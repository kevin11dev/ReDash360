#include "systeminfo.h"

#include <QDir>
#include <QFile>
#include <QGuiApplication>
#include <QOffscreenSurface>
#include <QOpenGLContext>
#include <QOpenGLFunctions>
#include <QProcess>
#include <QRegularExpression>
#include <QScreen>
#include <QSettings>
#include <QStandardPaths>
#include <QSysInfo>
#include <QThread>
#include <QWindow>

#define SDL_MAIN_HANDLED
#include <SDL.h>

#ifdef Q_OS_WIN
#ifndef NOMINMAX
#define NOMINMAX
#endif
#include <windows.h>
#endif

namespace {

constexpr int LiveIntervalMs = 2000;     // how often the readings update while you watch

QString readText(const QString &path)
{
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text))
        return {};
    return QString::fromUtf8(file.readAll()).trimmed();
}

// "Intel(R) Core(TM) i7-9700K CPU @ 3.60GHz" -> "Intel Core i7-9700K",
// "AMD Ryzen 7 5800X 8-Core Processor" -> "AMD Ryzen 7 5800X"
QString tidyName(QString name)
{
    static const QRegularExpression marks("\\((R|TM|r|tm)\\)");
    static const QRegularExpression tail("\\s+@.*$|\\s+\\d+-Core Processor$|\\s+Processor$|\\s+CPU(?=\\s|$)");
    static const QRegularExpression spaces("\\s+");
    name.remove(marks);
    name.remove(tail);
    return name.replace(spaces, " ").trimmed();
}

QString processorName()
{
#ifdef Q_OS_LINUX
    for (const QString &line : readText("/proc/cpuinfo").split('\n')) {
        if (line.startsWith("model name"))
            return tidyName(line.section(':', 1));
    }
#elif defined(Q_OS_WIN)
    const QSettings cpu("HKEY_LOCAL_MACHINE\\HARDWARE\\DESCRIPTION\\System\\CentralProcessor\\0",
                        QSettings::NativeFormat);
    return tidyName(cpu.value("ProcessorNameString").toString());
#endif
    return {};
}

// The graphics card's name, as its driver tells OpenGL:
// "AMD Radeon RX 6800 XT (radeonsi, navi21, LLVM ...)" -> "AMD Radeon RX 6800 XT",
// "NVIDIA GeForce RTX 3070/PCIe/SSE2" -> "NVIDIA GeForce RTX 3070"
QString graphicsName()
{
    QOffscreenSurface surface;
    surface.create();
    QOpenGLContext context;
    if (!context.create() || !context.makeCurrent(&surface))
        return {};
    const auto renderer = reinterpret_cast<const char *>(context.functions()->glGetString(GL_RENDERER));
    QString name = QString::fromUtf8(renderer ? renderer : "");
    context.doneCurrent();

    name = name.section(" (", 0, 0).section('/', 0, 0);
    if (name.startsWith("Mesa "))
        name.remove(0, 5);
    if (name == "llvmpipe" || name == "softpipe")
        return "None in use (drawing in software)";
    return tidyName(name);
}

// Without OpenGL, at least say whose card it is
QString graphicsMaker()
{
#ifdef Q_OS_LINUX
    const QDir drm("/sys/class/drm");
    for (const QString &card : drm.entryList({ "card*" }, QDir::Dirs)) {
        if (card.contains('-'))                 // "card0-DP-1" is one of its outputs
            continue;
        const QString vendor = readText(drm.filePath(card) + "/device/vendor");
        if (vendor == "0x1002")
            return "AMD Radeon graphics";
        if (vendor == "0x10de")
            return "NVIDIA graphics";
        if (vendor == "0x8086")
            return "Intel graphics";
    }
#endif
    return {};
}

QString bytesText(double bytes)
{
    return QString::number(bytes / (1024.0 * 1024 * 1024), 'f', 1) + " GB";
}

// The screen the dashboard is on: "2560 × 1440 at 144 Hz"
QString displayText()
{
    const QWindow *window = QGuiApplication::focusWindow();
    const QScreen *screen = window ? window->screen() : QGuiApplication::primaryScreen();
    if (!screen)
        return {};
    const QSize pixels = screen->size() * screen->devicePixelRatio();
    QString text = QString("%1 × %2 at %3 Hz").arg(pixels.width()).arg(pixels.height())
                       .arg(qRound(screen->refreshRate()));
    const int scale = qRound(screen->devicePixelRatio() * 100);
    if (scale != 100)
        text += QString(" · %1% scale").arg(scale);
    return text;
}

// "KDE Plasma · Wayland" (the Plasma version is filled in later)
QString desktopText(const QString &version = {})
{
    QString desktop = qEnvironmentVariable("XDG_CURRENT_DESKTOP").section(':', 0, 0);
    if (desktop == "KDE")
        desktop = "KDE Plasma";
    if (!version.isEmpty())
        desktop += " " + version;
    const QString session = qEnvironmentVariable("XDG_SESSION_TYPE");
    const QString kind = session == "wayland" ? "Wayland" : session == "x11" ? "X11" : QString();
    return QStringList({ desktop, kind }).filter(QRegularExpression(".")).join(" · ");
}

#ifdef Q_OS_LINUX
// A temperature file holds thousandths of a degree
int readTemperature(const QString &path)
{
    bool ok = false;
    const int value = readText(path).toInt(&ok);
    return ok ? qRound(value / 1000.0) : -1;
}

// The processor's temperature sensor: AMD's k10temp or zenpower, Intel's
// coretemp ("Package id 0" when it has one), or the board's as a last resort
QString findProcessorTemperature()
{
    const QDir hwmon("/sys/class/hwmon");
    QString fallback;
    for (const QString &entry : hwmon.entryList(QDir::Dirs | QDir::NoDotAndDotDot)) {
        const QString folder = hwmon.filePath(entry);
        const QString name = readText(folder + "/name");
        if (name == "k10temp" || name == "zenpower" || name == "cpu_thermal")
            return folder + "/temp1_input";
        if (name == "coretemp") {
            for (int i = 1; i <= 32; ++i) {
                if (readText(folder + QString("/temp%1_label").arg(i)).startsWith("Package"))
                    return folder + QString("/temp%1_input").arg(i);
            }
            return folder + "/temp1_input";
        }
        if (name == "acpitz" && fallback.isEmpty())
            fallback = folder + "/temp1_input";
    }
    return fallback;
}

// An AMD card, which keeps its load and video memory in files: the one with
// the most video memory, if there are two (a laptop's built-in one and a real one)
QString findAmdCard()
{
    const QDir drm("/sys/class/drm");
    QString best;
    qint64 bestMemory = -1;
    for (const QString &card : drm.entryList({ "card*" }, QDir::Dirs)) {
        const QString device = drm.filePath(card) + "/device";
        if (card.contains('-') || !QFile::exists(device + "/gpu_busy_percent"))
            continue;
        const qint64 memory = readText(device + "/mem_info_vram_total").toLongLong();
        if (memory > bestMemory) {
            best = device;
            bestMemory = memory;
        }
    }
    return best;
}

QString findCardTemperature(const QString &device)
{
    const QDir hwmon(device + "/hwmon");
    const QStringList entries = hwmon.entryList(QDir::Dirs | QDir::NoDotAndDotDot);
    return entries.isEmpty() ? QString() : hwmon.filePath(entries.first()) + "/temp1_input";
}
#endif

} // namespace

SystemInfo::SystemInfo(QObject *parent)
    : QObject(parent)
{
    m_timer.setInterval(LiveIntervalMs);
    connect(&m_timer, &QTimer::timeout, this, &SystemInfo::readLive);
}

void SystemInfo::setWatching(bool watching)
{
    if (watching == m_watching)
        return;
    m_watching = watching;
    emit watchingChanged();

    if (!watching) {
        m_timer.stop();
        return;
    }
    if (m_details.isEmpty())
        readDetails();
    readLive();                                 // the load needs two looks, so take
    QTimer::singleShot(500, this, &SystemInfo::readLive);   // the second one soon
    m_timer.start();
}

void SystemInfo::readDetails()
{
    const QString processor = processorName();
    QString graphics = graphicsName();
    if (graphics.isEmpty())
        graphics = graphicsMaker();

    double memory = 0;
#ifdef Q_OS_LINUX
    for (const QString &line : readText("/proc/meminfo").split('\n')) {
        if (line.startsWith("MemTotal:"))
            memory = line.section(':', 1).trimmed().section(' ', 0, 0).toDouble() * 1024;
    }
    m_cpuTempFile = findProcessorTemperature();
    m_amdGpu = findAmdCard();
    if (!m_amdGpu.isEmpty())
        m_gpuTempFile = findCardTemperature(m_amdGpu);
    else
        m_nvidiaSmi = QStandardPaths::findExecutable("nvidia-smi");
#elif defined(Q_OS_WIN)
    MEMORYSTATUSEX status;
    status.dwLength = sizeof(status);
    if (GlobalMemoryStatusEx(&status))
        memory = status.ullTotalPhys;
#endif

    SDL_version sdl;
    SDL_GetVersion(&sdl);
    const QString kernel = QSysInfo::kernelType() == "linux" ? "Linux " + QSysInfo::kernelVersion()
                                                             : QSysInfo::kernelVersion();

    const QList<QPair<QString, QString>> rows = {
        { "Computer name", QSysInfo::machineHostName() },
        { "Operating system", QSysInfo::prettyProductName() },
        { "Kernel", kernel },
        { "Desktop", desktopText() },
        { "Processor", processor.isEmpty() ? QString()
                                          : processor + QString(" · %1 threads").arg(QThread::idealThreadCount()) },
        { "Graphics", graphics },
        { "Memory", memory > 0 ? bytesText(memory) : QString() },
        { "Display", displayText() },
        { "Dashboard", QString("ReDash360 · Qt %1 · SDL %2.%3.%4")
                          .arg(qVersion()).arg(sdl.major).arg(sdl.minor).arg(sdl.patch) },
        };
    m_details.clear();
    for (const auto &row : rows) {
        if (!row.second.isEmpty())
            m_details << QVariantMap { { "label", row.first }, { "value", row.second } };
    }
    emit detailsChanged();

    // Plasma's version takes a moment to ask for
    if (qEnvironmentVariable("XDG_CURRENT_DESKTOP").contains("KDE")
        && !QStandardPaths::findExecutable("plasmashell").isEmpty()) {
        auto *plasma = new QProcess(this);
        connect(plasma, &QProcess::finished, this, [this, plasma] {
            // "plasmashell 6.2.0"
            const QString version = QString::fromUtf8(plasma->readAllStandardOutput()).trimmed().section(' ', -1);
            if (!version.isEmpty() && version.front().isDigit())
                setDetail("Desktop", desktopText(version));
            plasma->deleteLater();
        });
        plasma->start("plasmashell", { "--version" });
    }
}

void SystemInfo::setDetail(const QString &label, const QString &value)
{
    for (QVariant &row : m_details) {
        QVariantMap map = row.toMap();
        if (map.value("label") == label) {
            map["value"] = value;
            row = map;
            emit detailsChanged();
            return;
        }
    }
}

void SystemInfo::readLive()
{
    QVariantMap live {
        { "cpu", -1 }, { "cpuTemp", -1 }, { "gpu", -1 }, { "gpuTemp", -1 },
        { "vramUsed", 0.0 }, { "vramTotal", 0.0 }, { "memoryUsed", 0.0 }, { "memoryTotal", 0.0 },
        { "uptime", 0.0 },
        };
    quint64 busy = 0;
    quint64 total = 0;

#ifdef Q_OS_LINUX
    // Processor time so far: user nice system idle iowait irq softirq steal
    const QStringList cpu = readText("/proc/stat").section('\n', 0, 0).split(' ', Qt::SkipEmptyParts);
    if (cpu.size() > 5 && cpu.first() == "cpu") {
        for (int i = 1; i <= 8 && i < cpu.size(); ++i)
            total += cpu[i].toULongLong();
        busy = total - cpu[4].toULongLong() - cpu[5].toULongLong();
    }

    double memoryTotal = 0;
    double memoryFree = 0;
    for (const QString &line : readText("/proc/meminfo").split('\n')) {
        const double kib = line.section(':', 1).trimmed().section(' ', 0, 0).toDouble();
        if (line.startsWith("MemTotal:"))
            memoryTotal = kib * 1024;
        else if (line.startsWith("MemAvailable:"))
            memoryFree = kib * 1024;
    }
    live["memoryTotal"] = memoryTotal;
    live["memoryUsed"] = memoryTotal - memoryFree;
    live["uptime"] = readText("/proc/uptime").section(' ', 0, 0).toDouble();

    if (!m_cpuTempFile.isEmpty())
        live["cpuTemp"] = readTemperature(m_cpuTempFile);

    if (!m_amdGpu.isEmpty()) {
        bool ok = false;
        const int load = readText(m_amdGpu + "/gpu_busy_percent").toInt(&ok);
        live["gpu"] = ok ? load : -1;
        live["vramUsed"] = readText(m_amdGpu + "/mem_info_vram_used").toDouble();
        live["vramTotal"] = readText(m_amdGpu + "/mem_info_vram_total").toDouble();
        if (!m_gpuTempFile.isEmpty())
            live["gpuTemp"] = readTemperature(m_gpuTempFile);
    } else if (!m_nvidiaSmi.isEmpty()) {
        readNvidia();                           // answers by the next update
        live.insert(m_nvidia);
    }
#elif defined(Q_OS_WIN)
    FILETIME idle, kernel, user;
    if (GetSystemTimes(&idle, &kernel, &user)) {
        const auto ticks = [](const FILETIME &time) {
            return (quint64(time.dwHighDateTime) << 32) | time.dwLowDateTime;
        };
        total = ticks(kernel) + ticks(user);    // kernel time includes the idle time
        busy = total - ticks(idle);
    }
    MEMORYSTATUSEX status;
    status.dwLength = sizeof(status);
    if (GlobalMemoryStatusEx(&status)) {
        live["memoryTotal"] = double(status.ullTotalPhys);
        live["memoryUsed"] = double(status.ullTotalPhys - status.ullAvailPhys);
    }
    live["uptime"] = GetTickCount64() / 1000.0;
#endif

    // Processor load: how much of the time since the last look it was busy
    if (m_cpuTotal > 0 && total > m_cpuTotal && busy >= m_cpuBusy)
        live["cpu"] = qRound(100.0 * (busy - m_cpuBusy) / (total - m_cpuTotal));
    else if (m_live.value("cpu", -1).toInt() >= 0)
        live["cpu"] = m_live["cpu"];
    m_cpuBusy = busy;
    m_cpuTotal = total;

    m_live = live;
    emit liveChanged();
}

// NVIDIA's driver answers through nvidia-smi
void SystemInfo::readNvidia()
{
    if (!m_nvidiaQuery) {
        m_nvidiaQuery = new QProcess(this);
        connect(m_nvidiaQuery, &QProcess::finished, this, [this] {
            // "23, 47, 2101, 8192": load %, °C, MiB used, MiB total
            const QStringList values = QString::fromUtf8(m_nvidiaQuery->readAllStandardOutput())
                                           .section('\n', 0, 0).split(',');
            if (values.size() != 4)
                return;
            m_nvidia = {
                { "gpu", values[0].trimmed().toInt() },
                { "gpuTemp", values[1].trimmed().toInt() },
                { "vramUsed", values[2].trimmed().toDouble() * 1024 * 1024 },
                { "vramTotal", values[3].trimmed().toDouble() * 1024 * 1024 },
                };
        });
    }
    if (m_nvidiaQuery->state() == QProcess::NotRunning) {
        m_nvidiaQuery->start(m_nvidiaSmi, { "--query-gpu=utilization.gpu,temperature.gpu,memory.used,memory.total",
                                           "--format=csv,noheader,nounits" });
    }
}