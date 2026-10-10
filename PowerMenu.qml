import QtQuick

// Turn Off, in the style of the 360's tall message card
MessageCard{
    id: power

    readonly property bool onWindows: Qt.platform.os === "windows"

    title: "Turn Off"
    message: "What would you like to do?"
    defaultIndex: 0
    options: [
        {label: "Turn Off", run: () => Launcher.run(power.onWindows ? "shutdown /s /t 0" : "systemctl poweroff")},
        {label: "Restart", run: () => Launcher.run(power.onWindows ? "shutdown /r /t 0" : "systemctl reboot")},
        {label: "Exit to Desktop", run: () => Qt.quit()},
        {label: "Cancel", run: () => {}}
    ]
}