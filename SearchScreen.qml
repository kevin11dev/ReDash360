import QtQuick

// The keyboard for searching. open(): what you type opens in your web browser,
// on your search engine (Settings > Preferences > Search Engine).
// open("apps"): the apps whose names match, in the my apps list.
FocusScope {
    id: searchScreen
    visible: false

    property Item returnFocusTo: null

    // Search Apps found these (maybe none): show them
    signal appsFound(string title, var apps)

    function open(what) {
        returnFocusTo = Window.activeFocusItem
        visible = true
        if (what === "apps") {
            keyboard.open({
                title: "Search Apps",
                prompt: "Enter the name of an app.",
                doneLabel: "Search",
                done: text => {
                    if (text.trim() !== "")
                        appsFound("apps matching “" + text.trim() + "”", matching(AppLibrary.all(), text))
                }
            })
        } else {
            keyboard.open({
                title: "Search",
                prompt: "Search " + Preferences.searchEngine.name + ". The results open in your web browser.",
                doneLabel: "Search",
                done: text => {
                    if (text.trim() !== "")
                        Qt.openUrlExternally(Preferences.webSearch(text.trim()))
                }
            })
        }
    }

    function close() {
        if (!visible)
            return
        keyboard.visible = false
        visible = false
        if (returnFocusTo)
            returnFocusTo.forceActiveFocus()
    }

    // ---- Finding apps --------------------------------------------------------

    // "Pokémon™ Legends: Arceus" -> "pokemon legends arceus", so you can type it
    // without the accents and symbols
    function words(text) {
        return text.normalize("NFD").replace(/[\u0300-\u036f]/g, "").toLowerCase()
                   .replace(/[\s!-\/:-@\[-`{-~\u00a0-\u00bf\u00d7\u00f7\u2000-\u206f\u2100-\u214f\u3000-\u303f\uff01-\uff0f]+/g, " ")
                   .trim()
    }

    // How well a name matches: 0 it starts with what you typed, 1 every word
    // you typed starts a word in it, 2 they're in it somewhere, -1 not at all
    function rank(name, wanted) {
        const have = " " + words(name)
        if (!wanted.every(w => have.includes(w)))
            return -1
        if (have.startsWith(" " + wanted.join(" ")))
            return 0
        return wanted.every(w => have.includes(" " + w)) ? 1 : 2
    }

    // The ones whose names match, best first, then A-Z
    function matching(things, text) {
        const wanted = words(text).split(" ").filter(w => w !== "")
        if (wanted.length === 0)
            return []
        return things.map(thing => ({ thing: thing, rank: rank(thing.name, wanted) }))
                     .filter(m => m.rank >= 0)
                     .sort((a, b) => a.rank - b.rank || a.thing.name.localeCompare(b.thing.name))
                     .map(m => m.thing)
    }

    // Search or B on the keyboard: back to where you were
    Connections {
        target: keyboard
        function onVisibleChanged() {
            if (!keyboard.visible)
                searchScreen.close()
        }
    }

    Keyboard {
        id: keyboard
        anchors.fill: parent
    }
}