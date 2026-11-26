#pragma once

#include <QString>
#include <QStringList>

// While the dashboard is on screen, the apps you open from it fill the screen
// like a console's: maximized, without a title bar, so the dashboard doesn't
// show round the edges. When the dashboard hides (Exit to Desktop) they go
// back to normal windows.
//
// On Plasma this is a small script ReDash360 loads into KWin when it starts.
// It's only there while KWin runs, so your normal Plasma session's windows
// and KWin's own settings are left alone.
namespace AppWindows {

// Load the script into KWin (Plasma only; elsewhere it does nothing)
void fillScreen();

// The script itself, for the dashboard with this process id
QString kwinScript(qint64 dashboardPid);

// The names an app's windows go by, worked out from how it's started: its
// icon name, its program and its Flatpak ID, in lower case
// ("firefox", "org.mozilla.firefox")
QStringList appNames(const QString &command, const QString &icon);

// If the app with these names has a window open already, bring it to the
// front and say so: then it isn't started a second time. On Plasma (KWin)
// and Hyprland; elsewhere it always says no.
bool raise(const QStringList &names);

}