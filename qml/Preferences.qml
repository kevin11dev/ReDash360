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

    // Where the search tab looks on the web
    readonly property var searchEngines: [
        { id: "google", name: "Google", site: "google.com", url: "https://www.google.com/search?q=" },
        { id: "duckduckgo", name: "DuckDuckGo", site: "duckduckgo.com", url: "https://duckduckgo.com/?q=" },
        { id: "brave", name: "Brave Search", site: "search.brave.com", url: "https://search.brave.com/search?q=" },
        { id: "bing", name: "Bing", site: "bing.com", url: "https://www.bing.com/search?q=" },
        { id: "ecosia", name: "Ecosia", site: "ecosia.org", url: "https://www.ecosia.org/search?q=" },
    ]
    readonly property var searchEngine: searchEngines.find(e => e.id === saved.searchEngine) || searchEngines[0]

    // Where Home's News tile gets gaming news (the site's RSS feed), next to
    // the news about your Steam games
    readonly property var newsSites: [
        { id: "gamingonlinux", name: "GamingOnLinux", site: "", url: "https://www.gamingonlinux.com/article_rss.php" },
        { id: "pcgamer", name: "PC Gamer", site: "", url: "https://www.pcgamer.com/rss/" },
        { id: "rockpapershotgun", name: "Rock Paper Shotgun", site: "", url: "https://www.rockpapershotgun.com/feed" },
        { id: "eurogamer", name: "Eurogamer", site: "", url: "https://www.eurogamer.net/feed" },
        { id: "off", name: "Off", site: "Just your Steam games", url: "" },
    ]
    readonly property var newsSite: newsSites.find(s => s.id === saved.newsSite) || newsSites[0]

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

    function setSearchEngine(id) {
        saved.searchEngine = id
    }

    function setNewsSite(id) {
        saved.newsSite = id
    }

    // The web page with your search engine's results for text
    function webSearch(text) {
        return searchEngine.url + encodeURIComponent(text)
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
        property string searchEngine: "google"
        property string newsSite: "gamingonlinux"
    }
}