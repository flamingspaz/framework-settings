// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    id: root

    header: ColumnLayout {
        spacing: 0

        StatusMessages {
            Layout.fillWidth: true
        }

        QQC2.TabBar {
            id: tabBar
            Layout.fillWidth: true

            Repeater {
                model: pages.titles
                QQC2.TabButton {
                    required property string modelData
                    text: modelData
                }
            }
        }
    }

    Pages {
        id: pages
        width: parent.width
        currentIndex: tabBar.currentIndex
        enabled: (kcm.daemonAvailable || kcm.fixtureMode) && !kcm.busy
    }
}
