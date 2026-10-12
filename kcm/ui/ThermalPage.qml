// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

import org.kde.kirigami as Kirigami

ColumnLayout {
    spacing: Kirigami.Units.largeSpacing

    Kirigami.Heading {
        Layout.alignment: Qt.AlignHCenter
        Layout.topMargin: Kirigami.Units.largeSpacing
        level: 3
        text: i18n("Temperatures")
    }

    Flow {
        id: sensorFlow
        readonly property real tileWidth: Kirigami.Units.gridUnit * 6
        Layout.alignment: Qt.AlignHCenter
        // Only as wide as the tiles that fit, so the Flow itself can be centered
        Layout.preferredWidth: Math.max(1, Math.min(kcm.sensors.length, Math.floor((parent.width + spacing) / (tileWidth + spacing)))) * (tileWidth + spacing) - spacing
        spacing: Kirigami.Units.largeSpacing

        Repeater {
            // Count, not the list, so tiles aren't rebuilt on every reading
            model: kcm.sensors.length
            delegate: ColumnLayout {
                required property int index
                readonly property var modelData: kcm.sensors[index] ?? ({})
                width: sensorFlow.tileWidth
                spacing: 0

                Kirigami.Heading {
                    Layout.alignment: Qt.AlignHCenter
                    level: 2
                    text: modelData.status === "ok"
                        ? i18nc("degrees celsius", "%1 °C", modelData.temp)
                        : kcm.sensorStatusDisplayName(modelData.status)
                }
                QQC2.Label {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.maximumWidth: sensorFlow.tileWidth
                    elide: Text.ElideRight
                    opacity: 0.7
                    text: kcm.sensorDisplayName(modelData.location, modelData.name)
                }
            }
        }
    }

    QQC2.Label {
        Layout.alignment: Qt.AlignHCenter
        text: {
            const t = kcm.throttle;
            if (!t.known) {
                return i18n("Throttling: unknown");
            }
            if (t.hard) {
                return i18n("Throttling: yes (PROCHOT)");
            }
            return t.soft ? i18n("Throttling: yes (soft limit)") : i18n("Not throttling");
        }
    }

    Kirigami.FormLayout {
        Layout.fillWidth: true

        Item {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Fans")
        }

        Repeater {
            // Count, not the list: a list model rebuilds every row whenever any value
            // changes, and FormLayout trips over the destroyed rows
            model: kcm.fans.length
            delegate: QQC2.Label {
                required property int index
                readonly property var modelData: kcm.fans[index] ?? ({})
                Kirigami.FormData.label: i18nc("fan name", "%1:", kcm.fanDisplayName(modelData.position, modelData.name))
                text: modelData.stalled ? i18n("Stalled") : i18n("%1 RPM", modelData.rpm)
            }
        }

        SettingComboBox {
            Kirigami.FormData.label: i18n("Fan control:")
            setting: "fanMode"
            model: [
                { text: i18n("Automatic"), value: "auto" },
                { text: i18n("Fixed duty cycle"), value: "duty" },
                { text: i18n("Fixed speed"), value: "rpm" },
            ]
        }

        RowLayout {
            visible: kcm.fanMode === "duty"
            QQC2.Slider {
                id: dutySlider
                Layout.preferredWidth: Kirigami.Units.gridUnit * 12
                from: 0
                to: 100
                stepSize: 5
                snapMode: QQC2.Slider.SnapAlways
                value: kcm.fanDuty
                onMoved: kcm.fanDuty = value
            }
            QQC2.Label {
                text: i18nc("percent", "%1%", dutySlider.value)
            }
        }

        QQC2.SpinBox {
            visible: kcm.fanMode === "rpm"
            from: 0
            to: 8000
            stepSize: 100
            value: kcm.fanRpm
            onValueModified: kcm.fanRpm = value
            textFromValue: (v) => i18n("%1 RPM", v)
            valueFromText: (text) => parseInt(text)
        }

        Kirigami.InlineMessage {
            Layout.fillWidth: true
            visible: kcm.fanMode !== "auto"
            type: Kirigami.MessageType.Warning
            text: i18n("The EC still shuts the system down if it overheats, but a fixed fan speed can let it run hot and throttle. Fans go back to automatic when the service stops or the laptop reboots.")
        }
    }
}
