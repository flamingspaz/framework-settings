// SPDX-License-Identifier: GPL-3.0-or-later
//! Keyboard backlight timeout. The EC doesn't have one, so we fake it: watch
//! keyboards and pointing devices for activity, fade the backlight out once
//! they've been idle for the timeout, and fade back in the brightness it had
//! on the next input. Input during the fade-out brings it straight back.
//!
//! The desktop and Fn+Space stay in charge of the brightness. We read
//! whatever they last set when going idle, and leave the backlight alone if
//! it was already off or got turned up while idle.
//!
//! To cost next to nothing while the keyboard is in use, we don't read input
//! as it arrives. Events queue up in the kernel, and we only look at them when
//! the timeout would run out, using their timestamps to see how long it's
//! really been. Only while the backlight is off do we wait on input directly.
//! Only when input happened is used, never what it was.

use std::collections::{HashMap, HashSet};
use std::fs::OpenOptions;
use std::future::poll_fn;
use std::io;
use std::ops::RangeInclusive;
use std::os::unix::fs::OpenOptionsExt;
use std::path::{Path, PathBuf};
use std::task::Poll;
use std::time::{Duration, SystemTime};

use evdev::raw_stream::RawDevice;
use evdev::KeyCode;
use tokio::io::unix::AsyncFd;
use tokio::sync::watch;
use tokio::time::Instant;

use crate::{blocking, lock, restore, Daemon, Error};

/// Accepted timeouts in seconds; 0 turns the timeout off
pub const TIMEOUT_RANGE: RangeInclusive<u32> = 5..=3600;

/// Going idle fades out gently; input brings it back almost at once
const FADE_OUT: Duration = Duration::from_millis(1000);
const FADE_IN: Duration = Duration::from_millis(100);
/// Most brightness writes per fade
const FADE_STEPS: u32 = 20;

/// The LED the kernel's cros_kbd_led_backlight driver registers. Going through
/// it rather than framework_lib's PWM calls keeps the exact level: those
/// round percent to duty and back down, so restoring would creep darker.
fn led() -> Option<PathBuf> {
    std::fs::read_dir("/sys/class/leds")
        .ok()?
        .flatten()
        .map(|e| e.path())
        .find(|p| {
            p.file_name()
                .is_some_and(|n| n.to_string_lossy().ends_with("::kbd_backlight"))
        })
}

pub fn supported() -> bool {
    led().is_some()
}

async fn read_brightness(led: &Path) -> Result<u32, Error> {
    let path = led.join("brightness");
    blocking(move || {
        std::fs::read_to_string(&path)
            .map_err(|e| e.to_string())?
            .trim()
            .parse::<u32>()
            .map_err(|e| e.to_string())
    })
    .await
}

async fn write_brightness(led: &Path, value: u32) -> Result<(), Error> {
    let path = led.join("brightness");
    blocking(move || std::fs::write(&path, value.to_string()).map_err(|e| e.to_string())).await
}

/// Step the brightness from `from` to `to` over `duration`. Stops early once
/// `interrupt` returns true; returns whether it did.
async fn fade(
    led: &Path,
    from: u32,
    to: u32,
    duration: Duration,
    mut interrupt: impl FnMut() -> bool,
) -> Result<bool, Error> {
    let steps = from.abs_diff(to).clamp(1, FADE_STEPS);
    for step in 1..=steps {
        if interrupt() {
            return Ok(true);
        }
        let moved = from.abs_diff(to) * step / steps;
        let level = if to > from {
            from + moved
        } else {
            from - moved
        };
        write_brightness(led, level).await?;
        if step < steps {
            tokio::time::sleep(duration / steps).await;
        }
    }
    Ok(false)
}

/// Apply the timeout setting (seconds, 0 = off). Runs until main aborts it.
pub async fn run(daemon: Daemon) {
    let mut setting = daemon.0.backlight_timeout.subscribe();
    loop {
        let secs = *setting.borrow_and_update();
        if secs == 0 {
            // The sender lives in the daemon, so this can't fail
            let _ = setting.changed().await;
        } else {
            idle_loop(&daemon, Duration::from_secs(secs.into()), &mut setting).await;
        }
        wake(&daemon).await;
    }
}

/// Turn the backlight off when idle and on with activity until the setting
/// changes.
async fn idle_loop(daemon: &Daemon, timeout: Duration, setting: &mut watch::Receiver<u32>) {
    let mut inputs = Inputs::default();
    inputs.rescan();
    let mut deadline = Instant::now() + timeout;
    loop {
        tokio::select! {
            _ = setting.changed() => return,
            () = tokio::time::sleep_until(deadline) => {}
        }
        inputs.rescan();
        // Input since the last look: wait out the rest of the timeout from it
        let left = inputs.drain().and_then(|last| {
            timeout.checked_sub(SystemTime::now().duration_since(last).unwrap_or_default())
        });
        if let Some(left) = left {
            deadline = Instant::now() + left;
            continue;
        }

        let interrupted = turn_off(daemon, &mut inputs).await.unwrap_or_else(|e| {
            log::warn!("Failed to turn off keyboard backlight: {e:?}");
            false
        });
        if !interrupted {
            tokio::select! {
                _ = setting.changed() => return,
                () = inputs.wait() => {}
            }
            inputs.drain();
        }
        wake(daemon).await;
        deadline = Instant::now() + timeout;
    }
}

/// Fade the backlight out, remembering its brightness for wake(). Returns
/// whether input cut the fade short.
async fn turn_off(daemon: &Daemon, inputs: &mut Inputs) -> Result<bool, Error> {
    let Some(led) = led() else {
        return Ok(false);
    };
    let level = read_brightness(&led).await?;
    if level == 0 {
        return Ok(false);
    }
    // Remembered first so wake() still brings it back if the fade fails or
    // the daemon stops partway
    *lock(&daemon.0.backlight_restore) = Some(level);
    fade(&led, level, 0, FADE_OUT, || inputs.drain().is_some()).await
}

/// Put back the brightness the timeout turned off, if it did.
pub async fn wake(daemon: &Daemon) {
    let Some(level) = lock(&daemon.0.backlight_restore).take() else {
        return;
    };
    let Some(led) = led() else {
        return;
    };
    restore("keyboard backlight", async {
        // From wherever it got to if a fade was cut short. If the desktop or
        // Fn+Space turned it up while idle, theirs is kept.
        let now = read_brightness(&led).await?;
        if now < level {
            fade(&led, now, level, FADE_IN, || false).await?;
        }
        Ok(())
    })
    .await;
}

/// Keyboards and pointing devices, opened non-blocking so their queued
/// events can be read without waiting.
#[derive(Default)]
struct Inputs {
    devices: HashMap<PathBuf, RawDevice>,
    /// Devices looked at and skipped
    skipped: HashSet<PathBuf>,
}

impl Inputs {
    /// Pick up devices plugged in since the last look.
    fn rescan(&mut self) {
        let paths = event_devices();
        self.devices.retain(|p, _| paths.contains(p));
        self.skipped.retain(|p| paths.contains(p));
        for path in paths {
            if self.devices.contains_key(&path) || self.skipped.contains(&path) {
                continue;
            }
            if let Some(dev) = open(&path) {
                self.devices.insert(path, dev);
            } else {
                self.skipped.insert(path);
            }
        }
    }

    /// Read everything queued; returns when the newest event happened.
    fn drain(&mut self) -> Option<SystemTime> {
        let mut newest = None;
        self.devices.retain(|_, dev| loop {
            match dev.fetch_events() {
                Ok(events) => newest = events.map(|e| e.timestamp()).chain(newest).max(),
                Err(e) if e.kind() == io::ErrorKind::WouldBlock => break true,
                // Unplugged
                Err(_) => break false,
            }
        });
        newest
    }

    /// Wait until any device has input queued, without reading it.
    async fn wait(&mut self) {
        // Registered with the reactor only while waiting, so input at other
        // times doesn't wake us
        let fds: Vec<_> = self
            .devices
            .drain()
            .filter_map(|(path, dev)| AsyncFd::new(dev).ok().map(|fd| (path, fd)))
            .collect();
        poll_fn(|cx| {
            if fds.iter().any(|(_, fd)| fd.poll_read_ready(cx).is_ready()) {
                Poll::Ready(())
            } else {
                Poll::Pending
            }
        })
        .await;
        self.devices = fds
            .into_iter()
            .map(|(path, fd)| (path, fd.into_inner()))
            .collect();
    }
}

fn event_devices() -> HashSet<PathBuf> {
    std::fs::read_dir("/dev/input")
        .into_iter()
        .flatten()
        .flatten()
        .map(|e| e.path())
        .filter(|p| {
            p.file_name()
                .is_some_and(|n| n.to_string_lossy().starts_with("event"))
        })
        .collect()
}

/// Open a device if it's a keyboard or pointer. Power buttons, lid switches
/// and sensors don't mean someone is at the keyboard.
fn open(path: &Path) -> Option<RawDevice> {
    let file = OpenOptions::new()
        .read(true)
        .custom_flags(libc::O_NONBLOCK)
        .open(path)
        .ok()?;
    let dev = RawDevice::from_fd(file.into()).ok()?;
    let keys = dev.supported_keys()?;
    [KeyCode::KEY_SPACE, KeyCode::BTN_LEFT, KeyCode::BTN_TOUCH]
        .into_iter()
        .any(|k| keys.contains(k))
        .then_some(dev)
}
