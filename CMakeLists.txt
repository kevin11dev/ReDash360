cmake_minimum_required(VERSION 3.16)

project(ReDash360 VERSION 0.1 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 REQUIRED COMPONENTS Quick)

if (WIN32)
    list(APPEND CMAKE_PREFIX_PATH "C:/SDL2/x86_64-w64-mingw32")
endif()

find_package(SDL2 REQUIRED)
find_package(LayerShellQt QUIET)

qt_standard_project_setup(REQUIRES 6.10)

# Content of downloaded design from Figma to Qt or similar
if (EXISTS "${CMAKE_CURRENT_LIST_DIR}/importedcontent/CMakeLists.txt")
    add_subdirectory(${CMAKE_CURRENT_LIST_DIR}/importedcontent)
endif()

qt_add_executable(appReDash360
    main.cpp
)

# Pins.qml is a singleton (one shared object, used as Pins.pin(...) etc.)
set_source_files_properties(Pins.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)
set_source_files_properties(UserProfile.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)

qt_add_qml_module(appReDash360
    URI ReDash360
    QML_FILES
        Main.qml
        Home.qml
        Social.qml
        Games.qml
        Bing.qml
        MoviesTv.qml
        Apps.qml
        Settings.qml
        Tile.qml
        TilePage.qml
        ButtonHint.qml
        GameShelf.qml
        GameSlot.qml
        AppSlot.qml
        Profile.qml
        TileIcon.qml
        Guide.qml
        AppShelf.qml
        GuideOverlay.qml
        PowerMenu.qml
        RecentShelf.qml
        Pins.qml
        UserProfile.qml
        ProfileScreen.qml
        Gamerpic.qml
        PinShelf.qml
        icons.js
    SOURCES
        gamepad.h gamepad.cpp
        launcher.h launcher.cpp
        gamelibrary.h gamelibrary.cpp
        pointer.h pointer.cpp
        applibrary.h applibrary.cpp
        achievements.h achievements.cpp
)

# Qt for iOS sets MACOSX_BUNDLE_GUI_IDENTIFIER automatically since Qt 6.1.
# If you are developing for iOS or macOS you should consider setting an
# explicit, fixed bundle identifier manually though.
set_target_properties(appReDash360 PROPERTIES
#    MACOSX_BUNDLE_GUI_IDENTIFIER com.example.appReDash360
    MACOSX_BUNDLE_BUNDLE_VERSION ${PROJECT_VERSION}
    MACOSX_BUNDLE_SHORT_VERSION_STRING ${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}
    MACOSX_BUNDLE TRUE
    WIN32_EXECUTABLE TRUE
)

target_link_libraries(appReDash360
    PRIVATE Qt6::Quick SDL2::SDL2
)

if (LayerShellQt_FOUND)
    target_link_libraries(appReDash360 PRIVATE LayerShellQt::Interface)
    target_compile_definitions(appReDash360 PRIVATE HAVE_LAYER_SHELL)
    message(STATUS "Guide overlay: building with layer-shell-qt")
endif()

install(TARGETS appReDash360
    BUNDLE DESTINATION .
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)
