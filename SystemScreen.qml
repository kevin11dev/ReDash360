import QtQuick

// Settings > System, like the 360's System Info: what this PC is on the
// left, and how busy it is right now on the right (that part updates every
// couple of seconds while you look at it)
FocusScope {
    id: systemScreen
    visible: false

    property Item returnFocusTo: null

    readonly property var live: SystemInfo.live

    function open() {
        returnFocusTo = Window.activeFocusItem
        visible = true
        forceActiveFocus()
        panelAnimation.restart()
    }

    function close() {
        visible = false
        if (returnFocusTo)
            returnFocusTo.forceActiveFocus()
    }

    // "12.3 GB"
    function size(bytes) {
        return (bytes / (1024 * 1024 * 1024)).toFixed(1) + " GB"
    }

    // "9.8 of 31.3 GB in use"
    function amountOf(used, total) {
        return (used / (1024 * 1024 * 1024)).toFixed(1) + " of " + size(total) + " in use"
    }

    // "2 days, 3 hours", "3 hours, 12 minutes", "5 minutes"
    function duration(seconds) {
        const days = Math.floor(seconds / 86400)
        const hours = Math.floor(seconds % 86400 / 3600)
        const minutes = Math.floor(seconds % 3600 / 60)
        const parts = []
        if (days > 0)
            parts.push(days + (days === 1 ? " day" : " days"))
        if (hours > 0)
            parts.push(hours + (hours === 1 ? " hour" : " hours"))
        if (days === 0)
            parts.push(minutes + (minutes === 1 ? " minute" : " minutes"))
        return parts.join(", ")
    }

    // The readings only update while this is on screen
    Binding {
        target: SystemInfo
        property: "watching"
        value: systemScreen.visible
    }

    Keys.onEscapePressed: close()

    // Stops the mouse reaching the dashboard underneath
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
    }

    Text {
        x: 142
        anchors.verticalCenter: parent.top
        anchors.verticalCenterOffset: 120
        text: "System Info"
        color: "white"
        font.pixelSize: 50
    }

    Item {
        id: panel
        x: 300; y: 171
        width: 1320; height: 719

        // ---- What this PC is ----
        Rectangle {
            width: 760; height: parent.height
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#F4FBFA" }
                GradientStop { position: 1.0; color: "#D5DFE0" }
            }

            Column {
                x: 45; y: 24
                width: parent.width - 90
                Repeater {
                    model: SystemInfo.details
                    Item {
                        required property var modelData
                        width: parent.width
                        height: 74
                        Text {
                            y: 6
                            text: parent.modelData.label
                            color: "#5A6064"
                            font.pixelSize: 24
                        }
                        Text {
                            y: 32
                            width: parent.width
                            text: parent.modelData.value
                            color: "#222222"
                            font.pixelSize: 30
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }

        // ---- How busy it is ----
        Rectangle {
            x: 760
            width: 560; height: parent.height
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#C3C9CD" }
                GradientStop { position: 1.0; color: "#9EA6AA" }
            }

            Text {
                x: 40; y: 26
                text: "Right Now"
                color: "#2E3336"
                font.pixelSize: 36
            }

            Column {
                x: 40; y: 100
                width: parent.width - 80
                spacing: 34

                Meter {
                    label: "Processor"
                    amount: systemScreen.live.cpu !== undefined ? systemScreen.live.cpu : -1
                    temperature: systemScreen.live.cpuTemp !== undefined ? systemScreen.live.cpuTemp : -1
                }
                Meter {
                    label: "Graphics"
                    amount: systemScreen.live.gpu !== undefined ? systemScreen.live.gpu : -1
                    temperature: systemScreen.live.gpuTemp !== undefined ? systemScreen.live.gpuTemp : -1
                    detail: systemScreen.live.vramTotal > 0                 // its own memory
                            ? systemScreen.amountOf(systemScreen.live.vramUsed, systemScreen.live.vramTotal) : ""
                }
                Meter {
                    label: "Memory"
                    amount: systemScreen.live.memoryTotal > 0
                            ? Math.round(100 * systemScreen.live.memoryUsed / systemScreen.live.memoryTotal) : -1
                    detail: systemScreen.live.memoryTotal > 0
                            ? systemScreen.amountOf(systemScreen.live.memoryUsed, systemScreen.live.memoryTotal) : ""
                }
            }

            Text {
                x: 40
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 34
                visible: systemScreen.live.uptime > 0
                text: "On for " + systemScreen.duration(systemScreen.live.uptime || 0)
                color: "#2E3336"
                font.pixelSize: 30
            }
        }

        // Like the 360's lists: the panel grows out of the middle
        ParallelAnimation {
            id: panelAnimation
            NumberAnimation { target: panel; property: "scale"; from: 0.45; to: 1; duration: 250; easing.type: Easing.OutCubic }
            NumberAnimation { target: panel; property: "opacity"; from: 0.35; to: 1; duration: 250 }
        }
    }

    Row {
        x: 138; y: 973
        ButtonHint { button: "B"; label: "Back" }
    }

    // ---- Pieces ----------------------------------------------------------------

    // One reading: its name and number, a bar, then its temperature and any
    // extra detail underneath
    component Meter: Item {
        id: meter
        property string label
        property int amount: -1                 // 0-100, -1 when this PC can't tell
        property int temperature: -1            // °C, -1 when this PC can't tell
        property string detail

        readonly property string note: {
            if (amount < 0 && temperature < 0 && detail === "")
                return "Not reported on this PC"
            return [temperature >= 0 ? temperature + " °C" : "", detail].filter(t => t !== "").join("  ·  ")
        }

        width: parent.width
        height: 112

        Text {
            text: meter.label
            color: "#2E3336"
            font.pixelSize: 30
        }
        Text {
            anchors.right: parent.right
            text: meter.amount >= 0 ? meter.amount + "%" : "–"
            color: "#2E3336"
            font.pixelSize: 30
        }

        Rectangle {                             // the bar: green, red when nearly full
            y: 46
            width: parent.width; height: 22
            color: "#2B3033"
            Rectangle {
                width: parent.width * Math.max(0, Math.min(100, meter.amount)) / 100
                height: parent.height
                color: meter.amount >= 90 ? "#E8402A" : "#6BD12B"
                Behavior on width { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }
            }
        }

        Text {                                  // orange when hot, red when very hot
            y: 80
            width: parent.width
            text: meter.note
            color: meter.temperature >= 90 ? "#C0281C" : meter.temperature >= 80 ? "#B86A00" : "#3A4044"
            font.pixelSize: 26
            elide: Text.ElideRight
        }
    }
}