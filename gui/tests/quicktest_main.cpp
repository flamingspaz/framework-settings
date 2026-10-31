// SPDX-License-Identifier: GPL-3.0-or-later

#include "localizedcontext.h"

#include <QtQuickTest/quicktest.h>

#include <QGuiApplication>
#include <QQmlContext>
#include <QQmlEngine>

#pragma push_macro("TRANSLATION_DOMAIN")
#undef TRANSLATION_DOMAIN
#include <KLocalizedString>
#pragma pop_macro("TRANSLATION_DOMAIN")

class FrameworkQuickTestSetup : public QObject {
    Q_OBJECT

public Q_SLOTS:
    void applicationAvailable() {
        KLocalizedString::setApplicationDomain(QByteArrayLiteral(TRANSLATION_DOMAIN));
        // Keep English source strings stable regardless of the host locale.
        KLocalizedString::setLanguages({QStringLiteral("en_US")});
    }

    void qmlEngineAvailable(QQmlEngine *engine) {
        engine->rootContext()->setContextProperty(QStringLiteral("productionI18nContext"),
                                                  setupLocalizedContext(engine));
    }
};

QUICK_TEST_MAIN_WITH_SETUP(gui_qml_runtime_tests, FrameworkQuickTestSetup)

#include "quicktest_main.moc"
