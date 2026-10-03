import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ApplicationWindow {
      id: window

      width: 1280
      height: 720
      visible: true
      title: "ReDash360"
      color: "#eeeeee"

      property int currentTab: 1

      property var tabNames: [
            "Bing",
            "Home",
            "Social",
            "Games",
            "Movies & TV",
            "Apps",
            "Settings"
      ]

      property var tabFiles: [
            "Bing.qml",
            "Home.qml",
            "Social.qml",
            "Games.qml",
            "MoviesTv.qml",
            "Apps.qml",
            "Settings.qml"
      ]

      Rectangle{
            id: topBar

            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right

            height: 70
            color: "#eeeeee"

            Row {
                 anchors.left: parent.left
                 anchors.leftMargin: 50
                 anchors.verticalCenter: parent.verticalCenter
                 spacing: 28

                 Repeater {
                        model: tabNames

                        delegate: Item {
                               required property int index

                               width: tabText.implicitWidth
                               height: topBar.height

                               Text {
                                    id: tabText

                                    anchors.centerIn: parent
                                    text: tabNames[index]
                                    color: index === window.currentTab ? "#107C10" : "#777777"
                                    font.pixelSize: 20
                               }

                               Rectangle{
                                    anchors.bottom: parent.bottom
                                    anchors.horizontalCenter: parent.horizontalCenter

                                    width: tabText.implicitWidth
                                    height: 3
                                    color: "#107C10"
                                    visible: index === window.currentTab
                               }

                               MouseArea{
                                    anchors.fill: parent

                                    onClicked:{
                                          window.openTab(index)
                                    }
                               }
                        }
                 }
            }
      }

      StackView{
            id: pageStack

            anchors.top: topBar.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom

            initialItem: Qt.resolvedUrl("Home.qml")

            replaceEnter: Transition{
                  ParallelAnimation {
                        NumberAnimation {
                               property: "x"
                               from: pageStack.width
                               to: 0
                               duration: 220
                               easing.type: Easing.OutCubic
                        }


                        NumberAnimation {
                               property: "opacity"
                               from: 0
                               to: 1
                               duration: 200
                        }
                  }
            }

            replaceExit: Transition{
                  ParallelAnimation {
                        NumberAnimation {
                               property: "x"
                               from: 0
                               to: -pageStack.width
                               duration: 220
                               easing.type: Easing.OutCubic
                        }


                        NumberAnimation {
                               property: "opacity"
                               from: 1
                               to: 0
                               duration: 200
                        }
                  }
            }
      }

      function openTab(index){
            if (index === currentTab)
                 return

            currentTab = index
            pageStack.replace(Qt.resolvedUrl(tabFiles[index]))
      }
}