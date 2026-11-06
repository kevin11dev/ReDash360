import QtQuick

Rectangle{
    id: banner

    property string source

    readonly property var looks: ({
        Steam: { top: "#2A475E", bottom: "#171D25", line: "#66C0F4", icon: "steam,com.valvesoftware.Steam" },
        Heroic: { top: "#7246D6", bottom: "#3A1D82", line: "#B9A2FF", icon: "heroic,com.heroicgameslauncher.hgl" },
        Faugus: { top: "#1E7F75", bottom: "#0D4842", line: "#6EE6D6", icon: "faugus-launcher,io.github.Faugus.faugus-launcher" }
    })
    // ROMs: each console's banner in its maker's colours, with no icon
    readonly property var makers: ({
        Nintendo: { top: "#E4000F", bottom: "#8A0009", line: "#FF8A8A", icon: "" },
        Sony: { top: "#2156B8", bottom: "#0C2560", line: "#7FB0FF", icon: "" },
        Sega: { top: "#2F73D0", bottom: "#123C7A", line: "#8CC2FF", icon: "" },
        Microsoft: { top: "#1A8A1A", bottom: "#0A4A0A", line: "#8CE08C", icon: "" },
        Other: { top: "#5C5F66", bottom: "#2A2C30", line: "#C5C8CE", icon: "" }
    })
    readonly property var consoles: ({
        "NES": "Nintendo", "SNES": "Nintendo", "N64": "Nintendo", "Game Boy": "Nintendo", "Game Boy Color": "Nintendo",
        "GBA": "Nintendo", "DS": "Nintendo", "GameCube": "Nintendo", "Wii": "Nintendo", "Wii U": "Nintendo",
        "PlayStation": "Sony", "PS2": "Sony", "PS3": "Sony", "PSP": "Sony",
        "Genesis": "Sega", "Master System": "Sega", "Game Gear": "Sega", "Sega CD": "Sega", "Saturn": "Sega",
        "Dreamcast": "Sega", "Xbox": "Microsoft", "Xbox 360": "Microsoft",
        "PC Engine": "Other", "Atari 2600": "Other", "DOS": "Other", "ScummVM": "Other"
    })
    readonly property var look: looks[source] || makers[consoles[source]] || null

    visible: look !== null
    height: 42
    gradient: Gradient {
        GradientStop{position: 0; color: banner.look ? banner.look.top : "black"}
        GradientStop{position: 1; color: banner.look ? banner.look.bottom : "black"}
    }

    Rectangle{
        width: parent.width; height: 1
        color: "#40FFFFFF"
    }

    Row{
        anchors.centerIn: parent
        spacing: 9

        Image{
            anchors.verticalCenter: parent.verticalCenter
            width: 26; height: 26
            source: banner.look && banner.look.icon ? "image://appicon/" + banner.look.icon : ""
            sourceSize: Qt.size(52, 52)
            visible: status === Image.Ready && implicitWidth > 0
            asynchronous: true
        }

        Text{
            anchors.verticalCenter: parent.verticalCenter
            text: banner.source.toUpperCase()
            color: "white"
            font.pixelSize: 21
            font.bold: true
            font.letterSpacing: 2.5
        }
    }

    Rectangle{
        anchors.bottom: parent.bottom
        width: parent.width; height: 2
        color: banner.look ? banner.look.line : "transparent"
    }
}