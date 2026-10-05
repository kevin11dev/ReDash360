#include "pointer.h"

#include <QCursor>
#include <QGuiApplication>
#include <QMouseEvent>

Pointer::Pointer(QObject *parent)
    : QObject(parent)
{
    m_lastPos = QCursor::pos();     // where the cursor already is doesn't count as a move
    qApp->installEventFilter(this);
    setActive(false);   // start in controller mode, cursor hidden
}

bool Pointer::eventFilter(QObject *watched, QEvent *event)
{
    switch (event->type()) {
    case QEvent::MouseMove: {
        // Only a real move counts: the same position again (e.g. a page sliding
        // under a cursor that didn't move) shouldn't wake the mouse up
        const QPointF pos = static_cast<QMouseEvent *>(event)->globalPosition();
        if (pos != m_lastPos) {
            m_lastPos = pos;
            setActive(true);
        }
        break;
    }
    case QEvent::MouseButtonPress:
        setActive(true);
        break;
    case QEvent::KeyPress:
        setActive(false);
        break;
    default:
        break;
    }
    return QObject::eventFilter(watched, event);   // never swallow anything
}

void Pointer::setActive(bool active)
{
    if (active == m_active)
        return;
    m_active = active;

    // An "override cursor" wins over every cursorShape in QML
    if (active)
        QGuiApplication::restoreOverrideCursor();
    else
        QGuiApplication::setOverrideCursor(Qt::BlankCursor);

    emit activeChanged();
}