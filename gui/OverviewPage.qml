// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ScrollView {
    id: root
    clip: true
    contentWidth: availableWidth

    property double clock: Date.now()

    Timer {
        interval: 60000
        repeat: true
        running: true
        onTriggered: root.clock = Date.now()
    }

    function nextScheduleSummary() {
        if (!kcm.scheduleEnabled) {
            return "";
        }

        const now = new Date(root.clock);
        const weekdayNumber = {Mon: 1, Tue: 2, Wed: 3, Thu: 4, Fri: 5, Sat: 6, Sun: 0};
        let nextTime = null;
        let nextLimit = 0;
        for (let i = 0; i < kcm.schedules.length; ++i) {
            const entry = kcm.schedules[i];
            const match = /^(?:([01]\d|2[0-3])):([0-5]\d)$/.exec(entry.time);
            if (!match) {
                continue;
            }
            for (let j = 0; j < entry.days.length; ++j) {
                const dayNumber = weekdayNumber[entry.days[j]];
                if (dayNumber === undefined) {
                    continue;
                }
                const daysUntil = (dayNumber - now.getDay() + 7) % 7;
                const candidate = new Date(now.getFullYear(), now.getMonth(), now.getDate() + daysUntil,
                    Number(match[1]), Number(match[2]), 0, 0);
                if (candidate <= now) {
                    candidate.setDate(candidate.getDate() + 7);
                }
                if (nextTime === null || candidate < nextTime) {
                    nextTime = candidate;
                    nextLimit = entry.limit;
                }
            }
        }
        if (nextTime === null) {
            return "";
        }
        const time = Qt.formatDateTime(nextTime, "HH:mm");
        let relativeTime;
        if (nextTime.getFullYear() === now.getFullYear()
            && nextTime.getMonth() === now.getMonth()
            && nextTime.getDate() === now.getDate()) {
            relativeTime = i18n("at %1").arg(time);
        } else {
            const tomorrow = new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1);
            if (nextTime.getFullYear() === tomorrow.getFullYear()
                && nextTime.getMonth() === tomorrow.getMonth()
                && nextTime.getDate() === tomorrow.getDate()) {
                relativeTime = i18n("tomorrow at %1").arg(time);
            } else {
                relativeTime = i18n("%1 at %2").arg(Qt.formatDateTime(nextTime, "dddd")).arg(time);
            }
        }
        return i18n("Next scheduled change: %1% %2").arg(nextLimit).arg(relativeTime);
    }

    ColumnLayout {
        width: root.availableWidth
        spacing: 12

        Label {
            Layout.fillWidth: true
            visible: kcm.fixtureMode
            wrapMode: Text.Wrap
            color: palette.text
            text: i18n("Fixture mode is active. Readings are simulated, changes stay in memory, and no hardware service is contacted.")
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 12

            GroupBox {
                Layout.fillWidth: true
                visible: kcm.fixtureMode
                title: i18n("Test hardware profile")
                ColumnLayout {
                    anchors.fill: parent
                    Label {
                        Layout.fillWidth: true
                        text: i18n("Choose a profile to preview model-specific controls.")
                        wrapMode: Text.Wrap
                    }
                    ComboBox {
                        Layout.fillWidth: true
                        textRole: "name"
                        valueRole: "id"
                        model: kcm.fixtureModels
                        Component.onCompleted: currentIndex = indexOfValue(kcm.fixtureModel)
                        onActivated: kcm.setFixtureModel(currentValue)
                    }
                    Label {
                        Layout.fillWidth: true
                        text: i18n("Keyboard backlight: %1 · Fingerprint LED: %2 · Input deck: %3 · Touchscreen: %4 · Tablet mode: %5")
                            .arg(kcm.supportsKeyboardBacklight ? i18n("Yes") : i18n("No"))
                            .arg(kcm.fpLedSupported ? i18n("Yes") : i18n("No"))
                            .arg(kcm.supportsInputDeck ? i18n("Yes") : i18n("No"))
                            .arg(kcm.supportsTouchscreen ? i18n("Yes") : i18n("No"))
                            .arg(kcm.supportsTabletMode ? i18n("Yes") : i18n("No"))
                        wrapMode: Text.Wrap
                        color: palette.text
                    }
                }
            }

            GroupBox {
                Layout.fillWidth: true
                title: i18n("Battery")
                ColumnLayout {
                    anchors.fill: parent
                    Label {
                        Layout.fillWidth: true
                        text: {
                            const power = kcm.powerInfo;
                            if (!power.batteryPresent) return i18n("Battery status unavailable");
                            if (power.charging) return i18n("Charging");
                            if (power.discharging) return i18n("Discharging");
                            return i18n("Not charging");
                        }
                        font.weight: Font.DemiBold
                    }
                    Label {
                        Layout.fillWidth: true
                        text: kcm.powerInfo.batteryPresent && kcm.powerInfo.percentage >= 0
                            ? i18n("%1% · %2").arg(kcm.powerInfo.percentage)
                                .arg(kcm.powerInfo.acPresent ? i18n("AC power connected") : i18n("Running on battery"))
                            : i18n("Battery readings unavailable")
                        wrapMode: Text.Wrap
                    }
                    ProgressBar {
                        Layout.fillWidth: true
                        visible: kcm.powerInfo.batteryPresent && kcm.powerInfo.percentage >= 0
                        from: 0
                        to: 100
                        value: kcm.powerInfo.percentage ?? 0
                    }
                    Label {
                        Layout.fillWidth: true
                        text: kcm.chargeLimit > 0 ? i18n("Charge limit: %1%").arg(kcm.chargeLimit)
                            : i18n("Charge limit unavailable")
                        color: palette.text
                        wrapMode: Text.Wrap
                    }
                    Label {
                        Layout.fillWidth: true
                        visible: root.nextScheduleSummary().length > 0
                        text: root.nextScheduleSummary()
                        color: palette.text
                        wrapMode: Text.Wrap
                    }
                }
            }

            GroupBox {
                Layout.fillWidth: true
                title: i18n("Thermals and fans")
                ColumnLayout {
                    anchors.fill: parent
                    Label {
                        Layout.fillWidth: true
                        text: kcm.sensors.length > 0
                            ? kcm.sensors.filter(sensor => sensor.status === "ok")
                                .map(sensor => i18n("%1: %2 °C", kcm.sensorDisplayName(sensor.location, sensor.name || i18n("Sensor")), sensor.temp))
                                .join(" · ")
                            : i18n("Temperature readings unavailable")
                        wrapMode: Text.Wrap
                    }
                    Label {
                        Layout.fillWidth: true
                        text: kcm.fans.length > 0
                            ? kcm.fans.map(fan => i18n("%1: %2 RPM", kcm.fanDisplayName(fan.position, fan.name || i18n("Fan")), fan.rpm)).join(" · ")
                            : i18n("Fan readings unavailable")
                        color: palette.text
                        wrapMode: Text.Wrap
                    }
                    Label {
                        Layout.fillWidth: true
                        text: {
                            const t = kcm.throttle;
                            if (!t.known) return i18n("Throttling: unknown");
                            if (t.hard) return i18n("Throttling: yes (PROCHOT)");
                            return t.soft ? i18n("Throttling: yes (soft limit)") : i18n("Not throttling");
                        }
                    }
                }
            }

            GroupBox {
                Layout.fillWidth: true
                title: i18n("Device and firmware")
                GridLayout {
                    anchors.fill: parent
                    columns: 2
                    columnSpacing: 16
                    rowSpacing: 6
                    Label {
                        text: i18n("Model"); color: palette.text
                    }
                    Label {
                        Layout.fillWidth: true; text: kcm.systemInfo.product || i18n("Unknown"); wrapMode: Text.Wrap
                    }
                    Label {
                        text: i18n("BIOS"); color: palette.text
                    }
                    Label {
                        Layout.fillWidth: true; text: kcm.systemInfo.biosVersion || i18n("Unknown"); wrapMode: Text.Wrap
                    }
                    Label {
                        text: i18n("EC"); color: palette.text
                    }
                    Label {
                        Layout.fillWidth: true; text: kcm.systemInfo.ecVersion || i18n("Unknown"); wrapMode: Text.Wrap
                    }
                }
            }
        }
    }
}
