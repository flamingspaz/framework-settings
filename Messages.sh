#!/bin/sh
# KDE-style string extraction; run through po/update.sh (or KDE's scripty)
$EXTRACTRC `find kcm -name '*.ui'` >> rc.cpp 2>/dev/null
# C collation so the .pot comes out the same on every machine
$XGETTEXT `find kcm gui \( -name '*.cpp' -o -name '*.qml' \) | LC_ALL=C sort` -o $podir/kcm_framework.pot
rm -f rc.cpp
