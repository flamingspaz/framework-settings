# The probe stands in for frameworkd on a private bus, so it needs dbus-run-session
find_package(Qt6 ${QT_MIN_VERSION} QUIET OPTIONAL_COMPONENTS Test)
find_program(DBUS_RUN_SESSION dbus-run-session)

if(TARGET Qt6::Test AND DBUS_RUN_SESSION)
    add_executable(retry-service-probe
        retry_service_probe.cpp
        ../frameworkkcm.cpp
    )
    target_include_directories(retry-service-probe PRIVATE ..)
    target_link_libraries(retry-service-probe PRIVATE
        Qt6::Core
        Qt6::DBus
        Qt6::Test
        KF6::CoreAddons
        KF6::I18n
        KF6::KCMUtilsQuick
    )
    # The backend talks to the system bus; point it at the private session bus
    add_test(NAME kcm-retry-service
        COMMAND ${DBUS_RUN_SESSION} -- sh -c "DBUS_SYSTEM_BUS_ADDRESS=$DBUS_SESSION_BUS_ADDRESS exec \"$0\"" $<TARGET_FILE:retry-service-probe>)
else()
    message(STATUS "Qt Test or dbus-run-session not found; skipping KCM D-Bus tests")
endif()
