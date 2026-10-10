import QtQuick

// Turn Off: the 360's tall "Turn Off Console" card
MessageCard{
    id: power

    readonly property bool onWindows: Qt.platform.os === "windows"

    title: "Turn Off Console"
    message: "Turning off the console will also disconnect all controllers."
    options: [
        {label: "Turn Off Console", run: () => Launcher.run(power.onWindows ? "shutdown /s /t 0" : "systemctl poweroff")},
        {label: "Restart Console", run: () => Launcher.run(power.onWindows ? "shutdown /r /t 0" : "systemctl reboot")},
        {label: "Exit to Desktop", run: () => Qt.quit()},
        {label: "Cancel", run: () => {}}
    ]
}