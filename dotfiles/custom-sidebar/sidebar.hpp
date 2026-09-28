#pragma once
#include <gtk/gtk.h>
#include <string>
#include <vector>
#include "bluetooth.hpp"
#include "wifi.hpp"
#include "audio.hpp"
#include "timer.hpp"

class SidebarWindow {
public:
    SidebarWindow(GtkApplication *app);
    ~SidebarWindow();

    void show();
    void hide();
    void toggle();
    bool isVisible() const;

    void refreshAll();
    void refreshBluetooth();
    void refreshWifi();
    void refreshUptime();
    void refreshNotifications();
    void reloadThemeColors();

    void updateTimerDisplay();
    void updateCalendarDisplay();
    double getTimerProgress() const;

    // Accent RGB for Cairo drawing
    double accentR = 0.63;
    double accentG = 0.82;
    double accentB = 0.90;

private:
    GtkWidget *window = nullptr;    // GtkApplicationWindow (IPC only, hidden)
    GtkWidget *uiWindow = nullptr;  // GtkWindow (actual visible sidebar, no Adwaita bg)
    GtkWidget *dismissWindow = nullptr;
    GtkWidget *rootBg = nullptr;
    GtkWidget *mainStack = nullptr; // "main", "wifiDialog", "btDialog"

    // --- Main Page Column ---
    GtkWidget *mainColumn = nullptr;

    // 1. Android-Style Quick Panel (3 columns x 2 rows of pills)
    GtkWidget *btnWifiToggle = nullptr;
    GtkWidget *btnBtToggle = nullptr;
    GtkWidget *uptimePill = nullptr;
    GtkWidget *uptimeLabel = nullptr;
    GtkWidget *btnNightLight = nullptr;
    GtkWidget *btnScreenSnip = nullptr;
    GtkWidget *btnPower = nullptr;
    bool nightLightActive = false;

    // 2. CenterWidgetGroup (Notifications Card)
    GtkWidget *notifCard = nullptr;
    GtkWidget *notifScrolled = nullptr;
    GtkWidget *notifListBox = nullptr;
    GtkWidget *notifPlaceholder = nullptr;
    GtkWidget *notifCountLabel = nullptr;
    GtkWidget *btnDnd = nullptr;
    GtkWidget *btnClearAll = nullptr;
    bool dndActive = false;
    int currentNotifCount = 0;

    // 3. BottomWidgetGroup (Navigation rail + Calendar & Timer/Stopwatch)
    GtkWidget *bottomGroup = nullptr;
    GtkWidget *bottomStack = nullptr; // "timer", "calendar"
    GtkWidget *btnNavCalendar = nullptr;
    GtkWidget *btnNavTimer = nullptr;
    int activeBottomTab = 1; // 0: calendar, 1: timer

    // Timer & Stopwatch
    PomodoroTimer timer;
    Stopwatch stopwatch;
    int activeTimerSubTab = 0; // 0: Timer, 1: Stopwatch

    GtkWidget *btnSubTabTimer = nullptr;
    GtkWidget *btnSubTabStopwatch = nullptr;
    GtkWidget *subTabIndicator = nullptr;
    // Oval capsule timer widgets
    GtkWidget *timerCapsule = nullptr;        // the pill overlay container
    GtkWidget *timerProgressFill = nullptr;   // partial-width rect for progress
    GtkWidget *timerInputStack = nullptr;     // "display" / "input" pages
    GtkWidget *timerTimeLabel = nullptr;      // MM:SS big text (running)
    GtkWidget *timerMsLabel = nullptr;        // .cc milliseconds suffix
    GtkWidget *timerSubLabel = nullptr;       // "Таймер" subtitle (running)
    GtkWidget *timerHEntry = nullptr;         // H input field
    GtkWidget *timerMEntry = nullptr;         // M input field
    GtkWidget *timerSEntry = nullptr;         // S input field
    // Legacy (Cairo ring) – keep pointer for backward compat, unused
    GtkWidget *timerDrawingArea = nullptr;
    GtkWidget *presetsRow = nullptr;
    std::vector<GtkWidget*> presetButtons;
    GtkWidget *btnTimerAction = nullptr;
    GtkWidget *btnTimerReset = nullptr;
    // Slide-in revealer for open/close animation
    GtkWidget *sidebarRevealer = nullptr;

    // Calendar
    GtkWidget *calMonthLabel = nullptr;
    GtkWidget *calGrid = nullptr;
    int calMonthShift = 0;

    // --- Overlay Dialog Sheets ---
    GtkWidget *btDialogBox = nullptr;
    GtkWidget *btListBox = nullptr;
    GtkWidget *btProgressBar = nullptr;
    GtkWidget *btSwitch = nullptr;

    GtkWidget *wifiDialogBox = nullptr;
    GtkWidget *wifiListBox = nullptr;
    GtkWidget *wifiProgressBar = nullptr;
    GtkWidget *wifiSwitch = nullptr;

    // Dynamic theme CSS
    GtkCssProvider *dynamicCssProvider = nullptr;
    guint tickSource = 0;

    // Layout Builders
    void buildMainPage();
    GtkWidget* buildQuickTogglesGrid();
    GtkWidget* buildNotificationsCard();
    GtkWidget* buildBottomWidgetGroup();
    GtkWidget* buildTimerContent();
    GtkWidget* buildCalendarContent();

    GtkWidget* buildBluetoothDialog();
    GtkWidget* buildWifiDialog();

    static gboolean onTick(gpointer data);
};
