import QtQuick
import QtQuick.Controls
import QtCore

ApplicationWindow {
      id: window

      width: 1280
      height: 720
      visibility: Window.FullScreen
      title: "ReDash360"
      background: Rectangle {
            gradient: Gradient{
                  GradientStop{position: 0.00; color: "#525357"}
                  GradientStop{position: 0.20; color: "#65666a"}
                  GradientStop{position: 0.40; color: "#808185"}
                  GradientStop{position: 0.60; color: "#a0a0a2"}
                  GradientStop{position: 0.78; color: "#b3b3b5"}
                  GradientStop{position: 0.88; color: "#acadaf"}
                  GradientStop{position: 1.00; color: "#8a8b8f"}
            }

            Image{
                  anchors.fill: parent
                  source: theme.background
                  visible: status === Image.Ready
                  fillMode: Image.PreserveAspectCrop
                  asynchronous: true
                  sourceSize.width: 1920
            }
      }

      Settings{
            id: theme
            category: "theme"
            property string background
      }

      Shortcut{
            sequence: "Home"
            onActivated: {
                  if(guide.visible){
                        guide.close()
                  } else {
                        if(shelf.visible)
                              shelf.close()
                        guide.open()
                  }
            }
      }

      Shortcut{
            sequence: "Q"
            onActivated: pages.decrementCurrentIndex()
            enabled: !shelf.visible && !guide.visible
      }

      Shortcut{
            sequence: "E"
            onActivated: pages.incrementCurrentIndex()
            enabled: !shelf.visible && !guide.visible
      }

      Shortcut{
            sequence: "Esc"
            onActivated: pages.currentIndex = 1
            enabled: !shelf.visible && !guide.visible
      }


      readonly property var tabs: [
            {name: "bing", file: "Bing.qml"},
            {name: "home", file: "Home.qml"},
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
                  x: 231
                  y: 227                          // the line the tab names sit on (their baseline)
                  spacing: 58

                  Repeater{
                        id: tabRepeater
                        model: window.tabs

                        delegate: Text{
                              required property int index
                              required property var modelData

                              anchors.baseline: parent.top
                              text: modelData.name
                              font.pixelSize: 50
                              color: "white"
                              font.weight: Font.Light
                              opacity: index === pages.currentIndex ? 1.0 : 0.55
                              Behavior on opacity {NumberAnimation{duration: 200}}

                              TapHandler{onTapped: pages.currentIndex = index}
                        }
                  }
            }

            Profile{
                  id: profile
                  anchors.right: parent.right
                  anchors.rightMargin: 144
                  y: 63
            }

            ListView {
                  id: pages

                  anchors.top: parent.top
                  anchors.topMargin: 270
                  anchors.left: parent.left
                  anchors.right: parent.right
                  anchors.bottom: parent.bottom

                  focus: true

                  orientation: ListView.Horizontal
                  spacing: window.pageGap
                  model: window.tabs
                  Component.onCompleted: currentIndex = 1
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

                        MouseArea{
                              anchors.fill: parent
                              z: 1
                              visible: !page.ListView.isCurrentItem
                              hoverEnabled: true
                              onClicked: pages.currentIndex = page.index
                        }

                        Connections{
                              target: page.item
                              ignoreUnknownSignals: true
                              function onTabRequested(index) {pages.currentIndex = index}
                              function onShelfRequested() {shelf.open()}
                              function onPickGameRequested(callback) {shelf.pick(callback)}
                        }
                  }
            }

            Row{
                  id: hintBar
                  x: 180
                  y: 990
                  spacing: 40

                  ButtonHint{button: "A"; label: "Select"}

                  Repeater{
                        model: window.activeFocusItem && window.activeFocusItem.hints ? window.activeFocusItem.hints : []
                        delegate: ButtonHint{
                              required property var modelData
                              button: modelData.button
                              label: modelData.label
                        }
                  }

                  ButtonHint{
                        button: "B"
                        label: "Back"
                        visible: pages.currentIndex !== 1
                  }
            }

            GameShelf{
                  id: shelf
                  anchors.fill: parent
            }

            Guide{
                  id: guide
                  anchors.fill: parent
                  gamertag: profile.gamertag
                  gamerpic: profile.gamerpic
                  onTabRequested: (index) => pages.currentIndex = index
                  onShelfRequested: shelf.open()
                  onQuitRequested: Qt.quit()
            }
      }
}