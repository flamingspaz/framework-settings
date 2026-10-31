// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

import org.kde.kirigami as Kirigami

ColumnLayout {
    id: root
    spacing: Kirigami.Units.largeSpacing

    // Injectable for the runtime tests; the KCM and the standalone app supply kcm
    property var backend: typeof kcm !== "undefined" ? kcm : null
    property bool scheduleEnabled: backend ? backend.scheduleEnabled : false
    property bool changesSaved: false
    property int editRevision: 0
    // Empty until the first load
    property string savedSnapshot: ""
    readonly property bool hasUnsavedChanges: {
        const revision = editRevision;
        return savedSnapshot !== "" && currentSnapshot() !== savedSnapshot;
    }
    readonly property var dayNames: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    readonly property var dayLabels: [i18n("Monday"), i18n("Tuesday"), i18n("Wednesday"), i18n("Thursday"), i18n("Friday"), i18n("Saturday"), i18n("Sunday")]

    // The edited entries as the backend takes them, days in week order
    function entries() {
        const result = [];
        for (let i = 0; i < schedules.count; ++i) {
            const entry = schedules.get(i);
            const selectedDays = entry.days.length > 0 ? entry.days.split(",") : [];
            result.push({
                days: dayNames.filter(day => selectedDays.indexOf(day) >= 0),
                time: entry.time,
                limit: entry.limit
            });
        }
        return result;
    }

    function currentSnapshot() {
        return JSON.stringify({enabled: scheduleEnabled, schedules: entries()});
    }

    function markEdited() {
        ++editRevision;
        changesSaved = false;
    }

    function loadSchedules() {
        schedules.clear();
        const savedSchedules = backend ? backend.schedules : [];
        for (let i = 0; i < savedSchedules.length; ++i) {
            const entry = savedSchedules[i];
            schedules.append({days: entry.days.join(","), time: entry.time, limit: entry.limit});
        }
        if (schedules.count === 0) {
            schedules.append({days: "Mon,Tue,Wed,Thu,Fri", time: "08:00", limit: 80});
        }
        scheduleEnabled = backend ? backend.scheduleEnabled : false;
        savedSnapshot = currentSnapshot();
        ++editRevision;
    }

    function discardChanges() {
        changesSaved = false;
        loadSchedules();
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
        changesSaved = false;
        if (backend && backend.configureSchedule(scheduleEnabled, entries())) {
            // The backend normalizes saved values; reload them as the new local baseline
            loadSchedules();
            changesSaved = true;
            savedTimer.restart();
        }
    }

    Component.onCompleted: loadSchedules()

    // Feeds needsSave, so Apply and the unsaved-changes prompts cover the schedule
    Binding {
        target: root.backend
        property: "scheduleDirty"
        value: root.hasUnsavedChanges
        when: root.backend !== null && root.backend.scheduleDirty !== undefined
    }

    Connections {
        target: root.backend
        ignoreUnknownSignals: true
        function onScheduleSaveRequested() {
            if (root.hasUnsavedChanges) {
                root.saveSchedules();
            }
        }
        function onScheduleResetRequested() {
            root.discardChanges();
        }
    }

    Timer {
        id: savedTimer
        interval: 3000
        repeat: false
        onTriggered: root.changesSaved = false
    }

    Kirigami.Heading {
        Layout.topMargin: Kirigami.Units.largeSpacing
        level: 1
        text: i18n("Charge schedule")
    }

    QQC2.Label {
        Layout.fillWidth: true
        text: i18n("Create entries that automatically apply a charge limit on selected weekdays.")
        color: Kirigami.Theme.disabledTextColor
        wrapMode: Text.WordWrap
    }

    Kirigami.InlineMessage {
        Layout.fillWidth: true
        visible: root.changesSaved
        type: Kirigami.MessageType.Positive
        text: i18n("Schedule saved.")
    }

    Kirigami.InlineMessage {
        Layout.fillWidth: true
        visible: root.backend && root.backend.fixtureMode
        type: Kirigami.MessageType.Information
        text: i18n("Fixture mode only previews schedule settings. No systemd timers are created.")
    }

    QQC2.CheckBox {
        objectName: "scheduleEnabledCheckBox"
        text: i18n("Enable charge schedules")
        checked: root.scheduleEnabled
        onToggled: {
            root.scheduleEnabled = checked;
            root.markEdited();
        }
    }

    Repeater {
        model: schedules
        delegate: QQC2.Frame
        {
            id: scheduleCard
            required property int index
            required property string days
            required property string time
            required property int limit
            Layout.fillWidth: true

            ColumnLayout {
                anchors.fill: parent
                spacing: Kirigami.Units.smallSpacing

                RowLayout {
                    Layout.fillWidth: true
                    QQC2.Label {
                        objectName: "scheduleHeading%1".arg(scheduleCard.index)
                        Layout.fillWidth: true
                        text: i18n("Schedule %1", scheduleCard.index + 1)
                        font.bold: true
                    }
                    QQC2.Button {
                        objectName: "removeScheduleButton%1".arg(scheduleCard.index)
                        icon.name: "list-remove"
                        display: QQC2.AbstractButton.IconOnly
                        enabled: schedules.count > 1
                        Accessible.name: i18n("Remove schedule")
                        onClicked: schedules.remove(scheduleCard.index)
                    }
                }

                QQC2.Label {
                    text: i18n("Days")
                    font.bold: true
                }
                Flow {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing
                    Repeater {
                        model: root.dayLabels
                        delegate: QQC2.CheckBox
                        {
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
                    QQC2.Label {
                        text: i18n("Time")
                    }
                    QQC2.TextField {
                        objectName: "scheduleTimeField%1".arg(scheduleCard.index)
                        Layout.fillWidth: true
                        enabled: root.scheduleEnabled
                        text: scheduleCard.time
                        placeholderText: "HH:MM"
                        // Per keystroke, so unsaved-change tracking sees the edit before focus leaves
                        onTextEdited: schedules.setProperty(scheduleCard.index, "time", text)
                    }
                    QQC2.Label {
                        text: i18n("Charge limit")
                    }
                    QQC2.SpinBox {
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
        QQC2.Button {
            objectName: "addScheduleButton"
            icon.name: "list-add"
            text: i18n("Add schedule")
            onClicked: schedules.append({days: "Mon,Tue,Wed,Thu,Fri", time: "08:00", limit: 80})
        }
        QQC2.Label {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignRight
            visible: root.hasUnsavedChanges
            text: i18n("Schedule changes need saving")
            color: Kirigami.Theme.disabledTextColor
            elide: Text.ElideRight
        }
        Item {
            Layout.fillWidth: true
            visible: !root.hasUnsavedChanges
        }
        QQC2.Button {
            objectName: "saveScheduleButton"
            icon.name: "document-save"
            text: i18n("Save schedule")
            onClicked: root.saveSchedules()
        }
    }

    QQC2.Label {
        Layout.fillWidth: true
        visible: root.backend && !root.backend.fixtureMode
        text: i18n("Schedules run through your user systemd manager and require the Framework System command-line tools.")
        color: Kirigami.Theme.disabledTextColor
        wrapMode: Text.WordWrap
    }

    ListModel {
        id: schedules
        onDataChanged: root.markEdited()
        onCountChanged: root.markEdited()
    }
}
