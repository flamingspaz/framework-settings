// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import org.kde.kirigami as Kirigami

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
        dirty: kcm.needsSave
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
        anchors.margins: Kirigami.Units.gridUnit
        spacing: Kirigami.Units.largeSpacing

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            Kirigami.Heading {
                level: 1
                text: i18n("Framework Settings")
            }
            Label {
                text: i18n("Manage charging, cooling, and input hardware.")
            }
        }

        StatusMessages {
            Layout.fillWidth: true
        }

        TabBar {
            id: tabs
            Layout.fillWidth: true
            Repeater {
                model: pages.titles
                SettingsTabButton {
                    required property string modelData
                    width: tabs.width / pages.titles.length
                    text: modelData
                }
            }
        }

        ScrollView {
            id: scroller
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: availableWidth
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

            Pages {
                id: pages
                width: scroller.availableWidth
                currentIndex: tabs.currentIndex
                enabled: (kcm.daemonAvailable || kcm.fixtureMode) && !kcm.busy
            }
        }

        Kirigami.Separator {
            Layout.fillWidth: true
        }

        RowLayout {
            Layout.fillWidth: true
            Label {
                Layout.fillWidth: true
                text: kcm.busy ? i18n("Applying settings…") : kcm.needsSave ? i18n("Changes not applied") : ""
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
                    window.allowClose = true
                    discardDialog.close()
                    window.close()
                }
            }
        }
    }
}
