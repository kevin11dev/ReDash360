#pragma once

#include <QSet>

class VirtualInput
{
public:
    VirtualInput() = default;
    ~VirtualInput();

    VirtualInput(const VirtualInput &) = delete;
    VirtualInput &operator=(const VirtualInput &) = delete;

    static bool possible();

    bool open();
    bool isOpen() const { return m_fd >= 0; }

    void move(int dx, int dy);

    void scroll(int vertical, int horizontal);

    void press(int code, bool down);

    void tap(int code);

    void releaseAll();

private:
    void send(int type, int code, int value);
    void sync();

    int m_fd = -1;
    bool m_failed = false;
    QSet<int> m_held;
    int m_wheelRest = 0;
    int m_hwheelRest = 0;
};