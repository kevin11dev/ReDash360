include(GNUInstallDirs)

add_subdirectory(loginpad)

install(DIRECTORY redash360 DESTINATION ${CMAKE_INSTALL_DATADIR}/sddm/themes)
install(FILES redash360.conf
    DESTINATION ${CMAKE_INSTALL_FULL_SYSCONFDIR}/sddm.conf.d
    RENAME zz-redash360.conf)
