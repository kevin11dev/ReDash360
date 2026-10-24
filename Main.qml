import QtQuick
import QtQuick.Controls
import QtCore

ApplicationWindow {
      id: window
      readonly property QtObject sounds: Sounds

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
                  source: Preferences.shownBackground
                  retainWhileLoading: true      // no grey flash while switching pictures
                  fillMode: Image.PreserveAspectCrop
                  asynchronous: true
                  sourceSize.width: 1920
            }
      }

      Shortcut{
            sequence: "Home"
            onActivated: {
                  if(guide.visible){
                        guide.close()
                  } else {
                        if(profileScreen.visible)
                              profileScreen.close()
                        if(gameDetails.visible)
                              gameDetails.close()
                        if(shelf.visible)
                              shelf.close()
                        if(appShelf.visible)
                              appShelf.close()
                        if(recentShelf.visible)
                              recentShelf.close()
                        if(pinShelf.visible)
                              pinShelf.close()
                        if(networkScreen.visible)
                              networkScreen.close()
                        if(storageScreen.visible)
                              storageScreen.close()
                        if(controllersScreen.visible)
                              controllersScreen.close()
                        if(systemScreen.visible)
                              systemScreen.close()
                        if(displaySoundScreen.visible)
                              displaySoundScreen.close()
                        if(preferencesScreen.visible)
                              preferencesScreen.close()
                        if(searchScreen.visible)
                              searchScreen.close()
                        if(newsScreen.visible)
                              newsScreen.close()
                        if(addOnsScreen.visible)
                              addOnsScreen.close()
                        if(powerMenu.visible)
                              powerMenu.close()
                        if(signOutCard.visible)
                              signOutCard.close()
                        if(getAppCard.visible)
                              getAppCard.close()
                        guide.open()
                  }
            }
      }

      Shortcut{
            sequence: "Q"
            onActivated: pages.decrementCurrentIndex()
            enabled: !window.subScreenOpen && !guide.visible && !window.cardOpen
      }

      Shortcut{
            sequence: "E"
            onActivated: pages.incrementCurrentIndex()
            enabled: !window.subScreenOpen && !guide.visible && !window.cardOpen
      }

      Shortcut{
            sequence: "Esc"
            onActivated: pages.currentIndex = 1
            enabled: !window.subScreenOpen && !guide.visible && !window.cardOpen
      }


      readonly property var tabs: [
            {name: "search", file: "Search.qml"},
            {name: "home", file: "Home.qml"},
            {name: "social", file: "Social.qml"},
            {name: "games", file: "Games.qml"},
            {name: "apps", file: "Apps.qml"},
            {name: "settings", file: "Settings.qml"},
      ]

      readonly property int pageWidth: 1252
      readonly property int pageGap: 160
      readonly property bool subScreenOpen: shelf.visible || appShelf.visible || recentShelf.visible || pinShelf.visible || profileScreen.visible || gameDetails.visible || networkScreen.visible || storageScreen.visible || controllersScreen.visible || systemScreen.visible || displaySoundScreen.visible || preferencesScreen.visible || searchScreen.visible || newsScreen.visible || addOnsScreen.visible
      readonly property bool cardOpen: powerMenu.visible || signOutCard.visible || getAppCard.visible
      readonly property Window guideOverlay: overlay

      // Bring the dashboard in front of whatever is running (e.g. a game)
      function showDashboard() {
            window.raise()
            window.requestActivate()
      }

      Item{
            id: canvas
            width: 1920
            height: 1080
            anchors.centerIn: parent
            scale: Math.min(window.width / width, window.height / height)

            Row{
                  id: tabRow
                  anchors.horizontalCenter: parent.horizontalCenter
                  y: 227                          // the line the tab names sit on (their baseline)
                  spacing: 58
                  opacity: window.subScreenOpen ? 0 : 1
                  Behavior on opacity { NumberAnimation { duration: 200 } }

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
                  opacity: window.subScreenOpen ? 0 : 1
                  Behavior on opacity { NumberAnimation { duration: 200 } }
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
                  Component.onCompleted: {
                        currentIndex = 1
                        started = true
                  }

                  // A swoosh for every tab change (LB / RB, the mouse, sliding off a
                  // page's edge, B back to home), but not for opening on home
                  property bool started: false
                  onCurrentIndexChanged: if (started) Sounds.play("tab")
                  cacheBuffer: 10000

                  snapMode: ListView.SnapOneItem
                  highlightRangeMode: ListView.StrictlyEnforceRange
                  preferredHighlightBegin: (width - window.pageWidth) / 2
                  preferredHighlightEnd: preferredHighlightBegin + window.pageWidth
                  highlightMoveDuration: 300

                  opacity: window.subScreenOpen ? 0 : 1
                  Behavior on opacity { NumberAnimation { duration: 200 } }

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
                              function onAppsRequested() {appShelf.open()}
                              function onAppListRequested(title, apps) {appShelf.open(title, apps)}
                              function onPickAppRequested(title, apps, callback) {appShelf.pick(title, apps, callback)}
                              function onPowerRequested() {powerMenu.open()}
                              function onRecentsRequested(){recentShelf.open()}
                              function onPinsRequested(){pinShelf.open()}
                              function onProfileRequested() {profileScreen.open()}
                              function onNetworkRequested() {networkScreen.open()}
                              function onStorageRequested() {storageScreen.open()}
                              function onControllersRequested() {controllersScreen.open()}
                              function onSystemRequested() {systemScreen.open()}
                              function onDisplaySoundRequested() {displaySoundScreen.open()}
                              function onPreferencesRequested() {preferencesScreen.open()}
                              function onSearchRequested() {searchScreen.open()}
                              function onAppSearchRequested() {searchScreen.open("apps")}
                              function onGameSearchRequested() {searchScreen.open("games")}
                              function onAddOnsRequested() {addOnsScreen.open()}
                              function onInstallRequested(name) {getAppCard.app = name; getAppCard.open()}
                              function onSignOutRequested() {signOutCard.open()}
                              function onNewsRequested(cards, index) {newsScreen.open(cards, index)}
                        }
                  }
            }

            Row{
                  id: hintBar
                  x: 180
                  y: 990
                  spacing: 40
                  opacity: window.subScreenOpen ? 0 : 1
                  Behavior on opacity { NumberAnimation { duration: 200 } }

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
                  onDetailsRequested: (game) => gameDetails.open(game)
            }

            GameDetails{
                  id: gameDetails
                  anchors.fill: parent
                  onAchievementsRequested: (appId) => profileScreen.openGame(appId)
            }

            AppShelf{
                  id: appShelf
                  anchors.fill: parent
            }

            ProfileScreen{
                  id: profileScreen
                  anchors.fill: parent
            }

            NetworkScreen{
                  id: networkScreen
                  anchors.fill: parent
            }

            StorageScreen{
                  id: storageScreen
                  anchors.fill: parent
            }

            ControllerScreen{
                  id: controllersScreen
                  anchors.fill: parent
            }

            SystemScreen{
                  id: systemScreen
                  anchors.fill: parent
            }

            DisplaySoundScreen{
                  id: displaySoundScreen
                  anchors.fill: parent
            }

            PreferencesScreen{
                  id: preferencesScreen
                  anchors.fill: parent
            }

            SearchScreen{
                  id: searchScreen
                  anchors.fill: parent
                  onAppsFound: (title, apps) => appShelf.open(title, apps)
                  onGamesFound: (title, games) => shelf.open(title, games)
            }

            NewsScreen{
                  id: newsScreen
                  anchors.fill: parent
            }

            AddOnsScreen{
                  id: addOnsScreen
                  anchors.fill: parent
            }

            PinShelf {
                  id: pinShelf
                  anchors.fill: parent
            }

            RecentShelf{
                  id: recentShelf
                  anchors.fill: parent
            }

            PowerMenu{
                  id: powerMenu
                  anchors.fill: parent
            }

            // Sign Out (social tab, or X in the Guide): back to the login screen
            MessageCard{
                  id: signOutCard
                  anchors.fill: parent
                  title: "Sign Out"
                  message: "Sign out of " + profile.gamertag + "? Everything you have open will close, so save anything you're working on first."
                  defaultIndex: 1
                  options: [
                        {label: "Sign Out", run: () => Launcher.signOut()},
                        {label: "Cancel", run: () => {}}
                  ]
            }

            // An app a tile needs isn't installed (Discord on the social tab)
            MessageCard{
                  id: getAppCard
                  anchors.fill: parent
                  property string app
                  icon: "!"
                  title: app + " Isn't Installed"
                  message: "You need " + app + " for this. Get it, then come back here and it opens."
                  defaultIndex: 0
                  options: [
                        {label: "Get " + getAppCard.app, run: () => addOnsScreen.getNamed(getAppCard.app)},
                        {label: "Back", run: () => {}}
                  ]
            }

            Guide{
                  id: guide
                  anchors.fill: parent
                  gamertag: profile.gamertag
                  gamerpic: profile.gamerpic
                  onTabRequested: (index) => pages.currentIndex = index
                  onShelfRequested: shelf.open()
                  onQuitRequested: powerMenu.open()
                  onAchievementsRequested: profileScreen.openAchievements()
                  onRecentsRequested: recentShelf.open()
                  onProfileRequested: profileScreen.open()
                  onPreferencesRequested: preferencesScreen.open()
                  onSignOutRequested: signOutCard.open()
            }

            BatteryNotice{
                  anchors.fill: parent
            }
      }

      GuideOverlay{
            id: overlay
            gamertag: profile.gamertag
            gamerpic: profile.gamerpic
            onTabRequested: (index) => { window.showDashboard(); pages.currentIndex = index }
            onShelfRequested: { window.showDashboard(); shelf.open() }
            onQuitRequested: Qt.quit()
            onAchievementsRequested: { window.showDashboard(); profileScreen.openAchievements() }
            onRecentsRequested: { window.showDashboard(); recentShelf.open() }
            onProfileRequested: { window.showDashboard(); profileScreen.open() }
            onPreferencesRequested: { window.showDashboard(); preferencesScreen.open() }
            onSignOutRequested: { window.showDashboard(); signOutCard.open() }
      }
}