// SPDX-License-Identifier: GPL-3.0-or-later

#pragma once

#if defined(FRAMEWORK_KF6_HAS_LOCALIZED_QML_CONTEXT)
// KI18n's TRANSLATION_DOMAIN macros expand the i18n method names in this header.
#pragma push_macro("TRANSLATION_DOMAIN")
#undef TRANSLATION_DOMAIN
#include <KLocalizedQmlContext>
#pragma pop_macro("TRANSLATION_DOMAIN")
#else
#include <KLocalizedContext>
#endif

#include <QQmlContext>
#include <QQmlEngine>

// Gives the engine's QML i18n() and friends, in this build's translation domain;
// shared by the app and the QML test runner so both load components the same way
inline QObject *setupLocalizedContext(QQmlEngine *engine) {
#if defined(FRAMEWORK_KF6_HAS_LOCALIZED_QML_CONTEXT)
    auto *context = KLocalization::setupLocalizedContext(engine);
    context->setTranslationDomain(QStringLiteral(TRANSLATION_DOMAIN));
#else
    auto *context = new KLocalizedContext(engine);
    engine->rootContext()->setContextObject(context);
#endif
    return context;
}
