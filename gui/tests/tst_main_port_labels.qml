// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtTest
import ".."

Item {
    id: testRoot
    width: 100
    height: 100

    // Main.qml resolves the application's "kcm" context property by name; this
    // id provides the same lookup for the real window without hardware.
    QtObject {
        id: kcm
        property bool busy: false
        property bool needsSave: false
        property bool daemonAvailable: true
        property bool fixtureMode: true
        property string errorMessage: ""
        property int chargeLimit: 80
        property bool chargeLimitOverridden: false
        property int chargeRateLimit: 0
        property int chargeRateSoc: 0
        property string fanMode: "auto"
        property int fanRpm: 0
        property int fanDuty: 0
        property int fpLedLevel: 0
        property bool fpLedSupported: false
        property int hapticIntensity: 0
        property string clickForce: "medium"
        property var powerInfo: ({batteryPresent: true, percentage: 65, acPresent: true})
        property var systemInfo: ({product: "Mock laptop", biosVersion: "1.0", ecVersion: "2.0", privacyKnown: false})
        property var throttle: ({known: false, hard: false, soft: false})
        property var sensors: []
        property var fans: []
        property var ports: [{ok: true, position: "left-back", role: "sink", chargingType: "pd", maxPower: 65000000, voltageNow: 20500}]
        property string liveData: ""
        property bool scheduleEnabled: false
        property var schedules: []
        property var fixtureModels: []
        property string fixtureModel: ""
        property bool supportsKeyboardBacklight: false
        property bool supportsInputDeck: false
        property bool supportsTouchscreen: false
        property bool supportsTabletMode: false

        function fanDisplayName(position, name) { return name; }
        function sensorDisplayName(location, name) { return name; }
        function sensorStatusDisplayName(status) { return status; }
        function configureSchedule(enabled, entries) { return true; }
        function setFixtureModel(model) {}
        function save() {}
        function defaults() {}
        function retryService() {}
        function clearError() {}
        function overrideChargeLimit() {}
        function cancelChargeLimitOverride() {}
    }

    Main {
        id: mainWindow
        visible: false
    }

    TestCase {
        name: "MainPortLabels"
        when: windowShown

        function findByObjectName(item, objectName) {
            if (!item) {
                return null;
            }
            if (item.objectName === objectName) {
                return item;
            }
            const children = item.children || [];
            for (let i = 0; i < children.length; ++i) {
                const found = findByObjectName(children[i], objectName);
                if (found) {
                    return found;
                }
            }
            return null;
        }

        function test_portVoltageUsesLocaleDecimalSeparator() {
            const label = findByObjectName(mainWindow.contentItem, "portStatus");
            verify(label !== null, "Missing port status label");
            const expected = "Charging via USB Power Delivery, up to 65 W ("
                + Number(20.5).toLocaleString(Qt.locale(), "f", 1) + " V)";
            compare(label.text, expected);
            verify(label.text.indexOf("I18N_ARGUMENT_MISSING") < 0);
            verify(label.text.indexOf("I18N_ARGUMENT_EXCESS") < 0);
            verify(!/%\d/.test(label.text), "Unsubstituted placeholder in " + label.text);
            const decimalPoint = Qt.locale().decimalPoint;
            verify(label.text.indexOf("20" + decimalPoint + "5 V") >= 0,
                "Voltage should use the locale decimal point: " + label.text);
            if (decimalPoint !== ".") {
                verify(label.text.indexOf("20.5") < 0, "Voltage ignored the locale: " + label.text);
            }
        }
    }
}
