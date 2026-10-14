// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ApplicationWindow {
    id: window
    width: 800
    height: 760
    minimumWidth: 600
    minimumHeight: 560
    visible: true
    title: i18n("Framework Settings")
    property bool allowClose: false

    CloseGuard {
        id: closeGuard
        busy: kcm.busy
        settingsDirty: kcm.needsSave
        scheduleDirty: schedulePage.hasUnsavedChanges
        allowClose: window.allowClose
    }

    onClosing: function (close) {
        if (closeGuard.shouldBlockClose) {
            close.accepted = false
            if (kcm.busy) {
                // A previously approved discard must not bypass a now-busy operation.
                window.allowClose = false
            }
            discardDialog.open()
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 16

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            Label {
                text: i18n("Framework Settings")
                font.pixelSize: 24
                font.weight: Font.DemiBold
            }
            Label {
                text: i18n("Manage charging, cooling, and input hardware.")
                color: palette.text
            }
        }

        RowLayout {
            Layout.fillWidth: true
            visible: !kcm.daemonAvailable && !kcm.fixtureMode
            Label {
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                color: palette.text
                text: i18n("Cannot connect to the Framework hardware service (frameworkd). It is normally started automatically by D-Bus. Check that it is installed and that D-Bus activation is available, then retry.")
            }
            Button {
                text: i18n("Retry")
                enabled: !kcm.busy
                onClicked: kcm.retryService()
            }
        }
        Label {
            Layout.fillWidth: true
            visible: kcm.errorMessage.length > 0
            wrapMode: Text.Wrap
            color: palette.text
            text: kcm.errorMessage
        }

        TabBar {
            id: tabs
            Layout.fillWidth: true
            Layout.preferredWidth: parent.width
            SettingsTabButton {
                width: (window.width - 48) / 6; text: i18n("Overview")
            }
            SettingsTabButton {
                width: (window.width - 48) / 6; text: i18n("Battery")
            }
            SettingsTabButton {
                width: (window.width - 48) / 6; text: i18n("Schedule")
            }
            SettingsTabButton {
                width: (window.width - 48) / 6; text: i18n("Thermals")
            }
            SettingsTabButton {
                width: (window.width - 48) / 6; text: i18n("Input")
            }
            SettingsTabButton {
                width: (window.width - 48) / 6; text: i18n("System")
            }
        }

        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: tabs.currentIndex
            enabled: (kcm.daemonAvailable || kcm.fixtureMode) && !kcm.busy

            OverviewPage {
            }

            ScrollView {
                clip: true
                contentWidth: availableWidth
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                ColumnLayout {
                    width: parent.width
                    spacing: 16
                    GroupBox {
                        Layout.fillWidth: true
                        title: i18n("Battery status")
                        RowLayout {
                            anchors.fill: parent
                            Item {
                                Layout.preferredWidth: 68
                                Layout.preferredHeight: 112
                                Rectangle {
                                    id: batteryBody
                                    anchors.centerIn: parent
                                    width: 48
                                    height: 96
                                    radius: 5
                                    color: palette.base
                                    border.width: 2
                                    border.color: palette.text
                                    clip: true
                                    Rectangle {
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.bottom: parent.bottom
                                        anchors.margins: 3
                                        height: (parent.height - 6) * Math.max(0, Math.min(100, kcm.powerInfo.percentage ?? 0)) / 100
                                        color: (kcm.powerInfo.percentage ?? 100) <= 20 ? "#b3261e" : palette.highlight
                                    }
                                    Label {
                                        anchors.centerIn: parent
                                        text: kcm.powerInfo.batteryPresent && (kcm.powerInfo.percentage ?? -1) >= 0
                                            ? i18nc("percent", "%1%", kcm.powerInfo.percentage) : "--"
                                        font.weight: Font.DemiBold
                                    }
                                }
                                Rectangle {
                                    anchors.horizontalCenter: batteryBody.horizontalCenter
                                    anchors.bottom: batteryBody.top
                                    width: 14
                                    height: 5
                                    color: palette.text
                                }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                Label {
                                    text: {
                                        const power = kcm.powerInfo;
                                        if (!power.batteryPresent) return i18n("Battery unavailable");
                                        if (power.charging) return i18n("Charging");
                                        if (power.discharging) return i18n("Discharging");
                                        return i18n("Not charging");
                                    }
                                    font.weight: Font.DemiBold
                                }
                                Label {
                                    Layout.fillWidth: true
                                    text: kcm.powerInfo.acPresent === undefined
                                        ? i18n("Power status unavailable")
                                        : kcm.powerInfo.acPresent ? i18n("AC power connected") : i18n("Running on battery")
                                    color: palette.text
                                    wrapMode: Text.Wrap
                                }
                                Label {
                                    Layout.fillWidth: true
                                    text: kcm.chargeLimit > 0 ? i18n("Charge limit: %1%", kcm.chargeLimit)
                                        : i18n("Charge limit unavailable")
                                    wrapMode: Text.Wrap
                                }
                            }
                        }
                    }
                    GroupBox {
                        Layout.fillWidth: true
                        title: i18n("Charging")
                        ColumnLayout {
                            anchors.fill: parent
                            RowLayout {
                                Label {
                                    Layout.fillWidth: true; text: i18n("Charge limit:")
                                }
                                Slider {
                                    id: chargeLimitSlider
                                    Layout.fillWidth: true
                                    enabled: !kcm.chargeLimitOverridden
                                    from: 25;
                                    to: 100; stepSize: 5; snapMode: Slider.SnapAlways
                                    value: kcm.chargeLimit
                                    onMoved: kcm.chargeLimit = value
                                }
                                Label {
                                    text: i18nc("percent", "%1%", chargeLimitSlider.value)
                                }
                            }
                            Label {
                                Layout.fillWidth: true
                                wrapMode: Text.Wrap
                                text: i18n("Stops charging at this level. Keeping the battery below 100% helps it age slower. Plasma's Power Management page can set the same limit through the kernel driver; use only one of them.")
                            }
                            RowLayout {
                                Button {
                                    visible: !kcm.chargeLimitOverridden
                                    enabled: kcm.chargeLimit < 100
                                    text: i18n("Override Charge Limit")
                                    ToolTip.visible: hovered
                                    ToolTip.delay: 1000
                                    ToolTip.text: i18n("Charge to 100% once. The limit goes back to %1% the next time the computer starts.", kcm.chargeLimit)
                                    onClicked: kcm.overrideChargeLimit()
                                }
                                Label {
                                    Layout.fillWidth: true
                                    visible: kcm.chargeLimitOverridden
                                    wrapMode: Text.Wrap
                                    text: i18n("Charging to 100% until the computer restarts. The limit then goes back to %1%.", kcm.chargeLimit)
                                }
                                Button {
                                    visible: kcm.chargeLimitOverridden
                                    text: i18n("Restore now")
                                    onClicked: kcm.cancelChargeLimitOverride()
                                }
                            }
                        }
                    }
                    GroupBox {
                        Layout.fillWidth: true
                        title: i18n("Charge speed")
                        ColumnLayout {
                            anchors.fill: parent
                            CheckBox {
                                id: chargeSpeedCheck
                                text: i18n("Limit charging speed")
                                checked: kcm.chargeRateLimit < 1.0
                                onToggled: kcm.chargeRateLimit = checked ? 0.5 : 1.0
                            }
                            RowLayout {
                                visible: chargeSpeedCheck.checked
                                Label {
                                    text: i18n("Speed")
                                }
                                Slider {
                                    id: chargeRateSlider
                                    Layout.fillWidth: true
                                    from: 0.1;
                                    to: 0.9; stepSize: 0.1; snapMode: Slider.SnapAlways
                                    value: kcm.chargeRateLimit
                                    onMoved: kcm.chargeRateLimit = Math.round(value * 10) / 10
                                }
                                Label {
                                    readonly property real hours: Math.round(10 / chargeRateSlider.value) / 10
                                    text: i18nc("charge speed multiplier, hours to charge from empty", "%1× (about %2 h from empty)",
                                        Number(chargeRateSlider.value).toLocaleString(Qt.locale(), "f", 1),
                                        Number(hours).toLocaleString(Qt.locale(), "f", Number.isInteger(hours) ? 0 : 1))
                                }
                            }
                            RowLayout {
                                visible: chargeSpeedCheck.checked
                                CheckBox {
                                    id: socCheck
                                    text: i18n("Only above battery level:")
                                    checked: kcm.chargeRateSoc >= 0
                                    onToggled: kcm.chargeRateSoc = checked ? 80 : -1
                                }
                                SpinBox {
                                    enabled: socCheck.checked
                                    from: 0;
                                    to: 100; stepSize: 5
                                    value: Math.max(0, kcm.chargeRateSoc)
                                    onValueModified: kcm.chargeRateSoc = value
                                    textFromValue: value => i18nc("percent", "%1%", value)
                                }
                            }
                            Label {
                                Layout.fillWidth: true
                                visible: chargeSpeedCheck.checked
                                wrapMode: Text.Wrap
                                text: i18n("Relative to full charging speed. Slower charging produces less heat and wears the battery less; times are approximate. The EC forgets this limit on reset, so the service re-applies it when it starts.")
                            }
                        }
                    }
                }
            }

            SchedulePage {
                id: schedulePage
            }

            ScrollView {
                clip: true
                contentWidth: availableWidth
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                ColumnLayout {
                    width: parent.width
                    spacing: 16
                    GroupBox {
                        Layout.fillWidth: true
                        title: i18n("Temperatures")
                        ColumnLayout {
                            anchors.fill: parent
                            Repeater {
                                model: kcm.sensors
                                delegate: RowLayout {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    Label {
                                        Layout.fillWidth: true; text: kcm.sensorDisplayName(modelData.location, modelData.name || i18n("Sensor"))
                                    }
                                    Label {
                                        text: modelData.status === "ok" ? i18nc("degrees celsius", "%1 °C", modelData.temp) : kcm.sensorStatusDisplayName(modelData.status)
                                    }
                                }
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
                        title: i18n("Fans")
                        ColumnLayout {
                            anchors.fill: parent
                            Repeater {
                                model: kcm.fans
                                delegate: Label {
                                    required property var modelData
                                    objectName: "fanReading"
                                    text: modelData.stalled
                                        ? i18n("%1: %2", kcm.fanDisplayName(modelData.position, modelData.name || i18n("Fan")), i18n("Stalled"))
                                        : i18n("%1: %2 RPM", kcm.fanDisplayName(modelData.position, modelData.name || i18n("Fan")), modelData.rpm)
                                }
                            }
                            RowLayout {
                                Label {
                                    Layout.fillWidth: true; text: i18n("Fan control")
                                }
                                ComboBox {
                                    model: [i18n("Automatic"), i18n("Fixed duty cycle"), i18n("Fixed speed")]
                                    currentIndex: kcm.fanMode === "duty" ? 1 : kcm.fanMode === "rpm" ? 2 : 0
                                    onActivated: kcm.fanMode = ["auto", "duty", "rpm"][currentIndex]
                                }
                            }
                            RowLayout {
                                visible: kcm.fanMode === "duty"
                                Label {
                                    Layout.fillWidth: true; text: i18n("Fan duty")
                                }
                                Slider {
                                    id: dutySlider
                                    Layout.fillWidth: true
                                    from: 0;
                                    to: 100; stepSize: 5; snapMode: Slider.SnapAlways
                                    value: kcm.fanDuty
                                    onMoved: kcm.fanDuty = value
                                }
                                Label {
                                    text: i18nc("percent", "%1%", dutySlider.value)
                                }
                            }
                            RowLayout {
                                visible: kcm.fanMode === "rpm"
                                Label {
                                    Layout.fillWidth: true; text: i18n("Fan speed")
                                }
                                SpinBox {
                                    from: 0;
                                    to: 8000; stepSize: 100
                                    value: kcm.fanRpm
                                    onValueModified: kcm.fanRpm = value
                                    textFromValue: value => i18n("%1 RPM", value)
                                }
                            }
                            Label {
                                Layout.fillWidth: true
                                visible: kcm.fanMode !== "auto"
                                wrapMode: Text.Wrap
                                color: palette.highlight
                                font.weight: Font.DemiBold
                                leftPadding: 8
                                background: Rectangle {
                                    color: palette.alternateBase
                                    border.color: palette.highlight
                                    border.width: 1
                                    radius: 4
                                }
                                text: "⚠ " + i18n("The EC still shuts the system down if it overheats, but a fixed fan speed can let it run hot and throttle. Fans go back to automatic when the service stops or the laptop reboots.")
                            }
                        }
                    }
                }
            }

            ScrollView {
                clip: true
                contentWidth: availableWidth
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                ColumnLayout {
                    width: parent.width
                    spacing: 16
                    GroupBox {
                        Layout.fillWidth: true
                        title: i18n("Fingerprint reader LED")
                        RowLayout {
                            anchors.fill: parent
                            Label {
                                Layout.fillWidth: true; text: i18n("Brightness")
                            }
                            ComboBox {
                                enabled: kcm.fpLedSupported
                                model: [i18n("Automatic"), i18nc("fingerprint LED brightness", "High"), i18nc("fingerprint LED brightness", "Medium"), i18nc("fingerprint LED brightness", "Low"), i18nc("fingerprint LED brightness", "Ultra low")]
                                currentIndex: ["auto", "high", "medium", "low", "ultra-low"].indexOf(kcm.fpLedLevel)
                                displayText: currentIndex < 0 ? (kcm.fpLedLevel === "custom" ? i18n("Custom") : i18n("Unknown")) : currentText
                                onActivated: kcm.fpLedLevel = ["auto", "high", "medium", "low", "ultra-low"][currentIndex]
                            }
                        }
                    }
                    GroupBox {
                        Layout.fillWidth: true
                        title: i18n("Haptic touchpad")
                        ColumnLayout {
                            anchors.fill: parent
                            RowLayout {
                                Label {
                                    Layout.fillWidth: true; text: i18n("Feedback intensity")
                                }
                                ComboBox {
                                    objectName: "hapticIntensitySelector"
                                    model: [i18n("Off"), i18nc("percent", "%1%", 25), i18nc("percent", "%1%", 50), i18nc("percent", "%1%", 75), i18nc("percent", "%1%", 100)]
                                    currentIndex: [0, 25, 50, 75, 100].indexOf(kcm.hapticIntensity)
                                    displayText: currentIndex < 0 ? i18n("Not set") : currentText
                                    onActivated: kcm.hapticIntensity = [0, 25, 50, 75, 100][currentIndex]
                                }
                            }
                            RowLayout {
                                Label {
                                    Layout.fillWidth: true; text: i18n("Click force")
                                }
                                ComboBox {
                                    objectName: "clickForceSelector"
                                    model: [i18nc("touchpad click force", "Light"), i18nc("touchpad click force", "Medium"), i18nc("touchpad click force", "Firm")]
                                    currentIndex: ["low", "medium", "high"].indexOf(kcm.clickForce)
                                    displayText: currentIndex < 0 ? i18n("Not set") : currentText
                                    onActivated: kcm.clickForce = ["low", "medium", "high"][currentIndex]
                                }
                            }
                            Label {
                                Layout.fillWidth: true
                                wrapMode: Text.Wrap
                                text: i18n("Only for haptic touchpads. The touchpad can't report these settings back, so this shows what was last set here. The service re-applies them when it starts.")
                            }
                        }
                    }
                }
            }

            ScrollView {
                clip: true
                contentWidth: availableWidth
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                ColumnLayout {
                    width: parent.width
                    spacing: 16
                    GroupBox {
                        Layout.fillWidth: true
                        title: i18n("Device and firmware")
                        GridLayout {
                            Layout.fillWidth: true
                            columns: 2
                            columnSpacing: 24
                            rowSpacing: 12
                            Label {
                                text: i18n("Model"); color: palette.text
                            }
                            Label {
                                Layout.fillWidth: true; text: kcm.systemInfo.product || i18n("Unknown")
                            }
                            Label {
                                text: i18n("BIOS"); color: palette.text
                            }
                            Label {
                                Layout.fillWidth: true; text: kcm.systemInfo.biosVersion || i18n("Unknown")
                            }
                            Label {
                                text: i18n("EC"); color: palette.text
                            }
                            Label {
                                Layout.fillWidth: true; text: kcm.systemInfo.ecVersion || i18n("Unknown")
                            }
                            Label {
                                text: i18n("Service"); color: palette.text
                            }
                            Label {
                                Layout.fillWidth: true; text: kcm.systemInfo.daemonVersion || i18n("Unknown")
                            }
                            Label {
                                text: i18n("Camera"); color: palette.text
                            }
                            Label {
                                Layout.fillWidth: true
                                wrapMode: Text.Wrap
                                text: kcm.systemInfo.privacyKnown ? (kcm.systemInfo.cameraEnabled ? i18n("Enabled") : i18n("Disabled by privacy switch")) : i18n("Unknown")
                            }
                            Label {
                                text: i18n("Microphone"); color: palette.text
                            }
                            Label {
                                Layout.fillWidth: true
                                wrapMode: Text.Wrap
                                text: kcm.systemInfo.privacyKnown ? (kcm.systemInfo.micEnabled ? i18n("Enabled") : i18n("Disabled by privacy switch")) : i18n("Unknown")
                            }
                        }
                    }
                    GroupBox {
                        Layout.fillWidth: true
                        title: i18n("USB-C ports")
                        ColumnLayout {
                            anchors.fill: parent
                            Repeater {
                                model: kcm.ports
                                delegate: RowLayout {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    Label {
                                        Layout.fillWidth: true; text: modelData.position || i18n("Port")
                                    }
                                    Label {
                                        objectName: "portStatus"
                                        Layout.fillWidth: true
                                        horizontalAlignment: Text.AlignRight
                                        text: {
                                            const p = modelData;
                                            if (!p.ok) return i18n("Unavailable");
                                            if (p.role === "disconnected") return i18n("Nothing connected");
                                            if (p.role === "source") return i18n("Powering a device");
                                            if (p.role === "sink" || p.role === "sink-not-charging") {
                                                const watts = Number(p.maxPower / 1e6).toLocaleString(Qt.locale(), "f", 0);
                                                const volts = Number(p.voltageNow / 1000).toLocaleString(Qt.locale(), "f", 1);
                                                return i18n("%1 W, %2 V", watts, volts);
                                            }
                                            return i18n("Unknown");
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: palette.mid
            opacity: 0.25
        }

        RowLayout {
            Layout.fillWidth: true
            Label {
                Layout.fillWidth: true
                color: palette.text
                text: kcm.busy ? i18n("Applying settings…") : kcm.needsSave ? i18n("Changes not applied") : ""
            }
            Label {
                Layout.fillWidth: true
                visible: schedulePage.hasUnsavedChanges
                color: palette.text
                text: i18n("Schedule changes need saving")
            }
            Button {
                text: i18n("Defaults")
                enabled: !kcm.busy
                onClicked: kcm.defaults()
            }
            Button {
                text: i18n("Apply")
                enabled: kcm.needsSave && !kcm.busy && kcm.daemonAvailable
                highlighted: true
                onClicked: kcm.save()
            }
        }
    }

    Binding {
        target: kcm
        property: "liveData"
        value: tabs.currentIndex === 0 || tabs.currentIndex === 3 ? "thermal" : tabs.currentIndex === 5 ? "ports" : ""
    }

    Dialog {
        id: discardDialog
        anchors.centerIn: parent
        modal: true
        title: i18n("Unsaved changes")

        contentItem: Label {
            text: kcm.busy
                ? i18n("Settings are being applied. Wait for the operation to finish before closing.")
                : i18n("You have unsaved settings or schedule changes. Discard them and close?")
            wrapMode: Text.Wrap
        }

        footer: RowLayout {
            Button {
                text: i18n("Cancel")
                onClicked: discardDialog.close()
            }
            Item {
                Layout.fillWidth: true
            }
            Button {
                visible: !kcm.busy
                text: i18n("Discard and close")
                onClicked: {
                    // Recheck here as well as in onClosing: the operation can start
                    // while this dialog is already open.
                    if (kcm.busy) {
                        window.allowClose = false
                        return
                    }
                    schedulePage.discardChanges()
                    window.allowClose = true
                    discardDialog.close()
                    window.close()
                }
            }
        }
    }
}
