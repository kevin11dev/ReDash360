import QtQuick

// The 360's on-screen keyboard, for everything you type: a grey top with the
// question and the text box, then the keys. Works with the controller (move
// with the d-pad, A presses a key, and the shortcuts printed on the keys),
// a real keyboard (just type; Enter is Done, Esc cancels) or the mouse.
//
//   Keyboard { id: keyboard; anchors.fill: parent }
//   keyboard.open({ title: "Change Motto", prompt: "Enter your motto.",
//                   text: UserProfile.motto, maxLength: 21,
//                   done: text => UserProfile.setDetail("motto", text) })
FocusScope {
    id: keyboard
    visible: false

    property string title
    property string prompt
    property string text
    property int maxLength: 100
    property bool password: false               // dots instead of letters (Wi-Fi passwords)
    property var done: null                     // function(text), when you press Done
    property string doneLabel: "Done"          // what the Done key says

    property int cursor: 0                      // where the next letter goes
    property bool caps: false
    property string keySet: "letters"           // "letters", "symbols" or "accents"

    // Which key the controller is on: a 12 x 5 grid of cells. Column 0 and
    // 11 are the big keys at the sides, row 4 is Backspace / Space.
    property int row: 1
    property int column: 1

    property Item returnFocusTo: null

    function open(options) {
        returnFocusTo = Window.activeFocusItem
        title = options.title || ""
        prompt = options.prompt || ""
        text = options.text || ""
        maxLength = options.maxLength || 100
        password = options.password || false
        done = options.done || null
        doneLabel = options.doneLabel || "Done"
        cursor = text.length
        caps = false
        keySet = "letters"
        row = 1; column = 1                     // on "q"
        visible = true
        forceActiveFocus()
        openAnimation.restart()
    }

    function close() {
        visible = false
        focus = false
        if (returnFocusTo)
            returnFocusTo.forceActiveFocus()
    }

    function finish() {
        const callback = done
        const result = text
        close()
        if (callback)
            callback(result)
    }

    // ---- Typing ----------------------------------------------------------

    function insert(chars) {
        if (text.length + chars.length > maxLength)
            return
        text = text.slice(0, cursor) + chars + text.slice(cursor)
        cursor += chars.length
    }

    function backspace() {
        if (cursor === 0)
            return
        text = text.slice(0, cursor - 1) + text.slice(cursor)
        cursor--
    }

    function deleteForward() {
        text = text.slice(0, cursor) + text.slice(cursor + 1)
    }

    function moveCursor(step) {
        cursor = Math.max(0, Math.min(text.length, cursor + step))
    }

    function toggleKeySet(name) {
        keySet = keySet === name ? "letters" : name
    }

    // ---- The keys --------------------------------------------------------

    readonly property var keySets: ({
        letters: ["1234567890", "qwertyuiop", "asdfghjkl-", "zxcvbnm_@."],
        symbols: ["!@#$%^&*()", "`~-_=+[]{}", "\\|;:'\",./?", "<>€£¥©®°±¿"],
        accents: ["àáâäãåæçèé", "êëìíîïñòóô", "öõøœùúûüýÿ", "ßðþłčšžřőű"],
    })

    // The letter on character key (r, c), with Caps applied
    function character(r, c) {
        const ch = keySets[keySet][r].charAt(c)
        return caps && ch !== "ß" ? ch.toUpperCase() : ch
    }

    // What's in a cell of the 12 x 5 grid
    function keyAt(r, c) {
        if (c === 0)
            return r < 2 ? "cursorLeft" : r < 4 ? "symbols" : "caps"
        if (c === 11)
            return r < 2 ? "cursorRight" : r < 4 ? "accents" : "done"
        if (r === 4)
            return c <= 5 ? "backspace" : "space"
        return "char"
    }

    function keyIdAt(r, c) {
        const key = keyAt(r, c)
        return key === "char" ? "char" + r + c : key
    }

    readonly property string focusedKey: keyIdAt(row, column)

    // Move with the d-pad: skip cells that belong to the key you're on, so
    // the wide keys take one press to cross. Left and right wrap around.
    function move(dr, dc) {
        const from = focusedKey
        let r = row, c = column
        for (let i = 0; i < 12; i++) {
            if (dc !== 0)
                c = (c + dc + 12) % 12
            else
                r = Math.max(0, Math.min(4, r + dr))
            if (keyIdAt(r, c) !== from || (dr !== 0 && (r === 0 || r === 4)))
                break
        }
        if (keyIdAt(r, c) !== from) {
            row = r
            column = c
        }
    }

    function press(id) {
        if (id.startsWith("char"))              // "char" + row + grid column (1 to 10)
            insert(character(Number(id.charAt(4)), Number(id.substring(5)) - 1))
        else if (id === "cursorLeft") moveCursor(-1)
        else if (id === "cursorRight") moveCursor(1)
        else if (id === "symbols") toggleKeySet("symbols")
        else if (id === "accents") toggleKeySet("accents")
        else if (id === "caps") caps = !caps
        else if (id === "backspace") backspace()
        else if (id === "space") insert(" ")
        else if (id === "done") finish()
    }

    // The controller's buttons arrive as keys without any text; a real
    // keyboard's letters come with their text, so the two never mix up
    Keys.onPressed: (event) => {
        const fromController = event.text === ""
        switch (event.key) {
        case Qt.Key_Up: move(-1, 0); break
        case Qt.Key_Down: move(1, 0); break
        case Qt.Key_Left: move(0, -1); break
        case Qt.Key_Right: move(0, 1); break
        case Qt.Key_Escape: close(); break
        case Qt.Key_Return:
        case Qt.Key_Enter:
            if (fromController) press(focusedKey)   // A
            else finish()                           // Enter on a keyboard
            break
        case Qt.Key_Backspace: backspace(); break
        case Qt.Key_Delete: deleteForward(); break
        case Qt.Key_Home: cursor = 0; break
        case Qt.Key_End: cursor = text.length; break
        case Qt.Key_Menu: finish(); break                  // Start
        case Qt.Key_PageUp: toggleKeySet("symbols"); break  // LT
        case Qt.Key_PageDown: toggleKeySet("accents"); break // RT
        case Qt.Key_CapsLock: caps = !caps; break          // left stick click
        default:
            if (fromController && event.key === Qt.Key_X) backspace()
            else if (fromController && event.key === Qt.Key_Y) insert(" ")
            else if (fromController && event.key === Qt.Key_Q) moveCursor(-1)   // LB
            else if (fromController && event.key === Qt.Key_E) moveCursor(1)    // RB
            else if (!fromController && event.text.length > 0 && event.text.charCodeAt(0) >= 32)
                insert(event.text)
            else
                return
        }
        event.accepted = true
    }

    // ---- What's on screen ------------------------------------------------

    Rectangle {
        id: backdrop
        anchors.fill: parent
        color: "#F0141416"

        MouseArea {                             // keeps clicks off the screen underneath
            anchors.fill: parent
            hoverEnabled: true
        }
    }

    Text {
        x: panel.x - 95
        anchors.verticalCenter: parent.top
        anchors.verticalCenterOffset: panel.y - 75
        text: keyboard.title
        color: "white"
        font.pixelSize: 48
    }

    Item {
        id: panel
        x: 215; y: 160
        width: 1490; height: 810

        // Top: the question and the text box
        Rectangle {
            width: parent.width; height: 291
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#8B8E94" }
                GradientStop { position: 1.0; color: "#5A6167" }
            }

            Text {
                x: 53; y: 50
                width: parent.width - 2 * x
                text: keyboard.prompt
                color: "white"
                font.pixelSize: 34
                wrapMode: Text.WordWrap
                maximumLineCount: 3
            }

            Rectangle {
                id: field
                x: 53; y: 198
                width: 1323; height: 66
                color: "#F4F4F4"
                clip: true

                readonly property string shown: keyboard.password ? "•".repeat(keyboard.text.length)
                                                                 : keyboard.text
                readonly property real cursorX: metrics.advanceWidth(shown.substring(0, keyboard.cursor))
                // Slide the text left once the cursor would go past the end
                readonly property real offset: Math.max(0, cursorX - (width - 40))

                FontMetrics { id: metrics; font: fieldText.font }

                Text {
                    id: fieldText
                    x: 16 - field.offset
                    anchors.verticalCenter: parent.verticalCenter
                    text: field.shown
                    color: "#222222"
                    font.pixelSize: 38
                }

                Rectangle {                     // the blinking cursor
                    x: 16 - field.offset + field.cursorX
                    anchors.verticalCenter: parent.verticalCenter
                    width: 3; height: 44
                    color: "#222222"

                    SequentialAnimation on opacity {
                        running: keyboard.visible
                        loops: Animation.Infinite
                        NumberAnimation { to: 1; duration: 0 }
                        PauseAnimation { duration: 500 }
                        NumberAnimation { to: 0; duration: 0 }
                        PauseAnimation { duration: 500 }
                    }
                }

                MouseArea {                     // click in the text to move the cursor
                    anchors.fill: parent
                    onClicked: (mouse) => {
                        let best = 0
                        for (let i = 0; i <= field.shown.length; i++) {
                            const x = 16 - field.offset + metrics.advanceWidth(field.shown.substring(0, i))
                            if (x <= mouse.x + 6)
                                best = i
                        }
                        keyboard.cursor = best
                    }
                }
            }
        }

        // Bottom: the keys
        Rectangle {
            y: 291
            width: parent.width; height: parent.height - y
            color: "#E8E8E8"

            // Left column: Cursor (LB), Symbols (LT), Caps (left stick)
            BigKey { x: 53; y: 55; keyId: "cursorLeft"; label: "Cursor"; badge: "LB"; arrow: "left" }
            BigKey { x: 53; y: 195; keyId: "symbols"; label: "Symbols"; badge: "LT"
                     active: keyboard.keySet === "symbols" }
            BigKey { x: 53; y: 335; keyId: "caps"; label: "Caps"; badge: "L"; round: true
                     active: keyboard.caps }

            // The 40 letters, numbers and symbols
            Repeater {
                model: 40
                Key {
                    required property int index
                    readonly property int r: Math.floor(index / 10)
                    readonly property int c: index % 10
                    x: 305 + c * 88; y: 55 + r * 70
                    width: 80; height: 64
                    keyId: "char" + r + (c + 1)
                    label: keyboard.character(r, c)
                    onClicked: keyboard.insert(label)
                }
            }

            // Backspace (X) and Space (Y)
            Key {
                x: 305; y: 402
                width: 435; height: 65
                keyId: "backspace"
                Row {
                    x: 18
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10
                    Circle { button: "X" }
                    Text { anchors.verticalCenter: parent.verticalCenter; text: "Backspace"; color: parent.parent.ink; font.pixelSize: 32 }
                }
            }
            Key {
                x: 748; y: 402
                width: 434; height: 65
                keyId: "space"
                Row {
                    x: 18
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10
                    Circle { button: "Y" }
                    Text { anchors.verticalCenter: parent.verticalCenter; text: "Space"; color: parent.parent.ink; font.pixelSize: 32 }
                }
            }

            // Right column: Cursor (RB), Accents (RT), Done (Start)
            BigKey { x: 1197; y: 55; keyId: "cursorRight"; label: "Cursor"; badge: "RB"; arrow: "right" }
            BigKey { x: 1197; y: 195; keyId: "accents"; label: "Accents"; badge: "RT"
                     active: keyboard.keySet === "accents" }
            BigKey { x: 1197; y: 335; keyId: "done"; label: keyboard.doneLabel; badge: "▶"; round: true;}
        }

        SequentialAnimation {
            id: openAnimation
            ParallelAnimation {
                NumberAnimation { target: backdrop; property: "opacity"; from: 0; to: 1; duration: 150 }
                NumberAnimation { target: panel; property: "scale"; from: 0.45; to: 1; duration: 250; easing.type: Easing.OutCubic }
                NumberAnimation { target: panel; property: "opacity"; from: 0.35; to: 1; duration: 250 }
            }
        }
    }

    Row {
        x: panel.x
        y: panel.y + panel.height + 15
        ButtonHint { button: "B"; label: "Cancel" }
    }

    // One key: grey with a thin border, green while the controller is on it
    component Key: Rectangle {
        id: key
        property string keyId
        property string label
        property bool active: false             // Caps on, Symbols showing...
        property bool showLabel: true           // false when the key draws its own
        readonly property bool focused: keyboard.focusedKey === keyId
        readonly property color ink: focused ? "white" : "#555555"
        signal clicked()

        color: focused ? "#008E00" : active ? "#C4C7CC" : "#EAEAEA"
        border.color: focused ? "#008E00" : "#CDCDCD"
        border.width: 1

        Text {
            anchors.centerIn: parent
            visible: key.showLabel && key.label !== ""
            text: key.label
            color: key.ink
            font.pixelSize: 32
        }

        MouseArea {
            anchors.fill: parent
            onClicked: {
                // Put the controller's spot on it too, then press it
                for (let r = 0; r < 5; r++)
                    for (let c = 0; c < 12; c++)
                        if (keyboard.keyIdAt(r, c) === key.keyId) {
                            keyboard.row = r
                            keyboard.column = c
                            if (key.keyId.startsWith("char"))
                                key.clicked()
                            else
                                keyboard.press(key.keyId)
                            return
                        }
            }
        }
    }

    // A big key at the side: its controller button above the name
    component BigKey: Key {
        id: big
        property string badge                   // "LB", "RT", "L", "▶"...
        property string arrow: ""               // "left" / "right" for the cursor keys
        property bool round: false
        width: 237; height: 132
        showLabel: false

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 24
            spacing: 4
            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: big.arrow === "left"
                text: "◀"
                color: big.ink
                font.pixelSize: 24
            }
            Rectangle {
                width: big.round ? 40 : 52; height: 36
                radius: big.round ? 18 : 8
                color: big.focused ? "white" : "#3C3C3C"            // the box
                Text {
                    anchors.centerIn: parent
                    text: big.badge
                    color: big.focused ? "#008E00" : "white"        // the letters on it
                    font.pixelSize: big.round ? 22 : 20
                    font.bold: true
                }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: big.arrow === "right"
                text: "▶"
                color: big.ink
                font.pixelSize: 24
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 76
            text: big.label
            color: big.ink
            font.pixelSize: 32
        }
    }

    // The coloured controller button drawn on Backspace and Space
    component Circle: Rectangle {
        property string button
        width: 34; height: 34
        radius: 17
        color: button === "X" ? "#2A6DD2" : "#E0B018"
        Text {
            anchors.centerIn: parent
            text: parent.button
            color: "white"
            font.pixelSize: 22
            font.bold: true
        }
    }
}