// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Layouts

import org.kde.kirigami as Kirigami

// Service and error banners shared by the KCM and the standalone app
ColumnLayout {
    spacing: 0

    Kirigami.InlineMessage {
        Layout.fillWidth: true
        Layout.margins: Kirigami.Units.smallSpacing
        visible: !kcm.daemonAvailable && !kcm.fixtureMode
        type: Kirigami.MessageType.Error
        text: i18n("Cannot connect to the Framework hardware service (frameworkd). It is normally started automatically by D-Bus. Check that it is installed and that D-Bus activation is available, then retry.")
        actions: Kirigami.Action {
            icon.name: "view-refresh"
            text: i18n("Retry")
            enabled: !kcm.busy
            onTriggered: kcm.retryService()
        }
    }

    Kirigami.InlineMessage {
        Layout.fillWidth: true
        Layout.margins: Kirigami.Units.smallSpacing
        visible: kcm.errorMessage.length > 0
        type: Kirigami.MessageType.Error
        text: kcm.errorMessage
        showCloseButton: true
        onVisibleChanged: if (!visible) kcm.clearError()
    }
}
