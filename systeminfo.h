#pragma once

#include <QObject>
#include <QTimer>
#include <QVariantList>
#include <QVariantMap>
#include <QtQml/qqmlregistration.h>

class QProcess;

// Settings > System, like the 360's System Info: what this PC is (its name,
// Linux, processor, graphics, memory, screen) and how busy it is right now
// (processor and graphics load and temperature, memory in use).
class SystemInfo : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    // What this PC is, as [{label, value}] in the order to show them.
    // Filled in the first time the System screen opens.
    Q_PROPERTY(QVariantList details READ details NOTIFY detailsChanged)

    // While true (the System screen is open) the readings below update
    Q_PROPERTY(bool watching READ watching WRITE setWatching NOTIFY watchingChanged)

    // How busy it is right now:
    // {cpu, cpuTemp, gpu, gpuTemp, vramUsed, vramTotal, memoryUsed, memoryTotal, uptime}
    //   cpu, gpu: load 0-100; cpuTemp, gpuTemp: °C; -1 for any this PC can't tell
    //   vramUsed, vramTotal, memoryUsed, memoryTotal: bytes (0 if unknown); uptime: seconds
    Q_PROPERTY(QVariantMap live READ live NOTIFY liveChanged)

public:
    explicit SystemInfo(QObject *parent = nullptr);

    QVariantList details() const { return m_details; }
    bool watching() const { return m_watching; }
    void setWatching(bool watching);
    QVariantMap live() const { return m_live; }

signals:
    void detailsChanged();
    void watchingChanged();
    void liveChanged();

private:
    void readDetails();
    void readLive();
    void readNvidia();
    void setDetail(const QString &label, const QString &value);

    QVariantList m_details;
    bool m_watching = false;
    QVariantMap m_live;
    QTimer m_timer;

    // Processor load is the change since the last look
    quint64 m_cpuBusy = 0;
    quint64 m_cpuTotal = 0;

    // Where this PC keeps its readings (Linux), found once
    QString m_cpuTempFile;      // a hwmon temperature, in thousandths of a degree
    QString m_amdGpu;           // an AMD card's sysfs folder: load and video memory
    QString m_gpuTempFile;
    QString m_nvidiaSmi;        // NVIDIA cards report through nvidia-smi instead
    QProcess *m_nvidiaQuery = nullptr;
    QVariantMap m_nvidia;       // its last answer
};