// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick

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
