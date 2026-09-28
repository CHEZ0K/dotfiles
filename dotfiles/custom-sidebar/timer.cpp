#include "timer.hpp"
#include <iomanip>
#include <sstream>
#include <cstdlib>

PomodoroTimer::PomodoroTimer() {
    reset();
}

void PomodoroTimer::setDuration(int hours, int minutes, int seconds) {
    if (running) pause();
    int total = hours * 3600 + minutes * 60 + seconds;
    if (total <= 0) total = 60;
    if (total > 86400) total = 86400;
    durationSeconds = total;
    remainingMs = (long long)total * 1000;
    finished = false;
}

void PomodoroTimer::addMinutes(int mins) {
    addSeconds(mins * 60);
}

void PomodoroTimer::addSeconds(int secs) {
    int newDur = durationSeconds + secs;
    if (newDur < 10) newDur = 10;
    if (newDur > 86400) newDur = 86400;
    setDuration(0, 0, newDur);
}

void PomodoroTimer::start() {
    if (remainingMs <= 0 || finished) {
        remainingMs = (long long)durationSeconds * 1000;
    }
    finished = false;
    running = true;
    endTime = std::chrono::steady_clock::now() + std::chrono::milliseconds(remainingMs);
}

void PomodoroTimer::pause() {
    if (running) {
        auto now = std::chrono::steady_clock::now();
        remainingMs = std::chrono::duration_cast<std::chrono::milliseconds>(endTime - now).count();
        if (remainingMs < 0) remainingMs = 0;
        running = false;
    }
}

void PomodoroTimer::reset() {
    running = false;
    finished = false;
    remainingMs = (long long)durationSeconds * 1000;
}

void PomodoroTimer::tick() {
    if (!running) return;
    auto now = std::chrono::steady_clock::now();
    remainingMs = std::chrono::duration_cast<std::chrono::milliseconds>(endTime - now).count();
    if (remainingMs <= 0) {
        remainingMs = 0;
        running = false;
        finished = true;
        playAlarm();
    }
}

int PomodoroTimer::getHours() const {
    long long sec = remainingMs / 1000;
    return (int)(sec / 3600);
}

int PomodoroTimer::getMinutes() const {
    long long sec = remainingMs / 1000;
    return (int)((sec % 3600) / 60);
}

int PomodoroTimer::getSeconds() const {
    long long sec = remainingMs / 1000;
    return (int)(sec % 60);
}

int PomodoroTimer::getMilliseconds() const {
    return (int)((remainingMs % 1000) / 10);
}

std::string PomodoroTimer::getDisplayTime() {
    int h = getHours();
    int m = getMinutes();
    int s = getSeconds();
    std::ostringstream ss;
    if (h > 0) {
        ss << std::setfill('0') << std::setw(2) << h << ":"
           << std::setfill('0') << std::setw(2) << m << ":"
           << std::setfill('0') << std::setw(2) << s;
    } else {
        ss << std::setfill('0') << std::setw(2) << m << ":"
           << std::setfill('0') << std::setw(2) << s;
    }
    return ss.str();
}

std::string PomodoroTimer::getDisplayMs() {
    int ms = getMilliseconds();
    std::ostringstream ss;
    ss << "." << std::setfill('0') << std::setw(2) << ms;
    return ss.str();
}

double PomodoroTimer::getProgress() const {
    if (durationSeconds <= 0) return 0.0;
    double p = (double)remainingMs / (durationSeconds * 1000.0);
    if (p < 0.0) p = 0.0;
    if (p > 1.0) p = 1.0;
    return p;
}

void PomodoroTimer::playAlarm() {
    system("pw-play /home/chezok/.config/quickshell/ii/assets/sounds/alarm-clock-elapsed.wav >/dev/null 2>&1 & notify-send -u critical 'Таймер' 'Время вышло!' &");
}

// ==================== STOPWATCH ====================
void Stopwatch::start() {
    if (!running) {
        running = true;
        startTime = std::chrono::steady_clock::now() - std::chrono::milliseconds(elapsedMs);
    }
}

void Stopwatch::pause() {
    if (running) {
        auto now = std::chrono::steady_clock::now();
        elapsedMs = std::chrono::duration_cast<std::chrono::milliseconds>(now - startTime).count();
        running = false;
    }
}

void Stopwatch::reset() {
    running = false;
    elapsedMs = 0;
}

void Stopwatch::tick() {
    if (running) {
        auto now = std::chrono::steady_clock::now();
        elapsedMs = std::chrono::duration_cast<std::chrono::milliseconds>(now - startTime).count();
    }
}

double Stopwatch::getElapsedSeconds() const {
    return (double)elapsedMs / 1000.0;
}

std::string Stopwatch::getDisplayTime() {
    long long totalSec = elapsedMs / 1000;
    int m = (int)(totalSec / 60);
    int s = (int)(totalSec % 60);
    int ms = (int)((elapsedMs % 1000) / 10);
    std::ostringstream ss;
    ss << std::setfill('0') << std::setw(2) << m << ":"
       << std::setfill('0') << std::setw(2) << s << "."
       << std::setfill('0') << std::setw(2) << ms;
    return ss.str();
}
