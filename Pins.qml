import QtQuick
import QtCore

QtObject {
    id: pins

    readonly property var items: {
        try{
            return JSON.parse(store.list)
        } catch(error){
            return[]
        }
    }

    function isPinned(command) {
        return items.some(item => item.command === command)
    }

    function pin(item){
        if(isPinned(item.command))
            return
        const pinned = {kind: item.kind, name: item.name, command: item.command, icon: item.icon || ""}
        save([pinned].concat(items))
    }

    function unpin(command) {
        save(items.filter(item => item.command !== command))
    }

    function toggle(item){
        if(isPinned(item.command))
            unpin(item.command)
        else
            pin(item)
    }

    function save(list){
        store.list = JSON.stringify(list)
    }

    property Settings store: Settings{
        category: "pins"
        property string list: "[]"
    }
}