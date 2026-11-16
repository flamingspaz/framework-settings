// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

import org.kde.kirigami as Kirigami

Kirigami.FormLayout {
    Item {
        Kirigami.FormData.isSection: true
        Kirigami.FormData.label: i18n("Lighting")
    }

    SettingComboBox {
        Kirigami.FormData.label: i18n("Fingerprint reader LED:")
        enabled: kcm.fpLedSupported
        setting: "fpLedLevel"
        unsetText: kcm.fpLedLevel === "custom" ? i18n("Custom") : i18n("Unknown")
        model: [
            {text: i18n("Automatic"), value: "auto"},
            {text: i18nc("fingerprint LED brightness", "High"), value: "high"},
            {text: i18nc("fingerprint LED brightness", "Medium"), value: "medium"},
            {text: i18nc("fingerprint LED brightness", "Low"), value: "low"},
            {text: i18nc("fingerprint LED brightness", "Ultra low"), value: "ultra-low"},
        ]
    }

    RowLayout {
        id: kbdTimeoutRow
        // Seconds offered when the timeout is first turned on
        readonly property int defaultTimeout: 30

        Kirigami.FormData.label: i18n("Keyboard backlight:")
        visible: kcm.supportsKeyboardBacklight
        QQC2.CheckBox {
            id: kbdTimeoutCheck
            text: i18n("Turn off after:")
            checked: kcm.kbdBacklightTimeout > 0
            onToggled: kcm.kbdBacklightTimeout = checked ? kbdTimeoutRow.defaultTimeout : 0
        }
        QQC2.SpinBox {
            enabled: kbdTimeoutCheck.checked
            from: 5
            to: 3600
            stepSize: 5
            value: kcm.kbdBacklightTimeout > 0 ? kcm.kbdBacklightTimeout : kbdTimeoutRow.defaultTimeout
            onValueModified: kcm.kbdBacklightTimeout = value
            textFromValue: (v) => i18ncp("keyboard backlight timeout", "%1 second", "%1 seconds", v)
        }
    }

    HintLabel {
        visible: kcm.supportsKeyboardBacklight && kbdTimeoutCheck.checked
        text: i18n("Set the brightness as usual from the desktop or with Fn+Space.")
    }

    Item {
        Kirigami.FormData.isSection: true
        Kirigami.FormData.label: i18n("Haptic Touchpad")
    }

    SettingComboBox {
        Kirigami.FormData.label: i18n("Haptic feedback:")
        setting: "hapticIntensity"
        unsetText: i18n("Not set")
        model: [
            {text: i18n("Off"), value: 0},
            {text: i18nc("percent", "%1%", 25), value: 25},
            {text: i18nc("percent", "%1%", 50), value: 50},
            {text: i18nc("percent", "%1%", 75), value: 75},
            {text: i18nc("percent", "%1%", 100), value: 100},
        ]
    }

    SettingComboBox {
        Kirigami.FormData.label: i18n("Click force:")
        setting: "clickForce"
        unsetText: i18n("Not set")
        model: [
            {text: i18nc("touchpad click force", "Light"), value: "low"},
            {text: i18nc("touchpad click force", "Medium"), value: "medium"},
            {text: i18nc("touchpad click force", "Firm"), value: "high"},
        ]
    }

    HintLabel {
        text: i18n("Only for haptic touchpads. The touchpad can't report these settings back, so this shows what was last set here. The service re-applies them when it starts.")
    }
}
