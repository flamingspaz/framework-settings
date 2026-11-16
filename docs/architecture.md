# How it works

```
System Settings ──D-Bus (system bus)──▶ frameworkd (root) ──framework_lib──▶ EC / HID / SMBIOS
  kcm_framework (C++/QML)                   polkit checks on writes
```

Talking to the embedded controller (EC) needs root, but a KCM runs as your
user. So the project has two parts:

- **`kcm/`**: `kcm_framework`, the System Settings module. A C++ backend
  (`frameworkkcm.cpp`) talks to the daemon over D-Bus, and the QML pages in
  `kcm/ui/` show the result.
- **`daemon/`**: `frameworkd`, a small Rust service that links
  `framework_lib` directly and serves `io.github.frameworkkcm.Daemon1` at
  `/io/github/frameworkkcm/Daemon1` on the system bus.

The daemon is D-Bus activated, so it starts when the KCM first calls it. Its
systemd unit (`frameworkd.service`) can also be enabled to start it at
boot (see [Remembered settings](#remembered-settings)).

## Authorization

Anyone can call the read methods. Every write first checks with polkit
(`data/io.github.frameworkkcm.policy`):

| Action | Covers | Active local session | Inactive or remote |
|---|---|---|---|
| `io.github.frameworkkcm.battery` | charge limit, override, charge rate | allowed | admin password |
| `io.github.frameworkkcm.fan` | fan duty, RPM, automatic | admin password, remembered for about 5 minutes | admin password |
| `io.github.frameworkkcm.input` | fingerprint LED, touchpad haptics and click force, keyboard backlight timeout | allowed | admin password |

## Remembered settings

Some settings can't be read back from the hardware: touchpad haptic
intensity, click force and the charge rate limit. The charge limit can be
read back, but the BIOS resets it to its own setting (100% by default) on
every boot. The daemon saves the last value it set for each of these in
`/var/lib/frameworkd/state.json` and applies it again when it starts.
That's why the systemd unit is worth enabling at boot.

While an override from the current boot is active, the saved charge limit
isn't applied, so the EC stays at 100%.

The keyboard backlight timeout is saved there too.

Fan mode is only kept in memory. When the daemon exits, it hands the fans
back to automatic control.

## Charge limit override

`OverrideChargeLimit` saves the current limit together with the kernel's
boot ID (`/proc/sys/kernel/random/boot_id`), then sets the limit to 100%.
When the daemon starts in a *different* boot, it puts the saved limit back.
Restarting the daemon within the same boot keeps the override.

While the override is active, `GetChargeSettings` reports the saved limit as
`maxLimit` (not the 100% the EC is using) and sets `overrideActive`. The
override ends early if you call `CancelChargeLimitOverride` or set a new limit
with `SetChargeLimit`.

## Keyboard backlight timeout

The EC has no backlight timeout, so the daemon fakes one. While a timeout is
set, it opens every keyboard and pointing device in `/dev/input` (anything
with Space, a left button or touch; not power buttons, lid switches or
sensors). Only the time of the last event is used, never which key or where.

To stay cheap while the keyboard is in use, it doesn't read input as it
arrives. Events queue in the kernel, and the daemon only reads them when the
timeout would run out, using their timestamps to work out when the last one
happened. That's also when it picks up newly plugged-in devices. Only while
the backlight is off does it wait on input directly.

Once nothing has happened for the timeout, it reads the backlight's current
brightness, remembers it in memory and fades the backlight out over a second. On the next
input it fades that brightness back in over a tenth of a second. Input during
the fade-out reverses it straight away. The desktop and Fn+Space stay in
charge of the brightness, so:

- if the backlight is already off at the timeout, nothing changes
- if it was turned back on while idle, that brightness is kept

Brightness goes through the kernel's LED device
(`/sys/class/leds/*::kbd_backlight`), the same one the desktop uses, rather
than framework_lib. framework_lib rounds the level down each time it converts,
so restoring through it would leave the backlight slightly dimmer each time.
If the daemon stops or restarts while the backlight is off, it restores the
remembered brightness first. The brightness isn't written to disk, so after a
crash the backlight stays off until it's changed from the desktop or with
Fn+Space.

## D-Bus API

Interface `io.github.frameworkkcm.Daemon1`. Values are plain `a{sv}`
dictionaries. The daemon sends no display text, only stable kebab-case keys
(such as `"location": "near-cpu"` or `"role": "sink-not-charging"`), and the
KCM turns them into translated strings. A root system service can't know
the user's language.

**Reads**

| Method | Returns |
|---|---|
| `GetSystemInfo()` | `a{sv}`: product, BIOS and EC versions, `pdVersions` (`aa{sv}`), privacy switches, `daemonVersion` |
| `GetPower()` | `a{sv}`: AC and battery state (not used by the KCM; handy with `busctl`) |
| `GetChargeSettings()` | `a{sv}`: `maxLimit`, `overrideActive`, `rateLimit`, `rateLimitSoc` |
| `GetThermal()` | `(aa{sv} sensors, aa{sv} fans, a{sv} throttle)` |
| `GetFanControl()` | `a{sv}`: `mode` (`auto`, `duty`, `rpm`) and `value` |
| `GetInput()` | `a{sv}`: fingerprint LED level, last haptic intensity and click force, `kbdBacklightSupported`, `kbdBacklightTimeout` (seconds, 0 = off) |
| `GetPorts()` | `aa{sv}`: one entry per USB-C port with `position`, `role`, `chargingType`, power readings |

Property `Version` (`s`) is the daemon version.

**Writes**

| Method | Action |
|---|---|
| `SetChargeLimit(i max)` | battery; 25–100 |
| `OverrideChargeLimit()` | battery |
| `CancelChargeLimitOverride()` | battery |
| `SetChargeRateLimit(d rate, d soc)` | battery; `rate` 0.1–1.0 (1.0 removes the limit), `soc` < 0 means any battery level |
| `SetFanDuty(i fan, i percent)` | fan; `fan` < 0 means all fans |
| `SetFanRpm(i fan, i rpm)` | fan |
| `SetAutoFan(i fan)` | fan |
| `SetFpLedLevel(s level)` | input; `high`, `medium`, `low`, `ultra-low`, `auto` |
| `SetHapticIntensity(i value)` | input; 0, 25, 50, 75 or 100 |
| `SetClickForce(s force)` | input; `low`, `medium`, `high` |
| `SetKeyboardBacklightTimeout(i seconds)` | input; 5–3600, or 0 to turn the timeout off |

Errors are `io.github.frameworkkcm.Error.NotAuthorized` and
`io.github.frameworkkcm.Error.Failed`.
