import QtQuick
import QtQuick.Shapes

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
            BigKey { x: 53; y: 55; keyId: "cursorLeft"; label: "Cursor"; badge: "LB" }
            BigKey { x: 53; y: 195; keyId: "symbols"; label: "Symbols"; badge: "LT"
                     active: keyboard.keySet === "symbols" }
            BigKey { x: 53; y: 335; keyId: "caps"; label: "Caps"; badge: "L"
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
            BigKey { x: 1197; y: 55; keyId: "cursorRight"; label: "Cursor"; badge: "RB" }
            BigKey { x: 1197; y: 195; keyId: "accents"; label: "Accents"; badge: "RT"
                     active: keyboard.keySet === "accents" }
            BigKey { x: 1197; y: 335; keyId: "done"; label: keyboard.doneLabel; badge: "Start" }
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

    // A big key at the side: its controller button above the name, drawn like
    // the 360's own: a bumper with an arrow (LB, RB), a trigger (LT, RT), the
    // left stick (L) or the Start button
    component BigKey: Key {
        id: big
        property string badge                   // "LB", "RB", "LT", "RT", "L" or "Start"
        width: 237; height: 132
        showLabel: false

        Glyph {
            anchors.horizontalCenter: parent.horizontalCenter
            kind: big.badge
            focused: big.focused
            keyColor: big.color
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 76
            text: big.label
            color: big.ink
            font.pixelSize: 32
        }
    }

    // A controller button's picture, traced from the 360's own keyboard: dark
    // grey with its letters cut out in the key's colour, or white on the key
    // that's selected
    component Glyph: Shape {
        id: glyph
        property string kind
        property bool focused: false
        property color keyColor: "#EAEAEA"
        readonly property color ink: focused ? "white" : "#474A4F"
        readonly property var drawing: glyphs[kind] || glyphs.Start

        // Each one's size, how far down the key it sits, its outline, its
        // letters, and the holes in them (B and R)
        readonly property var glyphs: ({
            LB: { width: 81.1, height: 35.9, top: 21.8,
                shape: "M0,20.6 L14.8,5.7 14.8,13.6 27.7,13.6 27.7,27.7 14.8,27.7 14.8,35.6 Z M30.5,27.3 C30.5,12 43.7,0 58.6,0 H75.8 Q81.1,0 81.1,5.3 V30.6 Q81.1,35.9 75.8,35.9 H35.8 Q30.5,35.9 30.5,30.6 Z",
                letters: "M46.9,9.2 H50.2 V27.4 H46.9 Z M46.9,24.6 H56.2 V27.4 H46.9 Z M59.6,9.2 H66.9 C69.4,9.2 71.4,11.3 71.4,13.7 V15.3 C71.4,17.8 69.4,19.8 66.9,19.8 H59.6 Z M59.6,16.5 H67.5 C70.1,16.5 72.2,18.5 72.2,21.1 V22.8 C72.2,25.3 70.1,27.4 67.5,27.4 H59.6 Z",
                counters: "M62.9,12.6 H66.9 C67.6,12.6 68.1,13.1 68.1,13.7 V15.3 C68.1,15.9 67.6,16.5 66.9,16.5 H62.9 Z M62.9,19.8 H67.5 C68.3,19.8 68.9,20.4 68.9,21.1 V22.8 C68.9,23.5 68.3,24.1 67.5,24.1 H62.9 Z" },
            RB: { width: 83.8, height: 35.9, top: 21.8,
                shape: "M53.3,27.3 C53.3,12 40.1,0 25.2,0 H5.3 Q0,0 0,5.3 V30.6 Q0,35.9 5.3,35.9 H48 Q53.3,35.9 53.3,30.6 Z M83.8,20.6 L68.9,5.7 68.9,13.6 56.1,13.6 56.1,27.7 68.9,27.7 68.9,35.6 Z",
                letters: "M8.9,9.2 H12.2 V27.4 H8.9 Z M8.9,9.2 H16 C18.8,9.2 21.1,11.6 21.1,14.4 V15.6 C21.1,18.4 18.8,20.7 16,20.7 H8.9 Z M13.1,17.4 L16.8,17.4 21.5,27.4 17.8,27.4 Z M24.3,9.2 H31.6 C34.1,9.2 36.1,11.3 36.1,13.7 V15.3 C36.1,17.8 34.1,19.8 31.6,19.8 H24.3 Z M24.3,16.5 H32.2 C34.8,16.5 36.9,18.5 36.9,21.1 V22.8 C36.9,25.3 34.8,27.4 32.2,27.4 H24.3 Z",
                counters: "M12.2,12.6 H16 C17,12.6 17.8,13.4 17.8,14.4 V15.6 C17.8,16.6 17,17.4 16,17.4 H12.2 Z M27.6,12.6 H31.6 C32.3,12.6 32.8,13.1 32.8,13.7 V15.3 C32.8,15.9 32.3,16.5 31.6,16.5 H27.6 Z M27.6,19.8 H32.2 C33,19.8 33.6,20.4 33.6,21.1 V22.8 C33.6,23.5 33,24.1 32.2,24.1 H27.6 Z" },
            LT: { width: 38.6, height: 47.5, top: 16.9,
                shape: "M2.9,3.3 Q2.9,0 6.2,0 H33.2 Q38.6,0 38.6,5.4 V28 C38.6,38.7 29.5,47.5 18.3,47.5 H4.9 Q0,47.5 0,42.6 C8.1,31.1 9,15.6 2.9,3.3 Z",
                letters: "M13,13.9 H15.7 V30 H13 Z M13,27.9 H21.5 V30 H13 Z M21.5,13.9 H31.9 V16.1 H21.5 Z M25.4,13.9 H28.1 V30 H25.4 Z",
                counters: "" },
            RT: { width: 38.6, height: 47.5, top: 16.9,
                shape: "M35.6,3.3 Q35.6,0 32.4,0 H5.4 Q0,0 0,5.4 V28 C0,38.7 9.1,47.5 20.2,47.5 H33.7 Q38.6,47.5 38.6,42.6 C30.5,31.1 29.5,15.6 35.6,3.3 Z",
                letters: "M5.7,13.9 H8.4 V30 H5.7 Z M5.7,13.9 H10.9 C13.4,13.9 15.4,15.9 15.4,18.3 V19.3 C15.4,21.7 13.4,23.7 10.9,23.7 H5.7 Z M8.8,21 L11.6,21 15.4,30 12.6,30 Z M16.1,13.9 H26.4 V16.1 H16.1 Z M19.9,13.9 H22.6 V30 H19.9 Z",
                counters: "M8.4,16.6 H10.9 C11.9,16.6 12.7,17.4 12.7,18.3 V19.3 C12.7,20.3 11.9,21 10.9,21 H8.4 Z" },
            L: { width: 59.3, height: 48.4, top: 16.8,
                shape: "M18.5,0 L40.9,0 29.7,11.1 Z M13.5,12 H45.9 C53.3,12 59.3,18 59.3,25.5 C59.3,32.9 53.3,38.9 45.9,38.9 H41.6 V45 Q41.6,48.4 38.2,48.4 H21.1 Q17.8,48.4 17.8,45 V38.9 H13.5 C6,38.9 0,32.9 0,25.5 C0,18 6,12 13.5,12 Z",
                letters: "M26.3,18.1 H29.4 V34.2 H26.3 Z M26.3,31.5 H35.3 V34.2 H26.3 Z",
                counters: "" },
            Start: { width: 42.7, height: 36.8, top: 22.1,
                shape: "M0,18.4 C0,8.2 9.6,0 21.4,0 C33.1,0 42.7,8.2 42.7,18.4 C42.7,28.6 33.1,36.8 21.4,36.8 C9.6,36.8 0,28.6 0,18.4 Z",
                letters: "M14.5,8.3 L32.5,18.4 14.5,28.6 Z",
                counters: "" }
        })

        y: drawing.top
        width: drawing.width
        height: drawing.height
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: "transparent"
            fillColor: glyph.ink
            fillRule: ShapePath.WindingFill
            PathSvg { path: glyph.drawing.shape }
        }
        ShapePath {
            strokeColor: "transparent"
            fillColor: glyph.keyColor
            fillRule: ShapePath.WindingFill
            PathSvg { path: glyph.drawing.letters }
        }
        ShapePath {
            strokeColor: "transparent"
            fillColor: glyph.ink
            fillRule: ShapePath.WindingFill
            PathSvg { path: glyph.drawing.counters }
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