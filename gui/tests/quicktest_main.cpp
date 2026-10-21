// SPDX-License-Identifier: GPL-3.0-or-later

#include <QtQuickTest/quicktest.h>

#include <QGuiApplication>
#include <QQmlContext>
#include <QQmlEngine>

#if defined(FRAMEWORK_KF6_HAS_LOCALIZED_QML_CONTEXT)
// KI18n's TRANSLATION_DOMAIN macros expand the i18n method names in this header.
#pragma push_macro("TRANSLATION_DOMAIN")
#undef TRANSLATION_DOMAIN
#include <KLocalizedQmlContext>
#pragma pop_macro("TRANSLATION_DOMAIN")
#else
#include <KLocalizedContext>
#endif
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
#if defined(FRAMEWORK_KF6_HAS_LOCALIZED_QML_CONTEXT)
        auto *localizedContext = KLocalization::setupLocalizedContext(engine);
        localizedContext->setTranslationDomain(QStringLiteral(TRANSLATION_DOMAIN));
#else
        auto *localizedContext = new KLocalizedContext(engine);
        engine->rootContext()->setContextObject(localizedContext);
#endif
        engine->rootContext()->setContextProperty(QStringLiteral("productionI18nContext"), localizedContext);
    }
};

QUICK_TEST_MAIN_WITH_SETUP(gui_qml_runtime_tests, FrameworkQuickTestSetup)

#include "quicktest_main.moc"
