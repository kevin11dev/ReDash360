import QtQuick
import QtCore

Tile {
    id: slot

    required property string slotId
    property string emptyLabel: "Add App"

    signal pickRequested()

    readonly property bool hasApp: saved.command !== ""

    label: hasApp ? saved.name : emptyLabel
    icon: hasApp ? "apps" : "plus"
    image: hasApp && saved.icon !== "" ? "image://appicon/" + saved.icon : ""
    hints: [{button: "Y", label: hasApp ? "Change App" : "Choose App"}]

    onActivated:{
        if(hasApp)
            Launcher.openApp(saved.name, saved.command, saved.icon)
        else
            pickRequested()
    }
    onYPressed: pickRequested()

    function setApp(app) {
        saved.name = app.name
        saved.command = app.command
        saved.icon = app.icon
    }

    Settings{
        id: saved
        category: "appSlot_" + slot.slotId
        property string name
        property string command
        property string icon
    }
}