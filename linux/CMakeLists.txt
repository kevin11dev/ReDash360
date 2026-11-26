# What a Linux install adds besides the program: ReDash360 in the app menu,
# and the ReDash360 sessions. Pick one at the login screen and the dashboard
# is your desktop:
#   ReDash360 (Plasma): Plasma's Wayland session (KWin, and Plasma's
#     services for sound, networks, power and so on) with the dashboard in
#     place of Plasma's desktop and panels, and without Plasma's splash screen
#   ReDash360 (Hyprland): your own Hyprland setup, through uwsm, with the
#     dashboard on top
# The login screen tells the session which one it is in DESKTOP_SESSION (the
# session file's name), and systemd starts the dashboard by it.

include(GNUInstallDirs)

configure_file(app.desktop.in appReDash360.desktop @ONLY)
install(FILES ${CMAKE_CURRENT_BINARY_DIR}/appReDash360.desktop
    DESTINATION ${CMAKE_INSTALL_DATADIR}/applications)

set(SESSIONS ${CMAKE_INSTALL_DATADIR}/wayland-sessions)
set(USER_UNITS lib/systemd/user)

configure_file(redash360.service.in redash360.service @ONLY)
install(FILES ${CMAKE_CURRENT_BINARY_DIR}/redash360.service DESTINATION ${USER_UNITS})
install(FILES start-redash360.conf DESTINATION ${USER_UNITS}/graphical-session.target.d RENAME redash360.conf)

# Controller as mouse: the person at the screen may use /dev/uinput
install(FILES 60-redash360-uinput.rules DESTINATION lib/udev/rules.d)

find_program(STARTPLASMA_WAYLAND startplasma-wayland)
if (STARTPLASMA_WAYLAND)
    # Plasma's own session starts through this when there's no D-Bus yet;
    # where it is depends on the distribution
    find_program(PLASMA_DBUS_RUN_SESSION plasma-dbus-run-session-if-needed
        PATHS /usr/lib /usr/libexec /usr/lib/${CMAKE_LIBRARY_ARCHITECTURE}/libexec
        NO_DEFAULT_PATH)
    set(PLASMA_EXEC "${STARTPLASMA_WAYLAND}")
    if (PLASMA_DBUS_RUN_SESSION)
        set(PLASMA_EXEC "${PLASMA_DBUS_RUN_SESSION} ${STARTPLASMA_WAYLAND}")
    endif()
    message(STATUS "ReDash360 (Plasma) session: ${PLASMA_EXEC}")

    configure_file(plasma-session.desktop.in redash360-plasma.desktop @ONLY)
    install(FILES ${CMAKE_CURRENT_BINARY_DIR}/redash360-plasma.desktop DESTINATION ${SESSIONS})
    install(FILES not-in-redash360.conf DESTINATION ${USER_UNITS}/plasma-plasmashell.service.d RENAME redash360.conf)
    install(FILES not-in-redash360.conf DESTINATION ${USER_UNITS}/plasma-ksplash.service.d RENAME redash360.conf)
else()
    message(STATUS "ReDash360 (Plasma) session: needs KDE Plasma (startplasma-wayland), so not installing it")
endif()

# uwsm starts Hyprland from Hyprland's own session file
find_program(UWSM uwsm)
find_file(HYPRLAND_SESSION hyprland.desktop
    PATHS /usr/share/wayland-sessions /usr/local/share/wayland-sessions
    NO_DEFAULT_PATH)
if (UWSM AND HYPRLAND_SESSION)
    message(STATUS "ReDash360 (Hyprland) session: uwsm with ${HYPRLAND_SESSION}")
    install(FILES hyprland-session.desktop DESTINATION ${SESSIONS} RENAME redash360-hyprland.desktop)
else()
    message(STATUS "ReDash360 (Hyprland) session: needs Hyprland and uwsm, so not installing it")
endif()
