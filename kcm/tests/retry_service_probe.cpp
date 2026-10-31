// SPDX-License-Identifier: GPL-3.0-or-later

#include "frameworkkcm.h"

#include <KLocalizedString>
#include <KPluginMetaData>

#include <QDBusConnection>
#include <QDBusContext>
#include <QSignalSpy>
#include <QtTest>

namespace {
    constexpr auto s_service = "io.github.frameworkkcm.Daemon1";
    constexpr auto s_path = "/io/github/frameworkkcm/Daemon1";
    class FakeDaemon final : public QObject, protected QDBusContext {
        Q_OBJECT
        Q_CLASSINFO("D-Bus Interface", "io.github.frameworkkcm.Daemon1")

    public:
        bool powerAvailable = false;
        int powerCalls = 0;

    public Q_SLOTS:
        QVariantMap GetSystemInfo() const { return {{QStringLiteral("product"), QStringLiteral("Probe Laptop")}}; }

        QVariantMap GetPower() {
            ++powerCalls;
            if (!powerAvailable) {
                sendErrorReply(QDBusError::Failed, QStringLiteral("simulated initial power read failure"));
                return {};
            }
            return {{QStringLiteral("percentage"), 67}};
        }

        QVariantMap GetChargeSettings() const {
            return {{QStringLiteral("maxLimit"), 100},
                    {QStringLiteral("rateLimit"), 1.0},
                    {QStringLiteral("rateLimitSoc"), -1.0},
                    {QStringLiteral("overrideActive"), false}};
        }

        QVariantMap GetFanControl() const {
            return {{QStringLiteral("mode"), QStringLiteral("auto")}, {QStringLiteral("value"), 0}};
        }

        QVariantMap GetInput() const {
            return {{QStringLiteral("fpLedSupported"), false},
                    {QStringLiteral("fpLedLevel"), QString()},
                    {QStringLiteral("hapticIntensity"), -1},
                    {QStringLiteral("clickForce"), QString()}};
        }
    };
} // namespace

class RetryServiceProbe final : public QObject {
    Q_OBJECT

private Q_SLOTS:
    void initTestCase() { KLocalizedString::setApplicationDomain(QByteArrayLiteral("kcm_framework")); }

    void retryReadsPowerAfterInitialFailure() {
        auto bus = QDBusConnection::systemBus();
        QVERIFY(bus.isConnected());
        QVERIFY(bus.registerService(QString::fromLatin1(s_service)));

        FakeDaemon daemon;
        QVERIFY(bus.registerObject(QString::fromLatin1(s_path), &daemon, QDBusConnection::ExportAllSlots));

        FrameworkKcm settings(nullptr, KPluginMetaData());
        QSignalSpy powerChanged(&settings, &FrameworkKcm::powerChanged);
        QVERIFY(powerChanged.isValid());

        settings.load();
        settings.setChargeLimit(90);
        QTRY_COMPARE(daemon.powerCalls, 1);
        QCOMPARE(settings.powerInfo().value(QStringLiteral("percentage")).toInt(), 0);

        daemon.powerAvailable = true;
        settings.retryService();

        QTRY_COMPARE(settings.powerInfo().value(QStringLiteral("percentage")).toInt(), 67);
        QCOMPARE(daemon.powerCalls, 2);
        QCOMPARE(powerChanged.count(), 1);
        QCOMPARE(settings.chargeLimit(), 90);

        bus.unregisterObject(QString::fromLatin1(s_path));
        bus.unregisterService(QString::fromLatin1(s_service));
    }

    void batteryTabPollsPowerAndOverviewReadsOnce() {
        auto bus = QDBusConnection::systemBus();
        QVERIFY(bus.registerService(QString::fromLatin1(s_service)));
        FakeDaemon daemon;
        daemon.powerAvailable = true;
        QVERIFY(bus.registerObject(QString::fromLatin1(s_path), &daemon, QDBusConnection::ExportAllSlots));

        FrameworkKcm settings(nullptr, KPluginMetaData());
        settings.setLiveData(QStringLiteral("power"));
        QTRY_COMPARE(settings.powerInfo().value(QStringLiteral("percentage")).toInt(), 67);
        // Polled every couple of seconds while the Battery tab is shown
        QTRY_VERIFY_WITH_TIMEOUT(daemon.powerCalls >= 2, 5000);

        // The Overview reads once (unless a poll was still in flight), then stops
        settings.setLiveData(QStringLiteral("overview"));
        const int atSwitch = daemon.powerCalls;
        QTest::qWait(5000);
        QVERIFY(daemon.powerCalls <= atSwitch + 1);

        bus.unregisterObject(QString::fromLatin1(s_path));
        bus.unregisterService(QString::fromLatin1(s_service));
    }

    void scheduleEditsCountTowardsNeedsSave() {
        FrameworkKcm settings(nullptr, KPluginMetaData());
        QSignalSpy saveRequested(&settings, &FrameworkKcm::scheduleSaveRequested);
        QSignalSpy resetRequested(&settings, &FrameworkKcm::scheduleResetRequested);
        QVERIFY(!settings.needsSave());

        settings.setScheduleDirty(true);
        QVERIFY(settings.needsSave());

        // Apply and Reset hand the schedule to the page that holds its edits
        settings.save();
        QCOMPARE(saveRequested.count(), 1);
        settings.load();
        QCOMPARE(resetRequested.count(), 1);
        // The page didn't clear its edits, so they still need saving
        QVERIFY(settings.needsSave());

        settings.setScheduleDirty(false);
        QVERIFY(!settings.needsSave());
    }
};

QTEST_GUILESS_MAIN(RetryServiceProbe)

#include "retry_service_probe.moc"
