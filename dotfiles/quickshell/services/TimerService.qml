pragma Singleton
pragma ComponentBehavior: Bound

import qs.services
import qs.modules.common

import Quickshell
import Quickshell.Io
import QtQuick

/**
 * Custom Timer and Stopwatch time manager.
 */
Singleton {
    id: root

    // Custom Timer properties
    property int customDuration: (Persistent.states.timer.pomodoro.duration && Persistent.states.timer.pomodoro.duration > 0) ? Persistent.states.timer.pomodoro.duration : 300
    property int secondsLeft: customDuration
    property int timeLeftMs: customDuration * 1000
    property double timerEndTimeMs: 0
    property bool timerRunning: Persistent.states.timer.pomodoro.running
    property bool timerFinished: false
    property int timerEndTime: 0

    // Backward compatibility aliases for Pomodoro
    property int focusTime: customDuration
    property int breakTime: 300
    property int longBreakTime: 900
    property int cyclesBeforeLongBreak: 4
    property bool pomodoroRunning: timerRunning
    property bool pomodoroBreak: false
    property bool pomodoroLongBreak: false
    property int pomodoroLapDuration: customDuration
    property int pomodoroSecondsLeft: secondsLeft
    property int pomodoroCycle: 0

    // Stopwatch properties
    property bool stopwatchRunning: Persistent.states.timer.stopwatch.running
    property int stopwatchTime: 0
    property int stopwatchStart: Persistent.states.timer.stopwatch.start
    property var stopwatchLaps: Persistent.states.timer.stopwatch.laps

    // Initialization
    Component.onCompleted: {
        if (!stopwatchRunning)
            stopwatchReset();
        if (timerRunning) {
            timerEndTimeMs = (Persistent.states.timer.pomodoro.start + customDuration) * 1000;
            timerEndTime = Math.ceil(timerEndTimeMs / 1000);
            refreshTimer();
        } else {
            secondsLeft = customDuration;
            timeLeftMs = customDuration * 1000;
        }
    }

    function getCurrentTimeInSeconds() {
        return Math.floor(Date.now() / 1000);
    }

    function getCurrentTimeIn10ms() {
        return Math.floor(Date.now() / 10);
    }

    // Timer controls
    function setDuration(seconds) {
        if (timerRunning) {
            pauseTimer();
        }
        let dur = Math.max(1, Math.min(86400, seconds));
        customDuration = dur;
        Persistent.states.timer.pomodoro.duration = dur;
        secondsLeft = dur;
        timeLeftMs = dur * 1000;
        timerFinished = false;
    }

    function addSeconds(delta) {
        let newDur = Math.max(10, Math.min(86400, customDuration + delta));
        setDuration(newDur);
    }

    function startTimer() {
        if (secondsLeft <= 0 || timerFinished) {
            secondsLeft = customDuration;
            timeLeftMs = customDuration * 1000;
        } else if (timeLeftMs <= 0) {
            timeLeftMs = secondsLeft * 1000;
        }
        timerFinished = false;
        let now = Date.now();
        timerEndTimeMs = now + timeLeftMs;
        timerEndTime = Math.ceil(timerEndTimeMs / 1000);
        Persistent.states.timer.pomodoro.start = Math.floor((now + timeLeftMs - customDuration * 1000) / 1000);
        Persistent.states.timer.pomodoro.running = true;
        timerRunning = true;
    }

    function pauseTimer() {
        if (timerRunning) {
            let now = Date.now();
            timeLeftMs = Math.max(0, timerEndTimeMs - now);
            secondsLeft = Math.ceil(timeLeftMs / 1000);
        }
        timerRunning = false;
        Persistent.states.timer.pomodoro.running = false;
    }

    function toggleTimer() {
        if (timerRunning) {
            pauseTimer();
        } else {
            startTimer();
        }
    }

    function resetTimer() {
        pauseTimer();
        timerFinished = false;
        secondsLeft = customDuration;
        timeLeftMs = customDuration * 1000;
    }

    // Pomodoro compatibility
    function togglePomodoro() {
        toggleTimer();
    }

    function resetPomodoro() {
        resetTimer();
    }

    function refreshTimer() {
        if (!timerRunning) return;
        let now = Date.now();
        let remaining = timerEndTimeMs - now;
        if (remaining <= 0) {
            timeLeftMs = 0;
            secondsLeft = 0;
            timerRunning = false;
            Persistent.states.timer.pomodoro.running = false;
            timerFinished = true;

            // Send desktop notification
            Quickshell.execDetached([
                "gdbus", "call", "--session",
                "--dest", "org.freedesktop.Notifications",
                "--object-path", "/org/freedesktop/Notifications",
                "--method", "org.freedesktop.Notifications.Notify",
                "Shell", "0", "dialog-information",
                "Таймер", "Время вышло!", "[]", "{}", "8000"
            ]);

            Audio.playSystemSound("alarm-clock-elapsed");
        } else {
            timeLeftMs = remaining;
            secondsLeft = Math.ceil(remaining / 1000);
        }
    }

    Timer {
        id: countdownTimer
        interval: 33
        running: root.timerRunning
        repeat: true
        onTriggered: refreshTimer()
    }

    // Stopwatch controls
    function refreshStopwatch() {
        stopwatchTime = getCurrentTimeIn10ms() - stopwatchStart;
    }

    Timer {
        id: stopwatchTimer
        interval: 10
        running: root.stopwatchRunning
        repeat: true
        onTriggered: refreshStopwatch()
    }

    function toggleStopwatch() {
        if (root.stopwatchRunning)
            stopwatchPause();
        else
            stopwatchResume();
    }

    function stopwatchPause() {
        Persistent.states.timer.stopwatch.running = false;
    }

    function stopwatchResume() {
        if (stopwatchTime === 0) Persistent.states.timer.stopwatch.laps = [];
        Persistent.states.timer.stopwatch.running = true;
        Persistent.states.timer.stopwatch.start = getCurrentTimeIn10ms() - stopwatchTime;
    }

    function stopwatchReset() {
        stopwatchTime = 0;
        Persistent.states.timer.stopwatch.laps = [];
        Persistent.states.timer.stopwatch.running = false;
    }

    function stopwatchRecordLap() {
        Persistent.states.timer.stopwatch.laps.push(stopwatchTime);
    }
}
