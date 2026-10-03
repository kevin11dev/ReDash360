import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ApplicationWindow {
      id: window

      width: 1280
      height: 720
      visible: Window.FullScreen
      title: "ReDash360"
      color: "#eeeeee"

      Shortcut{
            sequence: "Esc"
            onActivated: Qt.quit()
      }

      readonly property var tabs: [
            {name: "bing", file: "Bing.qml"},
            {name: "home", file: "HOme.qml"},
            {name: "social", file: "Social.qml"},
            {name: "games", file: "Games.qml"},
            {name: "movies & tv", file: "MoviesTv.qml"},
            {name: "apps", file: "Apps.qml"},
            {name: "settings", file: "Settings.qml"},
      ]

      readonly property int pageWidth: 1252
      readonly property int pageGap: 160

      Item{
            id: canvas
            width: 1920
            height: 1080
            anchors.centerIn: parent
            scale: Math.min(window.width / width, window.height / height)

            Row{
                  id: tabRow
                  y: 120
                  spacing: 48
                  x: (canvas.width - window.pageWidth) / 2 - (tabRepeater.count > 0 ? tabRepeater.itemAt(pages.currentIndex).x : 0)
                  Behavior on x {
                        NumberAnimation {
                              duration: 300
                              easing.type: Easing.OutCubic
                        }
                  }

                  Repeater{
                        id: tabRepeater
                        model: window.tabs

                        delegate: Text{
                              required property int index
                              required property var modelData

                              text: modelData.name
                              font.pixelSize: 44
                              color: "#333333"
                              opacity: index === pages.currentIndex ? 1.0 : 0.45
                              Behavior on opacity {NumberAnimation{duration: 200}}

                              TapHandler{onTapped: pages.currentIndex = index}
                        }
                  }
            }

            ListView {
                  id: pages
                  anchors.fill: parent
                  anchors.topMargin: 200
                  anchors.bottomMargin: 80
                  focus: true

                  orientation: ListView.Horizontal
                  spacing: window.pageGap
                  model: window.tabs
                  Component.onCOmpleted: currentIndex = 1
                  cacheBuffer: 10000

                  snapMode: ListView.SnapOneItem
                  highlightRangeMode: ListView.StrictlyEnforceRange
                  preferredHighlightBegin: (width - window.pageWidth) / 2
                  preferredHighlightEnd: preferredHighlightBegin + window.pageWidth
                  highlightMoveDuration: 300

                  delegate: Loader{
                        id: page
                        required property int index
                        required property var modelData

                        width: window.pageWidth
                        height: pages.height
                        source: modelData.file
                        onLoaded: item.focus = true
                        opacity: ListView.isCurrentItem ? 1.0 : 0.35
                        Behavior on opacity {NumberAnimation {duration: 200}}

                        Connections{
                              target: page.item
                              ignoreUnknownSignals: true
                              function onTabRequested(index) {pages.currentIndex = index}
                        }
                  }
            }
      }
}