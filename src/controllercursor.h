#pragma once

#include <QObject>
#include <QString>
#include <QTimer>

class ControllerCursor : public QObject
{
    Q_OBJECT

public:
    explicit ControllerCursor(QObject *parent = nullptr, int idleMs = 60 * 1000);
    ~ControllerCursor() override;

    // The controller just moved the pointer: the ring, if it isn't on already
    void moved();

    // The desktop's own cursor again
    void hide();

    bool shown() const { return m_shown; }

    // Write the theme into this folder ("…/ReDash360-Cursors"); the missing
    // cursors (resize arrows and so on) come from the ones in inherits
    static bool writeTheme(const QString &folder, const QString &inherits);

    static constexpr char ThemeName[] = "ReDash360-Cursors";

private:
    void use(bool ring);
    QString desktopTheme() const;           // the cursor theme the desktop has now

    QTimer m_idle;
    bool m_shown = false;
};