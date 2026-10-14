qt_add_executable(framework-settings
        main.cpp
        ../kcm/frameworkkcm.cpp
        ../kcm/frameworkkcm.h
)

target_compile_definitions(framework-settings PRIVATE FRAMEWORK_STANDALONE TRANSLATION_DOMAIN="kcm_framework")
target_include_directories(framework-settings PRIVATE ../kcm)
target_link_libraries(framework-settings PRIVATE
        Qt6::Core
        Qt6::DBus
        Qt6::Qml
        Qt6::Quick
        Qt6::QuickControls2
        KF6::I18n
)

if(KF6I18n_VERSION VERSION_GREATER_EQUAL "6.8.0")
    target_compile_definitions(framework-settings PRIVATE FRAMEWORK_KF6_HAS_LOCALIZED_QML_CONTEXT)
    target_link_libraries(framework-settings PRIVATE KF6::I18nQml)
endif()

qt_add_qml_module(framework-settings
        URI Framework.Settings
        VERSION 1.0
        QML_FILES
        Main.qml
        OverviewPage.qml
        SchedulePage.qml
        CloseGuard.qml
        SettingsTabButton.qml
)

install(TARGETS framework-settings DESTINATION ${KDE_INSTALL_BINDIR} COMPONENT gui)
install(FILES ../data/io.github.frameworkkcm.desktop
        DESTINATION ${CMAKE_INSTALL_DATAROOTDIR}/applications COMPONENT gui)

if(BUILD_TESTING)
    # Python assertions supplement the runtime checks, but are not a GUI build dependency.
    find_package(Python3 QUIET COMPONENTS Interpreter)
    if(Python3_Interpreter_FOUND)
        add_test(NAME gui-qml-regressions
                COMMAND ${Python3_EXECUTABLE} ${CMAKE_CURRENT_SOURCE_DIR}/tests/test_qml_regressions.py)
    else()
        message(STATUS "Python 3 not found; skipping supplemental GUI source regression tests")
    endif()

    # Qt Quick Test is optional. The small custom runner installs the same
    # KI18n QML context as the application before loading the real components.
    find_package(Qt6 QUIET OPTIONAL_COMPONENTS QuickTest)
    if(TARGET Qt6::QuickTest)
        qt_add_executable(gui-qml-runtime-tests tests/quicktest_main.cpp)
        target_compile_definitions(gui-qml-runtime-tests PRIVATE TRANSLATION_DOMAIN="kcm_framework")
        target_link_libraries(gui-qml-runtime-tests PRIVATE
                Qt6::Gui
                Qt6::Qml
                Qt6::QuickTest
                KF6::I18n
        )
        if(KF6I18n_VERSION VERSION_GREATER_EQUAL "6.8.0")
            target_compile_definitions(gui-qml-runtime-tests PRIVATE FRAMEWORK_KF6_HAS_LOCALIZED_QML_CONTEXT)
            target_link_libraries(gui-qml-runtime-tests PRIVATE KF6::I18nQml)
        endif()
        add_test(NAME gui-qml-runtime
                COMMAND gui-qml-runtime-tests -input ${CMAKE_CURRENT_SOURCE_DIR}/tests)
        set_tests_properties(gui-qml-runtime PROPERTIES
                ENVIRONMENT "QT_QPA_PLATFORM=offscreen")
    else()
        message(STATUS "Qt Quick Test not found; skipping optional GUI runtime tests")
    endif()
endif()
