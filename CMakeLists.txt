cmake_minimum_required(VERSION 3.16)

project(ReDash360 VERSION 0.1 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 REQUIRED COMPONENTS Quick Network)

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
    src/main.cpp
)

# The dashboard's QML, in qml/
set(qml_files
    qml/Main.qml
    qml/Home.qml
    qml/Social.qml
    qml/Games.qml
    qml/Search.qml
    qml/SearchScreen.qml
    qml/Apps.qml
    qml/Settings.qml
    qml/Tile.qml
    qml/TilePage.qml
    qml/ButtonHint.qml
    qml/GameShelf.qml
    qml/GameSlot.qml
    qml/AppSlot.qml
    qml/Profile.qml
    qml/TileIcon.qml
    qml/Guide.qml
    qml/AppShelf.qml
    qml/GuideOverlay.qml
    qml/PowerMenu.qml
    qml/RecentShelf.qml
    qml/Pins.qml
    qml/UserProfile.qml
    qml/ProfileScreen.qml
    qml/Gamerpic.qml
    qml/PinShelf.qml
    qml/Sounds.qml
    qml/SoundBank.qml
    qml/MessageCard.qml
    qml/Keyboard.qml
    qml/GameDetails.qml
    qml/NetworkScreen.qml
    qml/StorageScreen.qml
    qml/ControllerPicture.qml
    qml/ControllerScreen.qml
    qml/BatteryIcon.qml
    qml/BatteryNotice.qml
    qml/PlatformBanner.qml
    qml/FolderPicker.qml
    qml/SystemScreen.qml
    qml/DisplaySoundScreen.qml
    qml/PreferencesScreen.qml
    qml/Preferences.qml
    qml/NewsTile.qml
    qml/NewsScreen.qml
    qml/AddOnsScreen.qml
    qml/UpdateScreen.qml
    qml/icons.js
)

# Inside the module each file keeps its plain name (Main.qml, not
# qml/Main.qml), so they all sit together and find each other, the
# singletons and icons.js
foreach (file IN LISTS qml_files)
    get_filename_component(name "${file}" NAME)
    set_source_files_properties("${file}" PROPERTIES QT_RESOURCE_ALIAS "${name}")
endforeach()

# Pins.qml is a singleton (one shared object, used as Pins.pin(...) etc.)
set_source_files_properties(qml/Pins.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)
set_source_files_properties(qml/UserProfile.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)
set_source_files_properties(qml/Sounds.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)
set_source_files_properties(qml/Preferences.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)

# The module: that QML, and the C++ in src/
qt_add_qml_module(appReDash360
    URI ReDash360
    QML_FILES ${qml_files}
    SOURCES
        src/gamepad.h src/gamepad.cpp
        src/virtualinput.h src/virtualinput.cpp
        src/controllercursor.h src/controllercursor.cpp
        src/appwindows.h src/appwindows.cpp
        src/updater.h src/updater.cpp
        src/launcher.h src/launcher.cpp
        src/gamelibrary.h src/gamelibrary.cpp
        src/roms.h src/roms.cpp
        src/pointer.h src/pointer.cpp
        src/applibrary.h src/applibrary.cpp
        src/achievements.h src/achievements.cpp
        src/network.h src/network.cpp
        src/storage.h src/storage.cpp
        src/systeminfo.h src/systeminfo.cpp
        src/audiosettings.h src/audiosettings.cpp
        src/displaysettings.h src/displaysettings.cpp
        src/autostart.h src/autostart.cpp
        src/news.h src/news.cpp
        src/loginscreen.h src/loginscreen.cpp
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
    PRIVATE Qt6::Quick Qt6::Network SDL2::SDL2
)

# The commit this is built from, so the dashboard can tell when GitHub has a
# newer one, and where updates come from. Only updater.cpp gets them, so a
# new commit doesn't make everything build again.
find_package(Git QUIET)
if (GIT_FOUND)
    execute_process(COMMAND ${GIT_EXECUTABLE} rev-parse HEAD
        WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
        OUTPUT_VARIABLE REDASH360_COMMIT OUTPUT_STRIP_TRAILING_WHITESPACE ERROR_QUIET)
endif()
set(REDASH360_REPO "kevin11dev/ReDash360" CACHE STRING "The GitHub repository updates come from")
set_source_files_properties(src/updater.cpp PROPERTIES COMPILE_DEFINITIONS
    "REDASH360_COMMIT=\"${REDASH360_COMMIT}\";REDASH360_REPO=\"${REDASH360_REPO}\"")
message(STATUS "ReDash360 version: ${REDASH360_COMMIT}")

# On Linux, D-Bus: for KWin, so apps opened from the dashboard fill the screen
if (UNIX AND NOT APPLE)
    find_package(Qt6 REQUIRED COMPONENTS DBus)
    target_link_libraries(appReDash360 PRIVATE Qt6::DBus)
    target_compile_definitions(appReDash360 PRIVATE HAVE_QTDBUS)
endif()

# For the code Qt generates, which includes the C++ headers by their plain names
target_include_directories(appReDash360 PRIVATE src)

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

# The app menu entry, the ReDash360 sessions (linux/CMakeLists.txt) and the
# login screen (sddm/CMakeLists.txt)
if (UNIX AND NOT APPLE)
    add_subdirectory(linux)
    add_subdirectory(sddm)
endif()