// SPDX-License-Identifier: GPL-3.0-or-later

import QtQml

QtObject {
    // Busy operations must finish even if a prior close attempt allowed discarding edits.
    property bool busy: false
    property bool settingsDirty: false
    property bool scheduleDirty: false
    property bool allowClose: false
    readonly property bool hasUnsavedChanges: settingsDirty || scheduleDirty
    readonly property bool shouldBlockClose: busy || (hasUnsavedChanges && !allowClose)
}
