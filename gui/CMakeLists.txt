# KI18n 6.8 moved the QML i18n context (see localizedcontext.h) into KF6::I18nQml
function(framework_link_i18n target)
    target_link_libraries(${target} PRIVATE KF6::I18n)
    if(KF6I18n_VERSION VERSION_GREATER_EQUAL "6.8.0")
        target_compile_definitions(${target} PRIVATE FRAMEWORK_KF6_HAS_LOCALIZED_QML_CONTEXT)
        target_link_libraries(${target} PRIVATE KF6::I18nQml)
    endif()
endfunction()

qt_add_executable(framework-settings
        main.cpp
        localizedcontext.h
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
)
framework_link_i18n(framework-settings)

# The pages are the KCM's own, so both UIs stay in step; aliasing them to the
# module root lets Main.qml use them by name
set(SHARED_QML_FILES
        BatteryPage.qml
        HintLabel.qml
        InputPage.qml
        OverviewPage.qml
        Pages.qml
        SchedulePage.qml
        SettingComboBox.qml
        StatusMessages.qml
        SystemPage.qml
        ThermalPage.qml
)
list(TRANSFORM SHARED_QML_FILES PREPEND ${CMAKE_SOURCE_DIR}/kcm/ui/ OUTPUT_VARIABLE SHARED_QML_PATHS)
foreach(qml_file ${SHARED_QML_FILES})
    set_source_files_properties(${CMAKE_SOURCE_DIR}/kcm/ui/${qml_file} PROPERTIES QT_RESOURCE_ALIAS ${qml_file})
endforeach()

set(GUI_QML_FILES
        Main.qml
        CloseGuard.qml
        SettingsTabButton.qml
)

qt_add_qml_module(framework-settings
        URI Framework.Settings
        VERSION 1.0
        # Kirigami's QML plugins load at runtime; the import scan only matters for
        # static Qt, and warns that Kirigami exports no plugin targets to link
        NO_IMPORT_SCAN
        QML_FILES
        ${GUI_QML_FILES}
        ${SHARED_QML_PATHS}
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
        set_target_properties(gui-qml-runtime-tests PROPERTIES QT_QML_MODULE_NO_IMPORT_SCAN TRUE)
        target_compile_definitions(gui-qml-runtime-tests PRIVATE TRANSLATION_DOMAIN="kcm_framework")
        target_include_directories(gui-qml-runtime-tests PRIVATE ${CMAKE_CURRENT_SOURCE_DIR})
        target_link_libraries(gui-qml-runtime-tests PRIVATE
                Qt6::Gui
                Qt6::Qml
                Qt6::QuickTest
        )
        framework_link_i18n(gui-qml-runtime-tests)
        # Stage the app's and the KCM's QML side by side, as the module has them,
        # so the tests can load Main.qml and the shared pages from one directory
        set(QML_TEST_DIR ${CMAKE_CURRENT_BINARY_DIR}/qml-tests)
        file(GLOB QML_TEST_FILES CONFIGURE_DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/tests/tst_*.qml)
        add_custom_target(gui-qml-test-sources
                COMMAND ${CMAKE_COMMAND} -E make_directory ${QML_TEST_DIR}/tests
                COMMAND ${CMAKE_COMMAND} -E copy_if_different ${GUI_QML_FILES} ${SHARED_QML_PATHS} ${QML_TEST_DIR}
                COMMAND ${CMAKE_COMMAND} -E copy_if_different ${QML_TEST_FILES} ${QML_TEST_DIR}/tests
                WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR})
        add_dependencies(gui-qml-runtime-tests gui-qml-test-sources)
        add_test(NAME gui-qml-runtime
                COMMAND gui-qml-runtime-tests -input ${QML_TEST_DIR}/tests)
        set_tests_properties(gui-qml-runtime PROPERTIES
                ENVIRONMENT "QT_QPA_PLATFORM=offscreen")
    else()
        message(STATUS "Qt Quick Test not found; skipping optional GUI runtime tests")
    endif()
endif()
