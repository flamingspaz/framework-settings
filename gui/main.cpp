// SPDX-License-Identifier: GPL-3.0-or-later

#include "frameworkkcm.h"
#include "localizedcontext.h"

#include <KLocalizedString>

#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>

int main(int argc, char *argv[]) {
    QGuiApplication app(argc, argv);
    QGuiApplication::setApplicationName(QStringLiteral("Framework Settings"));
    QGuiApplication::setOrganizationName(QStringLiteral("Framework"));
    QGuiApplication::setDesktopFileName(QStringLiteral("com.github.framework-settings"));
    KLocalizedString::setApplicationDomain(QByteArrayLiteral(TRANSLATION_DOMAIN));

    FrameworkKcm settings;
    settings.load();

    QQmlApplicationEngine engine;
    setupLocalizedContext(&engine);
    engine.rootContext()->setContextProperty(QStringLiteral("kcm"), &settings);
    engine.loadFromModule(QStringLiteral("Framework.Settings"), QStringLiteral("Main"));
    if (engine.rootObjects().isEmpty()) {
        return 1;
    }

    return QGuiApplication::exec();
}
