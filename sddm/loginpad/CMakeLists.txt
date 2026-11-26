cmake_minimum_required(VERSION 3.16)

# The controller for ReDash360's login screen (the SDDM theme in ../redash360):
# a QML module installed with Qt's own, where the login screen can find it.
#   cmake -B build -S . && cmake --build build && sudo cmake --install build
project(ReDash360LoginPad LANGUAGES CXX)

find_package(Qt6 REQUIRED COMPONENTS Quick)
find_package(SDL2 REQUIRED)

qt_standard_project_setup()

# Install next to Qt's own QML modules (/usr/lib/qt6/qml on Arch)
if (CMAKE_SOURCE_DIR STREQUAL CMAKE_CURRENT_SOURCE_DIR AND CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT)
    set(CMAKE_INSTALL_PREFIX "${QT6_INSTALL_PREFIX}" CACHE PATH "" FORCE)
endif()

qt_add_qml_module(redash360loginpad
    URI ReDash360.LoginPad
    VERSION 1.0
    PLUGIN_TARGET redash360loginpad
    OUTPUT_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/ReDash360/LoginPad"
    SOURCES loginpad.h loginpad.cpp
)

target_link_libraries(redash360loginpad PRIVATE Qt6::Quick SDL2::SDL2)

# controllerwatch.h, shared with the dashboard
target_include_directories(redash360loginpad PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}/../../src")

set(destination "${QT6_INSTALL_QML}/ReDash360/LoginPad")
install(TARGETS redash360loginpad LIBRARY DESTINATION "${destination}")
install(FILES "${CMAKE_CURRENT_BINARY_DIR}/ReDash360/LoginPad/qmldir"
              "${CMAKE_CURRENT_BINARY_DIR}/ReDash360/LoginPad/redash360loginpad.qmltypes"
        DESTINATION "${destination}")
