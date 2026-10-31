// SPDX-License-Identifier: GPL-3.0-or-later

import QtQml

QtObject {
    // Busy operations must finish even if a prior close attempt allowed discarding edits.
    property bool busy: false
    // Unsaved settings or schedule edits; the backend's needsSave covers both
    property bool dirty: false
    property bool allowClose: false
    readonly property bool shouldBlockClose: busy || (dirty && !allowClose)
}
