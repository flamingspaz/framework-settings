// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

import org.kde.kirigami as Kirigami

ColumnLayout {
    id: root
    spacing: Kirigami.Units.largeSpacing

    property double clock: Date.now()
    // Injectable for the runtime tests; the KCM and the standalone app supply kcm
    property var backend: kcm

    Timer {
        interval: 60000
        repeat: true
        running: true
        onTriggered: root.clock = Date.now()
    }

    function nextScheduleSummary() {
        if (!backend.scheduleEnabled) {
            return "";
        }

        const now = new Date(root.clock);
        const weekdayNumber = {Mon: 1, Tue: 2, Wed: 3, Thu: 4, Fri: 5, Sat: 6, Sun: 0};
        let nextTime = null;
        let nextLimit = 0;
        for (let i = 0; i < backend.schedules.length; ++i) {
            const entry = backend.schedules[i];
            const match = /^(?:([01]\d|2[0-3])):([0-5]\d)$/.exec(entry.time);
            if (!match) {
                continue;
            }
            const days = entry.days;
            for (let j = 0; j < days.length; ++j) {
                const dayNumber = weekdayNumber[days[j]];
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
        const time = nextTime.toLocaleTimeString(Qt.locale(), Locale.ShortFormat);
        let relativeTime;
        if (nextTime.getFullYear() === now.getFullYear()
            && nextTime.getMonth() === now.getMonth()
            && nextTime.getDate() === now.getDate()) {
            relativeTime = i18n("at %1", time);
        } else {
            const tomorrow = new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1);
            if (nextTime.getFullYear() === tomorrow.getFullYear()
                && nextTime.getMonth() === tomorrow.getMonth()
                && nextTime.getDate() === tomorrow.getDate()) {
                relativeTime = i18n("tomorrow at %1", time);
            } else {
                relativeTime = i18n("%1 at %2", nextTime.toLocaleString(Qt.locale(), "dddd"), time);
            }
        }
        return i18n("Next scheduled change: %1% %2", nextLimit, relativeTime);
    }

    Kirigami.InlineMessage {
        Layout.fillWidth: true
        Layout.topMargin: Kirigami.Units.largeSpacing
        visible: root.backend.fixtureMode
        type: Kirigami.MessageType.Information
        text: i18n("Fixture mode is active. Readings are simulated, changes stay in memory, and no hardware service is contacted.")
    }

    QQC2.GroupBox {
        Layout.fillWidth: true
        visible: root.backend.fixtureMode
        title: i18n("Test hardware profile")

        ColumnLayout {
            anchors.fill: parent
            QQC2.Label {
                Layout.fillWidth: true
                text: i18n("Choose a profile to preview model-specific controls.")
                wrapMode: Text.Wrap
            }
            QQC2.ComboBox {
                Layout.fillWidth: true
                textRole: "name"
                valueRole: "id"
                model: root.backend.fixtureModels
                Component.onCompleted: currentIndex = indexOfValue(root.backend.fixtureModel)
                onActivated: root.backend.setFixtureModel(currentValue)
            }
            QQC2.Label {
                Layout.fillWidth: true
                objectName: "overviewFixtureCapabilities"
                text: i18n("Keyboard backlight: %1 · Fingerprint LED: %2 · Input deck: %3 · Touchscreen: %4 · Tablet mode: %5",
                    root.backend.supportsKeyboardBacklight ? i18n("Yes") : i18n("No"),
                    root.backend.fpLedSupported ? i18n("Yes") : i18n("No"),
                    root.backend.supportsInputDeck ? i18n("Yes") : i18n("No"),
                    root.backend.supportsTouchscreen ? i18n("Yes") : i18n("No"),
                    root.backend.supportsTabletMode ? i18n("Yes") : i18n("No"))
                color: Kirigami.Theme.disabledTextColor
                wrapMode: Text.Wrap
            }
        }
    }

    QQC2.GroupBox {
        Layout.fillWidth: true
        Layout.topMargin: root.backend.fixtureMode ? 0 : Kirigami.Units.largeSpacing
        title: i18n("Battery")

        ColumnLayout {
            anchors.fill: parent
            QQC2.Label {
                Layout.fillWidth: true
                text: {
                    const power = root.backend.powerInfo;
                    if (!power.batteryPresent) return i18n("Battery status unavailable");
                    if (power.charging) return i18nc("battery state", "Charging");
                    if (power.discharging) return i18n("Discharging");
                    return i18n("Not charging");
                }
                font.bold: true
            }
            QQC2.Label {
                Layout.fillWidth: true
                objectName: "overviewBatterySummary"
                text: root.backend.powerInfo.batteryPresent && root.backend.powerInfo.percentage >= 0
                    ? i18n("%1% · %2", root.backend.powerInfo.percentage,
                        root.backend.powerInfo.acPresent ? i18n("AC power connected") : i18n("Running on battery"))
                    : i18n("Battery readings unavailable")
                wrapMode: Text.Wrap
            }
            QQC2.ProgressBar {
                Layout.fillWidth: true
                visible: root.backend.powerInfo.batteryPresent && root.backend.powerInfo.percentage >= 0
                from: 0
                to: 100
                value: root.backend.powerInfo.percentage ?? 0
            }
            QQC2.Label {
                Layout.fillWidth: true
                objectName: "overviewChargeLimit"
                text: root.backend.chargeLimit > 0 ? i18n("Charge limit: %1%", root.backend.chargeLimit)
                    : i18n("Charge limit unavailable")
                color: Kirigami.Theme.disabledTextColor
                wrapMode: Text.Wrap
            }
            QQC2.Label {
                Layout.fillWidth: true
                objectName: "overviewNextScheduleSummary"
                visible: text.length > 0
                text: root.nextScheduleSummary()
                color: Kirigami.Theme.disabledTextColor
                wrapMode: Text.Wrap
            }
        }
    }

    QQC2.GroupBox {
        Layout.fillWidth: true
        title: i18n("Thermals and fans")

        ColumnLayout {
            anchors.fill: parent
            QQC2.Label {
                Layout.fillWidth: true
                text: root.backend.sensors.length > 0
                    ? root.backend.sensors.filter(sensor => sensor.status === "ok")
                        .map(sensor => i18n("%1: %2 °C", root.backend.sensorDisplayName(sensor.location, sensor.name || i18n("Sensor")), sensor.temp))
                        .join(" · ")
                    : i18n("Temperature readings unavailable")
                wrapMode: Text.Wrap
            }
            QQC2.Label {
                objectName: "overviewFanSummary"
                Layout.fillWidth: true
                text: root.backend.fans.length > 0
                    ? root.backend.fans.map(fan => fan.stalled
                        ? i18n("%1: %2", root.backend.fanDisplayName(fan.position, fan.name || i18n("Fan")), i18n("Stalled"))
                        : i18n("%1: %2 RPM", root.backend.fanDisplayName(fan.position, fan.name || i18n("Fan")), fan.rpm)).join(" · ")
                    : i18n("Fan readings unavailable")
                color: Kirigami.Theme.disabledTextColor
                wrapMode: Text.Wrap
            }
            QQC2.Label {
                Layout.fillWidth: true
                text: {
                    const t = root.backend.throttle;
                    if (!t.known) return i18n("Throttling: unknown");
                    if (t.hard) return i18n("Throttling: yes (PROCHOT)");
                    return t.soft ? i18n("Throttling: yes (soft limit)") : i18n("Not throttling");
                }
                color: Kirigami.Theme.disabledTextColor
            }
        }
    }

    QQC2.GroupBox {
        Layout.fillWidth: true
        title: i18n("Device and firmware")

        GridLayout {
            anchors.fill: parent
            columns: 2
            columnSpacing: Kirigami.Units.gridUnit
            rowSpacing: Kirigami.Units.smallSpacing
            QQC2.Label {
                text: i18n("Model")
                color: Kirigami.Theme.disabledTextColor
            }
            QQC2.Label {
                Layout.fillWidth: true
                text: root.backend.systemInfo.product || i18n("Unknown")
                wrapMode: Text.Wrap
            }
            QQC2.Label {
                text: i18n("BIOS")
                color: Kirigami.Theme.disabledTextColor
            }
            QQC2.Label {
                Layout.fillWidth: true
                text: root.backend.systemInfo.biosVersion || i18n("Unknown")
                wrapMode: Text.Wrap
            }
            QQC2.Label {
                text: i18n("EC")
                color: Kirigami.Theme.disabledTextColor
            }
            QQC2.Label {
                Layout.fillWidth: true
                text: root.backend.systemInfo.ecVersion || i18n("Unknown")
                wrapMode: Text.Wrap
            }
        }
    }
}
