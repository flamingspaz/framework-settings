// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Controls
import QtTest
import ".."

Item {
    id: testRoot
    width: 800
    height: 760

    QtObject {
        id: mockBackend
        property bool scheduleEnabled: true
        property bool fixtureMode: true
        property bool saveSucceeds: true
        property var schedules: [{days: ["Mon", "Tue", "Wed", "Thu", "Fri"], time: "08:00", limit: 80}]
        property var lastEntries: []
        property bool lastEnabled: false

        function configureSchedule(enabled, entries) {
            lastEnabled = enabled;
            lastEntries = entries;
            if (!saveSucceeds) {
                return false;
            }
            scheduleEnabled = enabled;
            schedules = entries;
            return true;
        }
    }

    SchedulePage {
        id: schedulePage
        anchors.fill: parent
        backend: mockBackend
    }

    CloseGuard {
        id: closeGuard
    }

    TestCase {
        name: "ScheduleLifecycle"
        when: windowShown

        function activateButton(button) {
            verify(button !== null);
            tryVerify(function() {
                return button.visible && button.enabled && button.width > 0 && button.height > 0;
            });
            button.forceActiveFocus(Qt.TabFocusReason);
            tryVerify(function() { return button.activeFocus; });
            keyClick(Qt.Key_Space);
        }

        function init() {
            mockBackend.scheduleEnabled = true;
            mockBackend.schedules = [{days: ["Mon", "Tue", "Wed", "Thu", "Fri"], time: "08:00", limit: 80}];
            mockBackend.saveSucceeds = true;
            mockBackend.lastEntries = [];
            closeGuard.busy = false;
            closeGuard.settingsDirty = false;
            closeGuard.scheduleDirty = false;
            closeGuard.allowClose = false;
            schedulePage.discardChanges();
        }

        function test_initialLoadIsClean() {
            compare(schedulePage.hasUnsavedChanges, false);
            compare(schedulePage.scheduleEnabled, true);
        }

        function test_productionLocalizationContextIsAvailable() {
            verify(productionI18nContext !== null);
            compare(productionI18nContext.i18n("Localized %1", "text"), "Localized text");
        }

        function test_scheduleHeadingUsesProductionI18nArguments() {
            const heading = findChild(schedulePage, "scheduleHeading0");
            verify(heading !== null);
            compare(heading.text, "Schedule 1");
            verify(heading.text.indexOf("I18N_ARGUMENT_MISSING") < 0);
            verify(heading.text.indexOf("I18N_ARGUMENT_EXCESS") < 0);
        }

        function test_enableToggleAndRevert() {
            const enabledCheckBox = findChild(schedulePage, "scheduleEnabledCheckBox");
            verify(enabledCheckBox !== null);
            tryVerify(function() {
                return enabledCheckBox.visible && enabledCheckBox.enabled
                    && enabledCheckBox.width > 0 && enabledCheckBox.height > 0;
            });
            enabledCheckBox.forceActiveFocus(Qt.TabFocusReason);
            tryVerify(function() { return enabledCheckBox.activeFocus; });

            keyClick(Qt.Key_Space);
            tryCompare(enabledCheckBox, "checked", false);
            compare(schedulePage.scheduleEnabled, false);
            compare(schedulePage.hasUnsavedChanges, true);

            keyClick(Qt.Key_Space);
            tryCompare(enabledCheckBox, "checked", true);
            compare(schedulePage.scheduleEnabled, true);
            compare(schedulePage.hasUnsavedChanges, false);
        }

        function test_editsAndRevertingToSavedSnapshot() {
            schedulePage.toggleDay(0, "Sat", true);
            compare(schedulePage.hasUnsavedChanges, true);
            schedulePage.toggleDay(0, "Sat", false);
            compare(schedulePage.hasUnsavedChanges, false);

            const addButton = findChild(schedulePage, "addScheduleButton");
            verify(addButton !== null);
            activateButton(addButton);
            compare(schedulePage.hasUnsavedChanges, true);
            const removeButton = findChild(schedulePage, "removeScheduleButton1");
            activateButton(removeButton);
            compare(schedulePage.hasUnsavedChanges, false);
        }

        function test_failedSaveKeepsDirtyAndSuccessfulSaveClearsIt() {
            schedulePage.toggleDay(0, "Sat", true);
            const saveButton = findChild(schedulePage, "saveScheduleButton");
            verify(saveButton !== null);
            mockBackend.saveSucceeds = false;
            activateButton(saveButton);
            compare(schedulePage.hasUnsavedChanges, true);
            compare(mockBackend.schedules[0].days.indexOf("Sat"), -1);

            mockBackend.saveSucceeds = true;
            activateButton(saveButton);
            compare(schedulePage.hasUnsavedChanges, false);
            compare(schedulePage.changesSaved, true);
            verify(mockBackend.schedules[0].days.indexOf("Sat") >= 0);
        }

        function test_textEditsAreTrackedBeforeEditingFinishes() {
            const timeField = findChild(schedulePage, "scheduleTimeField0");
            verify(timeField !== null);
            timeField.forceActiveFocus();
            keyClick(Qt.Key_A, Qt.ControlModifier);
            keyClick(Qt.Key_0);
            keyClick(Qt.Key_9);
            keyClick(Qt.Key_Colon);
            keyClick(Qt.Key_3);
            keyClick(Qt.Key_0);
            compare(schedulePage.hasUnsavedChanges, true);
            schedulePage.saveSchedules();
            compare(mockBackend.lastEntries[0].time, "09:30");
            compare(schedulePage.hasUnsavedChanges, false);
        }

        function test_explicitDiscardRestoresSavedSnapshot() {
            schedulePage.toggleDay(0, "Sat", true);
            compare(schedulePage.hasUnsavedChanges, true);
            schedulePage.discardChanges();
            compare(schedulePage.hasUnsavedChanges, false);
            compare(schedulePage.currentSnapshot(), JSON.stringify({
                enabled: true,
                schedules: [{days: ["Mon", "Tue", "Wed", "Thu", "Fri"], time: "08:00", limit: 80}]
            }));
        }

        function test_busyBlocksCleanCloseEvenWhenDiscardWasAllowed() {
            closeGuard.settingsDirty = false;
            closeGuard.scheduleDirty = false;
            closeGuard.allowClose = false;
            compare(closeGuard.shouldBlockClose, false);

            closeGuard.busy = true;
            compare(closeGuard.shouldBlockClose, true);
            closeGuard.allowClose = true;
            compare(closeGuard.shouldBlockClose, true);
        }

        function test_busyBlocksDirtyCloseAndWaitsForOperation() {
            closeGuard.scheduleDirty = true;
            compare(closeGuard.hasUnsavedChanges, true);
            compare(closeGuard.shouldBlockClose, true);
            closeGuard.busy = true;
            compare(closeGuard.shouldBlockClose, true);
            closeGuard.busy = false;
            compare(closeGuard.shouldBlockClose, true);
            closeGuard.allowClose = true;
            compare(closeGuard.shouldBlockClose, false);
        }
    }
}
