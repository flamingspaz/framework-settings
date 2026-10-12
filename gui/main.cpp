// SPDX-License-Identifier: GPL-3.0-or-later

#include "frameworkkcm.h"

#include <KLocalizedContext>
#include <KLocalizedString>

#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>

int main(int argc, char *argv[]) {
    QGuiApplication app(argc, argv);
    QGuiApplication::setApplicationName(QStringLiteral("Framework Settings"));
    QGuiApplication::setOrganizationName(QStringLiteral("Framework"));
    QGuiApplication::setDesktopFileName(QStringLiteral("io.github.frameworkkcm"));
    KLocalizedString::setApplicationDomain(QByteArrayLiteral("kcm_framework"));

    FrameworkKcm settings;
    settings.load();

    QQmlApplicationEngine engine;
    engine.rootContext()->setContextObject(new KLocalizedContext(&engine));
    engine.rootContext()->setContextProperty(QStringLiteral("kcm"), &settings);
    engine.loadFromModule(QStringLiteral("Framework.Settings"), QStringLiteral("Main"));
    if (engine.rootObjects().isEmpty()) {
        return 1;
    }

    return QGuiApplication::exec();
}
