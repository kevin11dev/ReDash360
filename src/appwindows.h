#pragma once

#include <QList>
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

// The script itself, for the dashboard with this process id. With bus (the
// dashboard's name on D-Bus), it also tells the dashboard which window is in
// front, each time that changes.
QString kwinScript(qint64 dashboardPid, const QString &bus = {});

// The process of the window in front: on Plasma what the script said last, on
// Hyprland from hyprctl; 0 if it isn't known
qint64 frontApp();

// On Plasma, goes up by one each time the window in front changes, so the
// dashboard can look at it straight away (elsewhere it stays 0)
int frontChanges();

// The title of the window in front, the same way ("" if it isn't known)
QString frontTitle();

// Ask the windows of the program with this process id to close, as if you'd
// clicked their X, so an app gets to save first (or ask). True if it had one.
bool close(qint64 pid);

// The names an app's windows go by, worked out from how it's started: its
// icon name, its program and its Flatpak ID, in lower case
// ("firefox", "org.mozilla.firefox")
QStringList appNames(const QString &command, const QString &icon);

// If the app with these names has a window open already, bring it to the
// front and say so: then it isn't started a second time. On Plasma (KWin)
// and Hyprland; elsewhere it always says no.
bool raise(const QStringList &names);

// An app's window that's open: an id to bring it to the front or close it
// with, its program's process id, its title, and the names it goes by (its
// window's IDs and its program's names, in lower case, to compare with
// appNames())
struct Window {
    QString id;
    qint64 pid = 0;
    QString title;
    QStringList names;
};

// Every app's window that's open, not the dashboard's (Plasma and Hyprland)
QList<Window> windows();

// Bring that window to the front, or close it the way its X would
bool activate(const QString &id);
bool closeWindow(const QString &id);

}