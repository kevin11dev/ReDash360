pragma Singleton
import QtQuick
import QtCore

// Settings > Preferences: the dashboard's own settings, saved in
// ReDash360.conf under [preferences] (the background under [theme])
QtObject {
    id: preferences

    // The picture behind the dashboard, as a file URL; "" = the grey one
    readonly property string background: theme.background

    // Pictures to choose from go in ~/.local/share/ReDash360/backgrounds
    readonly property string backgroundsFolder: UserProfile.dataFolder + "/backgrounds"

    // What's behind the dashboard right now: while you're choosing, the
    // picture you're on, so you see it before you pick it
    readonly property string shownBackground: previewing ? preview : theme.background
    property bool previewing: false
    property string preview

    // The dashboard's sounds, and how loud they are (0-100)
    readonly property bool soundEffects: saved.soundEffects
    readonly property int soundVolume: saved.soundVolume

    // "" = how your region writes the time, "12" = 3:45 PM, "24" = 15:45
    readonly property string clock: saved.clock

    function setBackground(file) {
        theme.background = file
    }

    function setSoundEffects(on) {
        saved.soundEffects = on
    }

    function setSoundVolume(percent) {
        saved.soundVolume = Math.max(0, Math.min(100, percent))
    }

    function setClock(format) {
        saved.clock = format
    }

    // The time the way the clock is set to show it (or as `format` would)
    function time(date, format) {
        const clock = format !== undefined ? format : preferences.clock
        const pattern = clock === "12" ? "h:mm AP"
                      : clock === "24" ? "HH:mm"
                      : Qt.locale().timeFormat(Locale.ShortFormat).replace(":ss", "")
        return date.toLocaleTimeString(Qt.locale(), pattern)
    }

    property Settings theme: Settings {
        category: "theme"
        property string background
    }

    property Settings saved: Settings {
        category: "preferences"
        property bool soundEffects: true
        property int soundVolume: 100
        property string clock
    }
}