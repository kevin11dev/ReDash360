import QtQuick

Rectangle{
    id: banner

    property string source

    readonly property var looks: ({
        Steam: { top: "#2A475E", bottom: "#171D25", line: "#66C0F4", icon: "steam,com.valvesoftware.Steam" },
        Heroic: { top: "#7246D6", bottom: "#3A1D82", line: "#B9A2FF", icon: "heroic,com.heroicgameslauncher.hgl" },
        Faugus: { top: "#1E7F75", bottom: "#0D4842", line: "#6EE6D6", icon: "faugus-launcher,io.github.Faugus.faugus-launcher" }
    })
    readonly property var look: looks[source] || null

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
            source: banner.look ? "image://appicon/" + banner.look.icon : ""
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