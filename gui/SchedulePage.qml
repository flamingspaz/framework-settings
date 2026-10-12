// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ScrollView {
    id: root
    clip: true
    contentWidth: availableWidth

    property bool scheduleEnabled: kcm.scheduleEnabled
    property bool changesSaved: false
    readonly property var dayNames: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    readonly property var dayLabels: [i18n("Monday"), i18n("Tuesday"), i18n("Wednesday"), i18n("Thursday"), i18n("Friday"), i18n("Saturday"), i18n("Sunday")]

    function loadSchedules() {
        schedules.clear();
        for (let i = 0; i < kcm.schedules.length; ++i) {
            const entry = kcm.schedules[i];
            schedules.append({days: entry.days.join(","), time: entry.time, limit: entry.limit});
        }
        if (schedules.count === 0) {
            schedules.append({days: "Mon,Tue,Wed,Thu,Fri", time: "08:00", limit: 80});
        }
    }

    function toggleDay(index, day, checked) {
        const entry = schedules.get(index);
        let days = entry.days.length > 0 ? entry.days.split(",") : [];
        const position = days.indexOf(day);
        if (checked && position < 0) {
            days.push(day);
        } else if (!checked && position >= 0) {
            days.splice(position, 1);
        }
        schedules.setProperty(index, "days", days.join(","));
    }

    function saveSchedules() {
        const entries = [];
        for (let i = 0; i < schedules.count; ++i) {
            const entry = schedules.get(i);
            entries.push({days: entry.days.length > 0 ? entry.days.split(",") : [], time: entry.time, limit: entry.limit});
        }
        if (kcm.configureSchedule(root.scheduleEnabled, entries)) {
            root.changesSaved = true;
            savedTimer.restart();
        }
    }

    Component.onCompleted: loadSchedules()

    Timer {
        id: savedTimer
        interval: 3000
        repeat: false
        onTriggered: root.changesSaved = false
    }

    ColumnLayout {
        width: root.availableWidth
        spacing: 16

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            Label { text: i18n("Charge schedule"); font.pixelSize: 24; font.weight: Font.DemiBold }
            Label {
                Layout.fillWidth: true
                text: i18n("Create entries that automatically apply a charge limit on selected weekdays.")
                color: palette.text
                wrapMode: Text.Wrap
            }
        }

        Label {
            Layout.fillWidth: true
            visible: root.changesSaved
            text: i18n("Schedule saved.")
        }

        Label {
            Layout.fillWidth: true
            visible: kcm.fixtureMode
            text: i18n("Fixture mode only previews schedule settings. No systemd timers are created.")
            wrapMode: Text.Wrap
        }

        CheckBox {
            text: i18n("Enable charge schedules")
            checked: root.scheduleEnabled
            onToggled: root.scheduleEnabled = checked
        }

        Repeater {
            model: schedules
            delegate: Frame {
                id: scheduleCard
                required property int index
                required property string days
                required property string time
                required property int limit
                Layout.fillWidth: true

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true
                        Label {
                            Layout.fillWidth: true
                            text: i18n("Schedule %1").arg(scheduleCard.index + 1)
                            font.weight: Font.DemiBold
                        }
                        Button {
                            text: i18n("Remove")
                            enabled: schedules.count > 1
                            onClicked: schedules.remove(scheduleCard.index)
                        }
                    }

                    Label { text: i18n("Days"); font.weight: Font.DemiBold }
                    Flow {
                        Layout.fillWidth: true
                        spacing: 4
                        Repeater {
                            model: root.dayLabels
                            delegate: CheckBox {
                                required property int index
                                text: root.dayLabels[index]
                                enabled: root.scheduleEnabled
                                checked: scheduleCard.days.split(",").indexOf(root.dayNames[index]) >= 0
                                onToggled: root.toggleDay(scheduleCard.index, root.dayNames[index], checked)
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Label { text: i18n("Time") }
                        TextField {
                            Layout.fillWidth: true
                            enabled: root.scheduleEnabled
                            text: scheduleCard.time
                            placeholderText: "HH:MM"
                            onEditingFinished: schedules.setProperty(scheduleCard.index, "time", text)
                        }
                        Label { text: i18n("Charge limit") }
                        SpinBox {
                            enabled: root.scheduleEnabled
                            from: 25
                            to: 100
                            stepSize: 5
                            value: scheduleCard.limit
                            textFromValue: value => i18nc("percent", "%1%", value)
                            onValueModified: schedules.setProperty(scheduleCard.index, "limit", value)
                        }
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Button {
                text: i18n("Add schedule")
                onClicked: schedules.append({days: "Mon,Tue,Wed,Thu,Fri", time: "08:00", limit: 80})
            }
            Item { Layout.fillWidth: true }
            Button {
                text: i18n("Save schedule")
                highlighted: true
                onClicked: root.saveSchedules()
            }
        }

        Label {
            Layout.fillWidth: true
            visible: !kcm.fixtureMode
            text: i18n("Schedules run through your user systemd manager and require the Framework System command-line tools.")
            color: palette.text
            wrapMode: Text.Wrap
        }
    }

    ListModel { id: schedules }
}
