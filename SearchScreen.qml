import QtQuick

// The search tab's keyboard: type what you're looking for, and Search opens
// your web browser on your search engine's results (Settings > Preferences >
// Search Engine)
FocusScope {
    id: searchScreen
    visible: false

    property Item returnFocusTo: null

    function open() {
        returnFocusTo = Window.activeFocusItem
        visible = true
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

    function close() {
        if (!visible)
            return
        keyboard.visible = false
        visible = false
        if (returnFocusTo)
            returnFocusTo.forceActiveFocus()
    }

    // Search or B on the keyboard: back to the search tab
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