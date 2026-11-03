import QtQuick

Row{
    id: hint

    property string button
    property string label

    spacing: 12

    Rectangle{
        width: 34
        height: 34
        radius: width / 2
        anchors.verticalCenter: parent.verticalCenter
        color:{
            switch(hint.button){
            case "A": return "#60a828"
            case "B": return "#d8302c"
            case "X": return "#2a6dd2"
            case "Y": return "#e0b018"
            }
            return "gray"
        }

        Text{
            anchors.centerIn: parent
            text: hint.button
            color: "white"
            font.pixelSize: 22
            font.bold: true
        }
    }

    Text{
        anchors.verticalCenter: parent.verticalCenter
        text: hint.label
        color: "white"
        font.pixelSize: 30
    }
}