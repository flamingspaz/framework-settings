// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtTest
import ".."

Item {
    id: testRoot
    width: 900
    height: 1000

    QtObject {
        id: mockBackend
        property bool scheduleEnabled: true
        property bool fixtureMode: true
        property var schedules: [{days: ["Tue"], time: "09:30", limit: 75}]
        property var fixtureModels: [{id: "mock", name: "Mock"}]
        property string fixtureModel: "mock"
        property bool supportsKeyboardBacklight: true
        property bool fpLedSupported: false
        property bool supportsInputDeck: true
        property bool supportsTouchscreen: false
        property bool supportsTabletMode: true
        property var powerInfo: ({batteryPresent: true, percentage: 65, acPresent: true})
        property int chargeLimit: 85
        property var sensors: []
        property var fans: []
        property var throttle: ({known: false, hard: false, soft: false})
        property var systemInfo: ({product: "Mock laptop", biosVersion: "1.0", ecVersion: "2.0"})

        function setFixtureModel(model) {
            fixtureModel = model;
        }
    }

    OverviewPage {
        id: overviewPage
        anchors.fill: parent
        backend: mockBackend
        clock: new Date(2024, 0, 1, 10, 0, 0, 0).getTime()
    }

    TestCase {
        name: "OverviewLocalization"
        when: windowShown

        function assertFormattedText(objectName, expectedText) {
            const label = findChild(overviewPage, objectName);
            verify(label !== null, "Missing label " + objectName);
            compare(label.text, expectedText);
            verify(label.text.indexOf("I18N_ARGUMENT_MISSING") < 0);
            verify(label.text.indexOf("I18N_ARGUMENT_EXCESS") < 0);
            verify(!/%\d/.test(label.text), "Unsubstituted placeholder in " + label.text);
        }

        function init() {
            mockBackend.schedules = [{days: ["Tue"], time: "09:30", limit: 75}];
        }

        function test_overviewFormattedLabelsUseProductionI18nArguments() {
            assertFormattedText("overviewFixtureCapabilities",
                "Keyboard backlight: Yes · Fingerprint LED: No · Input deck: Yes · Touchscreen: No · Tablet mode: Yes");
            assertFormattedText("overviewBatterySummary", "65% · AC power connected");
            assertFormattedText("overviewChargeLimit", "Charge limit: 85%");
            assertFormattedText("overviewNextScheduleSummary", "Next scheduled change: 75% tomorrow at 09:30");
        }

        function test_laterWeekdayNameUsesLocale() {
            // The clock is Monday 2024-01-01; Thursday is three days ahead.
            mockBackend.schedules = [{days: ["Thu"], time: "09:30", limit: 75}];
            const thursday = new Date(2024, 0, 4, 9, 30, 0, 0);
            const dayName = thursday.toLocaleString(Qt.locale(), "dddd");
            compare(dayName, Qt.locale().dayName(4, Locale.LongFormat));
            if (Qt.locale().name.startsWith("de")) {
                compare(dayName, "Donnerstag");
            } else if (Qt.locale().name.startsWith("en")) {
                compare(dayName, "Thursday");
            }
            assertFormattedText("overviewNextScheduleSummary", "Next scheduled change: 75% " + dayName + " at 09:30");
        }
    }
}
