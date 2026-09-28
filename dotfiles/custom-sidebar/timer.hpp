#pragma once
#include <string>
#include <chrono>

class PomodoroTimer {
public:
    PomodoroTimer();

    void setDuration(int hours, int minutes, int seconds);
    void start();
    void pause();
    void reset();
    void addMinutes(int mins);
    void addSeconds(int secs);

    bool isRunning() const { return running; }
    bool isFinished() const { return finished; }
    int getDurationSeconds() const { return durationSeconds; }
    long long getRemainingMs() const { return remainingMs; }
    long long getDurationMs() const { return (long long)durationSeconds * 1000; }

    int getHours() const;
    int getMinutes() const;
    int getSeconds() const;
    int getMilliseconds() const; // 00-99

    std::string getDisplayTime();
    std::string getDisplayMs();
    double getProgress() const;

    void tick();

private:
    bool running = false;
    bool finished = false;
    int durationSeconds = 300; // default 5 mins (05:00)
    long long remainingMs = 300000;
    std::chrono::time_point<std::chrono::steady_clock> endTime;

    void playAlarm();
};

class Stopwatch {
public:
    Stopwatch() = default;

    void start();
    void pause();
    void reset();

    bool isRunning() const { return running; }
    std::string getDisplayTime();
    double getElapsedSeconds() const;

    void tick();

private:
    bool running = false;
    long long elapsedMs = 0;
    std::chrono::time_point<std::chrono::steady_clock> startTime;
};
