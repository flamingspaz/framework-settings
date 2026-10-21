// SPDX-License-Identifier: GPL-3.0-or-later

#include "frameworkkcm.h"

#if defined(FRAMEWORK_KF6_HAS_LOCALIZED_QML_CONTEXT)
// KI18n's TRANSLATION_DOMAIN macros expand the i18n method names in this header.
#pragma push_macro("TRANSLATION_DOMAIN")
#undef TRANSLATION_DOMAIN
#include <KLocalizedQmlContext>
#pragma pop_macro("TRANSLATION_DOMAIN")
#else
#include <KLocalizedContext>
#endif
#include <KLocalizedString>

#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>

int main(int argc, char *argv[]) {
    QGuiApplication app(argc, argv);
    QGuiApplication::setApplicationName(QStringLiteral("Framework Settings"));
    QGuiApplication::setOrganizationName(QStringLiteral("Framework"));
    QGuiApplication::setDesktopFileName(QStringLiteral("io.github.frameworkkcm"));
    KLocalizedString::setApplicationDomain(QByteArrayLiteral(TRANSLATION_DOMAIN));

    FrameworkKcm settings;
    settings.load();

    QQmlApplicationEngine engine;
#if defined(FRAMEWORK_KF6_HAS_LOCALIZED_QML_CONTEXT)
    auto *localizedContext = KLocalization::setupLocalizedContext(&engine);
    localizedContext->setTranslationDomain(QStringLiteral(TRANSLATION_DOMAIN));
#else
    engine.rootContext()->setContextObject(new KLocalizedContext(&engine));
#endif
    engine.rootContext()->setContextProperty(QStringLiteral("kcm"), &settings);
    engine.loadFromModule(QStringLiteral("Framework.Settings"), QStringLiteral("Main"));
    if (engine.rootObjects().isEmpty()) {
        return 1;
    }

    return QGuiApplication::exec();
}
