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

qt_add_qml_module(framework-settings
        URI Framework.Settings
        VERSION 1.0
        QML_FILES
        Main.qml
        OverviewPage.qml
        SchedulePage.qml
        SettingsTabButton.qml
)

install(TARGETS framework-settings DESTINATION ${KDE_INSTALL_BINDIR} COMPONENT gui)
install(FILES ../data/io.github.frameworkkcm.desktop
        DESTINATION ${CMAKE_INSTALL_DATAROOTDIR}/applications COMPONENT gui)
