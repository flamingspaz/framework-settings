#!/bin/sh
# KDE-style string extraction; run through po/update.sh (or KDE's scripty)
$EXTRACTRC `find kcm -name '*.ui'` >> rc.cpp 2>/dev/null
# C collation so the .pot comes out the same on every machine; test sources
# (*/tests) hold fake strings and must not reach translators
$XGETTEXT `find kcm gui -path '*/tests' -prune -o \( -name '*.cpp' -o -name '*.qml' \) -print | LC_ALL=C sort` -o $podir/kcm_framework.pot
rm -f rc.cpp
