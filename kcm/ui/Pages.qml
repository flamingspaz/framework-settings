// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Layouts

// The tabs shared by the KCM and the standalone app. All pages stay alive so
// unsaved schedule edits survive switching tabs.
Item {
    id: root

    property int currentIndex: 0
    readonly property var titles: [i18n("Overview"), i18n("Battery"), i18n("Schedule"), i18n("Thermals"), i18n("Input"), i18n("System")]

    // Only as tall as the visible page, not the tallest one
    implicitHeight: stack.children[currentIndex] ? stack.children[currentIndex].implicitHeight : 0

    // Only poll what the visible tab shows; the Overview's summary reads once
    Binding {
        target: kcm
        property: "liveData"
        value: ["overview", "power", "", "thermal", "", "ports"][root.currentIndex]
    }

    StackLayout {
        id: stack
        anchors.fill: parent
        currentIndex: root.currentIndex

        OverviewPage {}
        BatteryPage {}
        SchedulePage {}
        ThermalPage {}
        InputPage {}
        SystemPage {}
    }
}
