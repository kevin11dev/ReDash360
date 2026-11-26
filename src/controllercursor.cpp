#include "controllercursor.h"

#include <QDir>
#include <QFile>
#include <QImage>
#include <QPainter>
#include <QPainterPath>
#include <QProcess>
#include <QSettings>
#include <QStandardPaths>
#include <QtEndian>

#include <algorithm>
#include <cmath>

namespace {

// Bump when the drawings change, so the theme is written again
constexpr int DesignVersion = 1;

constexpr int BusyFrames = 8;
constexpr int BusyFrameMs = 80;
const QColor Green(107, 209, 43);

enum class Kind { Pointer, Link, Text, Busy };

// The sizes the desktop can ask for (its cursor size setting), and the ring
// for each: a good deal bigger than an arrow of that size
const QList<int> NominalSizes = { 24, 32, 48, 64, 96 };
int ringSize(int nominal) { return int(std::lround(nominal * 2.5 / 2)) * 2; }

// One cursor picture: a white ring with a dark edge (so it shows on white
// pages too), and what's inside it
QImage draw(Kind kind, int size, int frame)
{
    QImage image(size, size, QImage::Format_ARGB32_Premultiplied);
    image.fill(Qt::transparent);
    QPainter p(&image);
    p.setRenderHint(QPainter::Antialiasing);

    const QPointF centre(size / 2.0, size / 2.0);
    const double radius = size * 0.40;
    const double line = std::max(2.0, size * 0.085);
    const double edge = std::max(1.0, size * 0.03);
    const QColor dark(0, 0, 0, 170);

    if (kind == Kind::Link) {                       // something to click: green inside
        p.setPen(Qt::NoPen);
        p.setBrush(QColor(Green.red(), Green.green(), Green.blue(), 150));
        p.drawEllipse(centre, radius, radius);
    }

    p.setBrush(Qt::NoBrush);
    p.setPen(QPen(dark, line + 2 * edge));
    p.drawEllipse(centre, radius, radius);
    p.setPen(QPen(Qt::white, line));
    p.drawEllipse(centre, radius, radius);

    switch (kind) {
    case Kind::Pointer:
    case Kind::Link: {                              // a dot where it clicks
        const double dot = std::max(1.5, size * 0.045);
        p.setPen(Qt::NoPen);
        p.setBrush(dark);
        p.drawEllipse(centre, dot + edge, dot + edge);
        p.setBrush(Qt::white);
        p.drawEllipse(centre, dot, dot);
        break;
    }
    case Kind::Text: {                              // a text bar
        const double half = radius * 0.5;
        const double serif = radius * 0.22;
        QPainterPath bar;
        bar.moveTo(centre.x(), centre.y() - half);
        bar.lineTo(centre.x(), centre.y() + half);
        bar.moveTo(centre.x() - serif, centre.y() - half);
        bar.lineTo(centre.x() + serif, centre.y() - half);
        bar.moveTo(centre.x() - serif, centre.y() + half);
        bar.lineTo(centre.x() + serif, centre.y() + half);
        const double width = std::max(1.5, line * 0.45);
        p.setBrush(Qt::NoBrush);
        p.setPen(QPen(dark, width + 2 * edge, Qt::SolidLine, Qt::RoundCap));
        p.drawPath(bar);
        p.setPen(QPen(Qt::white, width, Qt::SolidLine, Qt::RoundCap));
        p.drawPath(bar);
        break;
    }
    case Kind::Busy: {                              // a green arc going round
        const QRectF box(centre.x() - radius, centre.y() - radius, 2 * radius, 2 * radius);
        p.setPen(QPen(Green, line, Qt::SolidLine, Qt::RoundCap));
        p.drawArc(box, -frame * (360 / BusyFrames) * 16, 100 * 16);
        break;
    }
    }
    return image;
}

void put32(QByteArray &out, quint32 value)
{
    const quint32 little = qToLittleEndian(value);
    out.append(reinterpret_cast<const char *>(&little), 4);
}

// One cursor file, in the X cursor format every desktop reads: a header, a
// table of contents, then each picture (at each size, each frame of an
// animation) as width x height ARGB pixels
bool writeCursor(const QString &path, Kind kind)
{
    struct Picture { int nominal; QImage image; int delay; };
    QList<Picture> pictures;
    for (int nominal : NominalSizes) {
        const int frames = kind == Kind::Busy ? BusyFrames : 1;
        for (int frame = 0; frame < frames; ++frame)
            pictures.append({ nominal, draw(kind, ringSize(nominal), frame), kind == Kind::Busy ? BusyFrameMs : 0 });
    }

    constexpr quint32 ImageType = 0xfffd0002;
    QByteArray out;
    out.append("Xcur", 4);
    put32(out, 16);                                 // header size
    put32(out, 0x10000);                            // version
    put32(out, quint32(pictures.size()));

    quint32 position = 16 + 12 * quint32(pictures.size());
    for (const Picture &picture : pictures) {
        put32(out, ImageType);
        put32(out, quint32(picture.nominal));
        put32(out, position);
        position += 36 + 4 * quint32(picture.image.width() * picture.image.height());
    }
    for (const Picture &picture : pictures) {
        const QImage &image = picture.image;
        put32(out, 36);                             // chunk header size
        put32(out, ImageType);
        put32(out, quint32(picture.nominal));
        put32(out, 1);                              // chunk version
        put32(out, quint32(image.width()));
        put32(out, quint32(image.height()));
        put32(out, quint32(image.width() / 2));     // the hotspot: the middle
        put32(out, quint32(image.height() / 2));
        put32(out, quint32(picture.delay));
        for (int y = 0; y < image.height(); ++y) {
            const auto *row = reinterpret_cast<const quint32 *>(image.constScanLine(y));
            for (int x = 0; x < image.width(); ++x)
                put32(out, row[x]);                 // premultiplied ARGB, as X cursors want
        }
    }

    QFile file(path);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Truncate))
        return false;
    return file.write(out) == out.size();
}

// In ~/.icons, the one folder everything looks in for cursors: Plasma's
// plasma-apply-cursortheme doesn't look in ~/.local/share/icons
QString themeFolder()
{
    return QDir::homePath() + "/.icons/" + ControllerCursor::ThemeName;
}

// Where earlier versions put it
QString oldThemeFolder()
{
    return QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation) + "/icons/"
           + ControllerCursor::ThemeName;
}

// Switch the cursor without waiting. What it says goes in cursor.log (in
// ~/.cache/ReDash360/ReDash360), to see why if the cursor didn't change.
void run(const QString &program, const QStringList &arguments)
{
    const QString folder = QStandardPaths::writableLocation(QStandardPaths::CacheLocation);
    QDir().mkpath(folder);
    QProcess process;
    process.setProgram(program);
    process.setArguments(arguments);
    process.setStandardOutputFile(folder + "/cursor.log");
    process.setStandardErrorFile(folder + "/cursor.log", QIODevice::Append);
    if (!process.startDetached())
        qWarning("Controller cursor: can't run %s", qPrintable(program));
}

bool onPlasma() { return qEnvironmentVariable("XDG_CURRENT_DESKTOP").contains("KDE"); }
bool onHyprland() { return qEnvironmentVariable("XDG_CURRENT_DESKTOP").contains("Hyprland"); }

QString hyprlandSize() { return qEnvironmentVariable("XCURSOR_SIZE", "24"); }

} // namespace

ControllerCursor::ControllerCursor(QObject *parent, int idleMs)
    : QObject(parent)
{
    m_idle.setSingleShot(true);
    m_idle.setInterval(idleMs);
    connect(&m_idle, &QTimer::timeout, this, &ControllerCursor::hide);

    // The theme from an earlier version, in the folder Plasma doesn't look in
    if (QFile::exists(oldThemeFolder() + "/.redash360-version"))
        QDir(oldThemeFolder()).removeRecursively();

    // The ring still on from a dashboard that didn't get to put yours back
    if (QSettings().value("cursor/ring").toBool())
        use(false);
}

ControllerCursor::~ControllerCursor()
{
    hide();
}

void ControllerCursor::moved()
{
    if (!m_shown)
        use(true);
    m_idle.start();                                 // a minute more
}

void ControllerCursor::hide()
{
    m_idle.stop();
    if (m_shown)
        use(false);
}

QString ControllerCursor::desktopTheme() const
{
    if (onPlasma()) {
        const QSettings kde(QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation) + "/kcminputrc",
                            QSettings::IniFormat);
        return kde.value("Mouse/cursorTheme", "breeze_cursors").toString();
    }
    return qEnvironmentVariable("XCURSOR_THEME", "Adwaita");
}

void ControllerCursor::use(bool ring)
{
    if (!onPlasma() && !onHyprland())
        return;                                     // other desktops: their own cursor stays
    QSettings settings;

    QString theme;
    if (ring) {
        // Remember yours, to put back (not the ring, if it's somehow on already)
        const QString yours = desktopTheme();
        if (yours != ThemeName)
            settings.setValue("cursor/yours", yours);
        const QString inherits = settings.value("cursor/yours", "breeze_cursors").toString();
        if (!writeTheme(themeFolder(), inherits)) {
            qWarning("Controller cursor: can't write the cursor theme to %s", qPrintable(themeFolder()));
            return;
        }
        theme = ThemeName;
    } else {
        theme = settings.value("cursor/yours", onPlasma() ? "breeze_cursors" : "Adwaita").toString();
    }

    if (onPlasma())
        run("plasma-apply-cursortheme", { theme });
    else
        run("hyprctl", { "setcursor", theme, hyprlandSize() });

    m_shown = ring;
    settings.setValue("cursor/ring", ring);
}

bool ControllerCursor::writeTheme(const QString &folder, const QString &inherits)
{
    // Already there, as this version draws it?
    const QString stamp = QString("%1 %2").arg(DesignVersion).arg(inherits);
    QFile version(folder + "/.redash360-version");
    if (version.open(QIODevice::ReadOnly) && QString::fromUtf8(version.readAll()) == stamp)
        return true;
    version.close();

    const QString cursors = folder + "/cursors";
    if (!QDir().mkpath(cursors))
        return false;

    QFile index(folder + "/index.theme");
    if (!index.open(QIODevice::WriteOnly | QIODevice::Truncate))
        return false;
    index.write(QString("[Icon Theme]\n"
                        "Name=ReDash360 Controller\n"
                        "Comment=A big ring for the controller, made by ReDash360\n"
                        "Inherits=%1,breeze_cursors,Adwaita,default\n").arg(inherits).toUtf8());
    index.close();

    // Each picture once, and the other names apps ask for, linked to it
    const QList<QPair<Kind, QStringList>> names = {
        { Kind::Pointer, { "default", "left_ptr", "arrow", "top_left_arrow", "left_arrow" } },
        { Kind::Link, { "pointer", "hand", "hand1", "hand2", "pointing_hand",
                      "e29285e634086352946a0e7090d73106", "9d800788f1b08800ae810202380a0822" } },
        { Kind::Text, { "text", "xterm", "ibeam" } },
        { Kind::Busy, { "progress", "wait", "watch", "left_ptr_watch", "half-busy",
                      "00000000000000020006000e7e9ffc3f", "08e8e1c95fe2fc01f976f1e063a24ccd",
                      "3ecb610c1bf2410f44200f48c40d3599" } },
        };
    for (const auto &[kind, aliases] : names) {
        if (!writeCursor(cursors + "/" + aliases.first(), kind))
            return false;
        for (const QString &alias : aliases.mid(1)) {
            QFile::remove(cursors + "/" + alias);
            QFile::link(aliases.first(), cursors + "/" + alias);
        }
    }

    if (!version.open(QIODevice::WriteOnly | QIODevice::Truncate))
        return false;
    version.write(stamp.toUtf8());
    return true;
}