// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Controls

TabButton {
    id: control

    readonly property bool selected: TabBar.tabBar !== null
        && TabBar.tabBar.currentIndex === TabBar.index

    // Some styles (org.kde.desktop) draw the label as part of the background,
    // so replacing the background needs an explicit label
    contentItem: Label {
        text: control.text
        font: control.font
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }

    background: Rectangle {
        implicitWidth: 100
        implicitHeight: 36
        color: control.selected || control.hovered ? control.palette.button : "transparent"

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: 4
            visible: control.selected
            color: control.palette.highlight
        }

        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            color: "transparent"
            border.width: 1
            border.color: control.palette.highlight
            visible: control.visualFocus
        }
    }
}
