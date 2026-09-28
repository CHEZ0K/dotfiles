#include "sidebar.hpp"
#include <gtk4-layer-shell.h>
#include <thread>
#include <iomanip>
#include <sstream>
#include <ctime>
#include <cmath>
#include <fstream>
#include <iostream>

// ==================== HELPER WIDGET FACTORIES ====================
static GtkWidget* createIconLabel(const std::string &iconName, int sizePx = 20, bool isNerd = false) {
    GtkWidget *lbl = gtk_label_new(iconName.c_str());
    if (isNerd) {
        gtk_widget_add_css_class(lbl, "nerd-icon");
    } else {
        gtk_widget_add_css_class(lbl, "material-symbol");
    }
    return lbl;
}

static GtkWidget* createIconButton(const std::string &iconName, const std::string &btnClass = "quick-pill-btn", int sizePx = 20, bool isNerd = false) {
    GtkWidget *btn = gtk_button_new();
    gtk_widget_add_css_class(btn, btnClass.c_str());
    GtkWidget *lbl = createIconLabel(iconName, sizePx, isNerd);
    gtk_button_set_child(GTK_BUTTON(btn), lbl);
    return btn;
}

// JSON Color Extractor helper
static std::string extractJsonColor(const std::string &json, const std::string &key, const std::string &fallback) {
    std::string needle = "\"" + key + "\":";
    auto pos = json.find(needle);
    if (pos == std::string::npos) return fallback;
    pos = json.find('"', pos + needle.length());
    if (pos == std::string::npos) return fallback;
    auto endPos = json.find('"', pos + 1);
    if (endPos == std::string::npos) return fallback;
    return json.substr(pos + 1, endPos - pos - 1);
}

static void hexToRgb(const std::string &hex, double &r, double &g, double &b) {
    std::string h = hex;
    if (!h.empty() && h[0] == '#') h = h.substr(1);
    if (h.length() == 6) {
        try {
            int ir = std::stoi(h.substr(0, 2), nullptr, 16);
            int ig = std::stoi(h.substr(2, 2), nullptr, 16);
            int ib = std::stoi(h.substr(4, 2), nullptr, 16);
            r = ir / 255.0;
            g = ig / 255.0;
            b = ib / 255.0;
        } catch (...) {}
    }
}

static std::string hexToRgbaStr(const std::string &hex, double alpha) {
    double r = 0, g = 0, b = 0;
    hexToRgb(hex, r, g, b);
    char buf[64];
    std::snprintf(buf, sizeof(buf), "rgba(%d, %d, %d, %.2f)", (int)(r * 255), (int)(g * 255), (int)(b * 255), alpha);
    return buf;
}

// ==================== SIDEBAR WINDOW CONSTRUCTOR ====================
SidebarWindow::SidebarWindow(GtkApplication *app) {
    // GtkApplicationWindow: invisible, only needed to keep GApplication running (IPC)
    window = gtk_application_window_new(app);
    gtk_window_set_default_size(GTK_WINDOW(window), 1, 1);
    // Don't show window - it's invisible IPC holder

    // ── REAL VISIBLE WINDOW ── pure GtkWindow = no Adwaita background = transparent!
    uiWindow = gtk_window_new();
    gtk_window_set_title(GTK_WINDOW(uiWindow), "custom-sidebar");
    gtk_window_set_decorated(GTK_WINDOW(uiWindow), FALSE);
    gtk_widget_set_name(uiWindow, "custom-sidebar-window");
    gtk_window_set_application(GTK_WINDOW(uiWindow), app);

    // Wayland Layer-Shell setup on uiWindow
    gtk_layer_init_for_window(GTK_WINDOW(uiWindow));
    gtk_layer_set_namespace(GTK_WINDOW(uiWindow), "custom-sidebar");
    gtk_layer_set_layer(GTK_WINDOW(uiWindow), GTK_LAYER_SHELL_LAYER_TOP);
    gtk_layer_set_anchor(GTK_WINDOW(uiWindow), GTK_LAYER_SHELL_EDGE_RIGHT, TRUE);
    gtk_layer_set_anchor(GTK_WINDOW(uiWindow), GTK_LAYER_SHELL_EDGE_TOP, TRUE);
    gtk_layer_set_anchor(GTK_WINDOW(uiWindow), GTK_LAYER_SHELL_EDGE_BOTTOM, TRUE);
    gtk_layer_set_margin(GTK_WINDOW(uiWindow), GTK_LAYER_SHELL_EDGE_TOP, 38);
    gtk_layer_set_margin(GTK_WINDOW(uiWindow), GTK_LAYER_SHELL_EDGE_BOTTOM, 8);
    gtk_layer_set_margin(GTK_WINDOW(uiWindow), GTK_LAYER_SHELL_EDGE_RIGHT, 8);
    gtk_layer_set_keyboard_mode(GTK_WINDOW(uiWindow), GTK_LAYER_SHELL_KEYBOARD_MODE_ON_DEMAND);
    gtk_window_set_default_size(GTK_WINDOW(uiWindow), 440, -1);

    // Dismiss overlay for outside clicks
    dismissWindow = gtk_window_new();
    gtk_window_set_decorated(GTK_WINDOW(dismissWindow), FALSE);
    gtk_window_set_application(GTK_WINDOW(dismissWindow), app);
    gtk_layer_init_for_window(GTK_WINDOW(dismissWindow));
    gtk_layer_set_namespace(GTK_WINDOW(dismissWindow), "custom-sidebar-dismiss");
    gtk_layer_set_layer(GTK_WINDOW(dismissWindow), GTK_LAYER_SHELL_LAYER_TOP);
    gtk_layer_set_anchor(GTK_WINDOW(dismissWindow), GTK_LAYER_SHELL_EDGE_TOP, TRUE);
    gtk_layer_set_anchor(GTK_WINDOW(dismissWindow), GTK_LAYER_SHELL_EDGE_BOTTOM, TRUE);
    gtk_layer_set_anchor(GTK_WINDOW(dismissWindow), GTK_LAYER_SHELL_EDGE_LEFT, TRUE);
    gtk_layer_set_anchor(GTK_WINDOW(dismissWindow), GTK_LAYER_SHELL_EDGE_RIGHT, TRUE);
    gtk_layer_set_margin(GTK_WINDOW(dismissWindow), GTK_LAYER_SHELL_EDGE_RIGHT, 455);
    gtk_widget_add_css_class(dismissWindow, "dismiss-window");
    gtk_widget_set_opacity(dismissWindow, 0.001);

    GtkWidget *dismissBox = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0);
    gtk_window_set_child(GTK_WINDOW(dismissWindow), dismissBox);

    GtkGesture *dismissClick = gtk_gesture_click_new();
    g_signal_connect_swapped(dismissClick, "pressed", G_CALLBACK(+[](SidebarWindow *self) {
        self->hide();
    }), this);
    gtk_widget_add_controller(dismissWindow, GTK_EVENT_CONTROLLER(dismissClick));

    // Key event controller for Escape (on uiWindow)
    GtkEventController *keyCtrl = gtk_event_controller_key_new();
    g_signal_connect(keyCtrl, "key-pressed", G_CALLBACK(+[](GtkEventControllerKey*, guint keyval, guint, GdkModifierType, gpointer user_data) -> gboolean {
        auto *self = static_cast<SidebarWindow*>(user_data);
        if (keyval == GDK_KEY_Escape) {
            const char *cur = gtk_stack_get_visible_child_name(GTK_STACK(self->mainStack));
            if (cur && std::string(cur) != "main") {
                gtk_stack_set_visible_child_name(GTK_STACK(self->mainStack), "main");
            } else {
                self->hide();
            }
            return TRUE;
        }
        return FALSE;
    }), this);
    gtk_widget_add_controller(uiWindow, keyCtrl);

    // Dynamic color provider (for whole display)
    dynamicCssProvider = gtk_css_provider_new();
    gtk_style_context_add_provider_for_display(
        gdk_display_get_default(),
        GTK_STYLE_PROVIDER(dynamicCssProvider),
        GTK_STYLE_PROVIDER_PRIORITY_APPLICATION + 1
    );
    reloadThemeColors();

    // Main background container (on uiWindow)
    rootBg = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0);
    gtk_widget_add_css_class(rootBg, "sidebar-bg");
    gtk_widget_set_size_request(rootBg, 440, -1);
    gtk_window_set_child(GTK_WINDOW(uiWindow), rootBg);
    sidebarRevealer = nullptr;

    mainStack = gtk_stack_new();
    gtk_widget_set_vexpand(mainStack, TRUE);
    gtk_widget_set_hexpand(mainStack, TRUE);
    gtk_stack_set_transition_type(GTK_STACK(mainStack), GTK_STACK_TRANSITION_TYPE_SLIDE_LEFT_RIGHT);
    gtk_stack_set_transition_duration(GTK_STACK(mainStack), 200);

    buildMainPage();
    gtk_stack_add_named(GTK_STACK(mainStack), mainColumn, "main");
    gtk_stack_add_named(GTK_STACK(mainStack), buildBluetoothDialog(), "btDialog");
    gtk_stack_add_named(GTK_STACK(mainStack), buildWifiDialog(), "wifiDialog");

    gtk_box_append(GTK_BOX(rootBg), mainStack);

    tickSource = g_timeout_add(50, onTick, this);
    refreshAll();
}

SidebarWindow::~SidebarWindow() {
    if (tickSource > 0) g_source_remove(tickSource);
    if (dynamicCssProvider) g_object_unref(dynamicCssProvider);
}

void SidebarWindow::show() {
    reloadThemeColors();
    refreshAll();
    gtk_stack_set_visible_child_name(GTK_STACK(mainStack), "main");
    if (dismissWindow) gtk_widget_set_visible(dismissWindow, TRUE);
    gtk_widget_set_visible(window, TRUE);
    gtk_window_present(GTK_WINDOW(window));
    // Fade-in via CSS class toggle
    gtk_widget_remove_css_class(rootBg, "sidebar-hidden");
    gtk_widget_add_css_class(rootBg, "sidebar-visible");
}

void SidebarWindow::hide() {
    gtk_widget_remove_css_class(rootBg, "sidebar-visible");
    gtk_widget_add_css_class(rootBg, "sidebar-hidden");
    // Hide after fade-out (220ms)
    g_timeout_add(230, +[](gpointer data) -> gboolean {
        auto *self = static_cast<SidebarWindow*>(data);
        gtk_widget_set_visible(self->window, FALSE);
        if (self->dismissWindow) gtk_widget_set_visible(self->dismissWindow, FALSE);
        return G_SOURCE_REMOVE;
    }, this);
}

void SidebarWindow::toggle() {
    if (isVisible()) hide();
    else show();
}

bool SidebarWindow::isVisible() const {
    return gtk_widget_is_visible(window);
}

// ==================== DYNAMIC COLOR ENGINE ====================
void SidebarWindow::reloadThemeColors() {
    std::string colorsJsonPath = std::string(getenv("HOME")) + "/.local/state/quickshell/user/generated/colors.json";
    std::ifstream f(colorsJsonPath);
    std::string jsonStr;
    if (f.is_open()) { std::stringstream ss; ss << f.rdbuf(); jsonStr = ss.str(); }

    // Extract colors from JSON
    std::string primary          = extractJsonColor(jsonStr, "primary",              "#aaccd6");
    std::string onPrimary        = extractJsonColor(jsonStr, "on_primary",            "#11353d");
    std::string primaryContainer = extractJsonColor(jsonStr, "primary_container",     "#44656e");
    std::string bg               = extractJsonColor(jsonStr, "background",            "#121414");
    std::string surfCont         = extractJsonColor(jsonStr, "surface_container",     "#1e2020");
    std::string surfContLow      = extractJsonColor(jsonStr, "surface_container_low", "#1a1c1c");
    std::string onSurface        = extractJsonColor(jsonStr, "on_surface",            "#e3e2e3");
    std::string onSurfaceVar     = extractJsonColor(jsonStr, "on_surface_variant",    "#c1c8ca");
    std::string errorCont        = extractJsonColor(jsonStr, "error_container",       "#93000a");
    std::string onErrorCont      = extractJsonColor(jsonStr, "on_error_container",    "#ffdad6");

    hexToRgb(primary, accentR, accentG, accentB);

    // Build rgba strings
    auto rgba = [](const std::string &hex, double a) -> std::string {
        std::string h = hex;
        if (!h.empty() && h[0]=='#') h = h.substr(1);
        if (h.size() != 6) return "rgba(0,0,0,0)";
        try {
            int r = std::stoi(h.substr(0,2),nullptr,16);
            int g = std::stoi(h.substr(2,2),nullptr,16);
            int b = std::stoi(h.substr(4,2),nullptr,16);
            char buf[64]; std::snprintf(buf,sizeof(buf),"rgba(%d,%d,%d,%.2f)",r,g,b,a);
            return buf;
        } catch(...) { return "rgba(0,0,0,0)"; }
    };

    std::string L0      = rgba(bg,          0.72);
    std::string L0b     = "rgba(255,255,255,0.08)";
    std::string L1      = rgba(surfContLow, 0.76);
    std::string L1h     = rgba(surfContLow, 0.90);
    std::string L2      = rgba(surfCont,    0.86);
    std::string L2h     = rgba(surfCont,    0.96);

    double sr=0,sg=0,sb_=0; hexToRgb(onSurfaceVar,sr,sg,sb_);
    char subBuf[64]; std::snprintf(subBuf,sizeof(subBuf),"rgba(%d,%d,%d,0.60)",(int)(sr*255),(int)(sg*255),(int)(sb_*255));
    std::string subtext = subBuf;

    // Read style.css template (uses __COL_XXX__ placeholders)
    std::string cssPath = std::string(getenv("HOME")) + "/.config/custom-sidebar/style.css";
    std::ifstream cssFile(cssPath);
    std::string css;
    if (cssFile.is_open()) { std::stringstream ss2; ss2 << cssFile.rdbuf(); css = ss2.str(); }

    // Replace placeholders with actual rgba values
    auto rep = [](std::string &s, const std::string &from, const std::string &to) {
        size_t pos = 0;
        while ((pos = s.find(from, pos)) != std::string::npos) {
            s.replace(pos, from.size(), to);
            pos += to.size();
        }
    };

    rep(css, "__L0__",      L0);
    rep(css, "__L0B__",     L0b);
    rep(css, "__L1__",      L1);
    rep(css, "__L1H__",     L1h);
    rep(css, "__L2__",      L2);
    rep(css, "__L2H__",     L2h);
    rep(css, "__PRIMARY__",      primary);
    rep(css, "__ON_PRIMARY__",   onPrimary);
    rep(css, "__PRI_HOVER__",    primary);
    rep(css, "__PRI_CONT__",     primaryContainer);
    rep(css, "__ON_SURFACE__",   onSurface);
    rep(css, "__ON_SURF_VAR__",  onSurfaceVar);
    rep(css, "__SUBTEXT__",      subtext);
    rep(css, "__ERR_CONT__",     errorCont);
    rep(css, "__ON_ERR_CONT__",  onErrorCont);

    // DEBUG: dump resolved CSS to file
    { std::ofstream dbg("/tmp/sidebar_resolved.css"); dbg << css; }

    gtk_css_provider_load_from_string(dynamicCssProvider, css.c_str());
}






// ==================== MAIN PAGE BUILDER ====================
void SidebarWindow::buildMainPage() {
    mainColumn = gtk_box_new(GTK_ORIENTATION_VERTICAL, 10);
    gtk_widget_add_css_class(mainColumn, "main-content-column");

    // 1. Android Quick Panel (Wi-Fi, BT, Uptime | Night Light, Screen Snip, Power)
    gtk_box_append(GTK_BOX(mainColumn), buildQuickTogglesGrid());

    // 2. CenterWidgetGroup (Notification List with placeholder and footer)
    notifCard = buildNotificationsCard();
    gtk_widget_set_vexpand(notifCard, TRUE);
    gtk_box_append(GTK_BOX(mainColumn), notifCard);

    // 3. BottomWidgetGroup (Navigation rail + Calendar & Circular Pomodoro/Stopwatch)
    bottomGroup = buildBottomWidgetGroup();
    gtk_box_append(GTK_BOX(mainColumn), bottomGroup);
}

// 1. Top Quick Toggles (Exact Android-Style 3 cols x 2 rows pills from sidebar_final.png)
GtkWidget* SidebarWindow::buildQuickTogglesGrid() {
    GtkWidget *grid = gtk_grid_new();
    gtk_grid_set_row_spacing(GTK_GRID(grid), 4);
    gtk_grid_set_column_spacing(GTK_GRID(grid), 4);
    gtk_grid_set_row_homogeneous(GTK_GRID(grid), TRUE);
    gtk_grid_set_column_homogeneous(GTK_GRID(grid), TRUE);
    gtk_widget_add_css_class(grid, "quick-panel-grid");

    // ---------------- ROW 0 ----------------
    // Col 0: Wi-Fi Toggle Pill (Material Symbol: "wifi")
    btnWifiToggle = gtk_button_new();
    gtk_widget_add_css_class(btnWifiToggle, "quick-pill-btn");
    GtkWidget *wifiIcon = createIconLabel("wifi", 20, false);
    gtk_widget_add_css_class(wifiIcon, "quick-pill-icon");
    gtk_button_set_child(GTK_BUTTON(btnWifiToggle), wifiIcon);
    gtk_widget_set_tooltip_text(btnWifiToggle, "Wi-Fi (ЛКМ: вкл/выкл, ПКМ: список сетей)");

    GtkGesture *wifiClick = gtk_gesture_click_new();
    gtk_gesture_single_set_button(GTK_GESTURE_SINGLE(wifiClick), 0);
    g_signal_connect(wifiClick, "pressed", G_CALLBACK(+[](GtkGestureClick *gesture, int, double, double, gpointer user_data) {
        auto *self = static_cast<SidebarWindow*>(user_data);
        guint btn = gtk_gesture_single_get_current_button(GTK_GESTURE_SINGLE(gesture));
        if (btn == GDK_BUTTON_SECONDARY) {
            gtk_stack_set_visible_child_name(GTK_STACK(self->mainStack), "wifiDialog");
            self->refreshWifi();
        } else if (btn == GDK_BUTTON_PRIMARY) {
            bool on = WifiManager::isPowered();
            WifiManager::setPowered(!on);
            if (!on) gtk_widget_add_css_class(self->btnWifiToggle, "active");
            else gtk_widget_remove_css_class(self->btnWifiToggle, "active");
        }
    }), this);
    gtk_widget_add_controller(btnWifiToggle, GTK_EVENT_CONTROLLER(wifiClick));
    gtk_grid_attach(GTK_GRID(grid), btnWifiToggle, 0, 0, 1, 1);

    // Col 1: Bluetooth Toggle Pill (Material Symbol: "bluetooth")
    btnBtToggle = gtk_button_new();
    gtk_widget_add_css_class(btnBtToggle, "quick-pill-btn");
    GtkWidget *btIcon = createIconLabel("bluetooth", 20, false);
    gtk_widget_add_css_class(btIcon, "quick-pill-icon");
    gtk_button_set_child(GTK_BUTTON(btnBtToggle), btIcon);
    gtk_widget_set_tooltip_text(btnBtToggle, "Bluetooth (ЛКМ: вкл/выкл, ПКМ: список устройств)");

    GtkGesture *btClick = gtk_gesture_click_new();
    gtk_gesture_single_set_button(GTK_GESTURE_SINGLE(btClick), 0);
    g_signal_connect(btClick, "pressed", G_CALLBACK(+[](GtkGestureClick *gesture, int, double, double, gpointer user_data) {
        auto *self = static_cast<SidebarWindow*>(user_data);
        guint btn = gtk_gesture_single_get_current_button(GTK_GESTURE_SINGLE(gesture));
        if (btn == GDK_BUTTON_SECONDARY) {
            gtk_stack_set_visible_child_name(GTK_STACK(self->mainStack), "btDialog");
            self->refreshBluetooth();
        } else if (btn == GDK_BUTTON_PRIMARY) {
            bool on = BluetoothManager::isPowered();
            BluetoothManager::setPowered(!on);
            if (!on) gtk_widget_add_css_class(self->btnBtToggle, "active");
            else gtk_widget_remove_css_class(self->btnBtToggle, "active");
        }
    }), this);
    gtk_widget_add_controller(btnBtToggle, GTK_EVENT_CONTROLLER(btClick));
    gtk_grid_attach(GTK_GRID(grid), btnBtToggle, 1, 0, 1, 1);

    // Col 2: Uptime Pill (󰣇 Arch icon + 1d, 4h, 58m)
    uptimePill = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 0);
    gtk_widget_add_css_class(uptimePill, "uptime-pill");
    gtk_widget_set_halign(uptimePill, GTK_ALIGN_FILL);

    GtkWidget *uptimeInner = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 6);
    gtk_widget_set_halign(uptimeInner, GTK_ALIGN_CENTER);
    gtk_widget_set_valign(uptimeInner, GTK_ALIGN_CENTER);
    gtk_widget_set_hexpand(uptimeInner, TRUE);

    GtkWidget *distroIcon = gtk_label_new("󰣇");
    gtk_widget_add_css_class(distroIcon, "nerd-icon");
    gtk_box_append(GTK_BOX(uptimeInner), distroIcon);

    uptimeLabel = gtk_label_new("0m");
    gtk_label_set_xalign(GTK_LABEL(uptimeLabel), 0);
    gtk_box_append(GTK_BOX(uptimeInner), uptimeLabel);

    gtk_box_append(GTK_BOX(uptimePill), uptimeInner);
    gtk_grid_attach(GTK_GRID(grid), uptimePill, 2, 0, 1, 1);

    // ---------------- ROW 1 ----------------
    // Col 0: Night Light (Material Symbol: "night_sight_auto")
    btnNightLight = gtk_button_new();
    gtk_widget_add_css_class(btnNightLight, "quick-pill-btn");
    GtkWidget *nlIcon = createIconLabel("night_sight_auto", 20, false);
    gtk_widget_add_css_class(nlIcon, "quick-pill-icon");
    gtk_button_set_child(GTK_BUTTON(btnNightLight), nlIcon);
    gtk_widget_set_tooltip_text(btnNightLight, "Ночной свет (Wlsunset)");

    // Detect initial state: wlsunset running = night light is on
    {
        int ret = system("pgrep -x wlsunset > /dev/null 2>&1");
        nightLightActive = (ret == 0);
        if (nightLightActive) gtk_widget_add_css_class(btnNightLight, "active");
    }

    g_signal_connect(btnNightLight, "clicked", G_CALLBACK(+[](GtkButton*, gpointer user_data) {
        auto *self = static_cast<SidebarWindow*>(user_data);
        self->nightLightActive = !self->nightLightActive;
        if (self->nightLightActive) {
            // Restart wlsunset in always-on warm mode (same as daemon args)
            system("pkill -x wlsunset 2>/dev/null; sleep 0.1 && "
                   "/home/chezok/.local/bin/wlsunset -t 2800 -T 2801 -s 00:00 -S 23:59 >/dev/null 2>&1 &");
            gtk_widget_add_css_class(self->btnNightLight, "active");
        } else {
            // Kill wlsunset and reset to neutral temperature
            system("pkill -x wlsunset 2>/dev/null; sleep 0.1 && "
                   "wlsunset -t 6500 -T 6501 -s 00:00 -S 00:01 >/dev/null 2>&1 &");
            gtk_widget_remove_css_class(self->btnNightLight, "active");
        }
    }), this);
    gtk_grid_attach(GTK_GRID(grid), btnNightLight, 0, 1, 1, 1);

    // Col 1: Screen Snip / Region (Material Symbol: "screenshot_region")
    btnScreenSnip = gtk_button_new();
    gtk_widget_add_css_class(btnScreenSnip, "quick-pill-btn");
    GtkWidget *cropIcon = createIconLabel("screenshot_region", 20, false);
    gtk_widget_add_css_class(cropIcon, "quick-pill-icon");
    gtk_button_set_child(GTK_BUTTON(btnScreenSnip), cropIcon);
    gtk_widget_set_tooltip_text(btnScreenSnip, "Скриншот области");
    g_signal_connect_swapped(btnScreenSnip, "clicked", G_CALLBACK(+[](SidebarWindow *self) {
        self->hide();
        system("sleep 0.2 && niri msg action screenshot &");
    }), this);
    gtk_grid_attach(GTK_GRID(grid), btnScreenSnip, 1, 1, 1, 1);

    // Col 2: Power Button Pill (Material Symbol: "power_settings_new" + "Питание")
    btnPower = gtk_button_new();
    gtk_widget_add_css_class(btnPower, "power-pill");
    GtkWidget *pBox = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 6);
    gtk_widget_set_halign(pBox, GTK_ALIGN_CENTER);
    gtk_widget_set_valign(pBox, GTK_ALIGN_CENTER);
    GtkWidget *pIcon = createIconLabel("power_settings_new", 18, false);
    GtkWidget *pLbl = gtk_label_new("Питание");
    gtk_box_append(GTK_BOX(pBox), pIcon);
    gtk_box_append(GTK_BOX(pBox), pLbl);
    gtk_button_set_child(GTK_BUTTON(btnPower), pBox);
    gtk_widget_set_tooltip_text(btnPower, "Меню питания");
    g_signal_connect_swapped(btnPower, "clicked", G_CALLBACK(+[](SidebarWindow *self) {
        self->hide();
        system("quickshell -p ~/.config/niri/scripts/power-menu/ 2>/dev/null || systemctl poweroff &");
    }), this);
    gtk_grid_attach(GTK_GRID(grid), btnPower, 2, 1, 1, 1);

    return grid;
}

// 2. Notifications Card (Matches sidebar_final.png & NotificationList.qml)
GtkWidget* SidebarWindow::buildNotificationsCard() {
    GtkWidget *card = gtk_box_new(GTK_ORIENTATION_VERTICAL, 6);
    gtk_widget_add_css_class(card, "notifications-card");

    // Scrollable list
    notifScrolled = gtk_scrolled_window_new();
    gtk_widget_set_vexpand(notifScrolled, TRUE);
    gtk_widget_add_css_class(notifScrolled, "notif-scroll-area");

    notifListBox = gtk_box_new(GTK_ORIENTATION_VERTICAL, 6);
    gtk_scrolled_window_set_child(GTK_SCROLLED_WINDOW(notifScrolled), notifListBox);

    // Empty Placeholder
    notifPlaceholder = gtk_box_new(GTK_ORIENTATION_VERTICAL, 4);
    gtk_widget_set_valign(notifPlaceholder, GTK_ALIGN_CENTER);
    gtk_widget_set_halign(notifPlaceholder, GTK_ALIGN_CENTER);
    gtk_widget_set_vexpand(notifPlaceholder, TRUE);
    gtk_widget_add_css_class(notifPlaceholder, "notif-placeholder");

    GtkWidget *phIcon = createIconLabel("notifications_active", 44, false);
    gtk_widget_add_css_class(phIcon, "notif-placeholder-icon");
    gtk_box_append(GTK_BOX(notifPlaceholder), phIcon);

    GtkWidget *phText = gtk_label_new("Нет уведомлений");
    gtk_widget_add_css_class(phText, "notif-placeholder-text");
    gtk_box_append(GTK_BOX(notifPlaceholder), phText);

    gtk_box_append(GTK_BOX(card), notifPlaceholder);
    gtk_box_append(GTK_BOX(card), notifScrolled);

    // Status Row: [notifications_paused DND] | [6 уведомл.] | [delete_sweep Trash]
    GtkWidget *statusRow = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 8);
    gtk_widget_add_css_class(statusRow, "notif-status-row");

    btnDnd = gtk_button_new();
    gtk_widget_add_css_class(btnDnd, "notif-action-btn");
    GtkWidget *dndIco = createIconLabel("notifications_paused", 18, false);
    gtk_button_set_child(GTK_BUTTON(btnDnd), dndIco);
    gtk_widget_set_tooltip_text(btnDnd, "Не беспокоить (DND)");
    g_signal_connect_swapped(btnDnd, "clicked", G_CALLBACK(+[](SidebarWindow *self) {
        system("swaync-client -d -sw >/dev/null 2>&1 &");
        self->refreshNotifications();
    }), this);
    gtk_box_append(GTK_BOX(statusRow), btnDnd);

    notifCountLabel = gtk_label_new("Уведомлений нет");
    gtk_widget_set_hexpand(notifCountLabel, TRUE);
    gtk_label_set_xalign(GTK_LABEL(notifCountLabel), 0.5);
    gtk_widget_add_css_class(notifCountLabel, "notif-count-text");
    gtk_box_append(GTK_BOX(statusRow), notifCountLabel);

    btnClearAll = gtk_button_new();
    gtk_widget_add_css_class(btnClearAll, "notif-action-btn");
    GtkWidget *trashIco = createIconLabel("delete_sweep", 18, false);
    gtk_button_set_child(GTK_BUTTON(btnClearAll), trashIco);
    gtk_widget_set_tooltip_text(btnClearAll, "Очистить все");
    g_signal_connect_swapped(btnClearAll, "clicked", G_CALLBACK(+[](SidebarWindow *self) {
        system("swaync-client -C >/dev/null 2>&1 &");
        self->refreshNotifications();
    }), this);
    gtk_box_append(GTK_BOX(statusRow), btnClearAll);

    gtk_box_append(GTK_BOX(card), statusRow);
    return card;
}

// 3. Bottom Widget Group (Left Rail + Content Stack)
GtkWidget* SidebarWindow::buildBottomWidgetGroup() {
    GtkWidget *card = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 8);
    gtk_widget_add_css_class(card, "bottom-widget-group");
    gtk_widget_set_size_request(card, -1, 275);

    // Left Navigation Rail
    GtkWidget *navRail = gtk_box_new(GTK_ORIENTATION_VERTICAL, 6);
    gtk_widget_add_css_class(navRail, "nav-rail");
    gtk_widget_set_valign(navRail, GTK_ALIGN_CENTER);

    // 1. Календарь Button (Material Symbol: "calendar_month")
    btnNavCalendar = gtk_button_new();
    gtk_widget_add_css_class(btnNavCalendar, "nav-rail-btn");
    GtkWidget *calBox = gtk_box_new(GTK_ORIENTATION_VERTICAL, 2);
    GtkWidget *calIco = createIconLabel("calendar_month", 22, false);
    gtk_widget_add_css_class(calIco, "nav-rail-icon");
    GtkWidget *calTxt = gtk_label_new("Календарь");
    gtk_widget_add_css_class(calTxt, "nav-rail-label");
    gtk_box_append(GTK_BOX(calBox), calIco);
    gtk_box_append(GTK_BOX(calBox), calTxt);
    gtk_button_set_child(GTK_BUTTON(btnNavCalendar), calBox);
    gtk_box_append(GTK_BOX(navRail), btnNavCalendar);

    // 2. Таймер Button (Material Symbol: "schedule", Active by default)
    btnNavTimer = gtk_button_new();
    gtk_widget_add_css_class(btnNavTimer, "nav-rail-btn");
    gtk_widget_add_css_class(btnNavTimer, "active");
    GtkWidget *tmrBox = gtk_box_new(GTK_ORIENTATION_VERTICAL, 2);
    GtkWidget *tmrIco = createIconLabel("schedule", 22, false);
    gtk_widget_add_css_class(tmrIco, "nav-rail-icon");
    GtkWidget *tmrTxt = gtk_label_new("Таймер");
    gtk_widget_add_css_class(tmrTxt, "nav-rail-label");
    gtk_box_append(GTK_BOX(tmrBox), tmrIco);
    gtk_box_append(GTK_BOX(tmrBox), tmrTxt);
    gtk_button_set_child(GTK_BUTTON(btnNavTimer), tmrBox);
    gtk_box_append(GTK_BOX(navRail), btnNavTimer);

    gtk_box_append(GTK_BOX(card), navRail);

    // Right Content Stack
    bottomStack = gtk_stack_new();
    gtk_widget_set_hexpand(bottomStack, TRUE);
    gtk_widget_set_vexpand(bottomStack, TRUE);
    gtk_stack_set_transition_type(GTK_STACK(bottomStack), GTK_STACK_TRANSITION_TYPE_SLIDE_UP_DOWN);
    gtk_stack_set_transition_duration(GTK_STACK(bottomStack), 180);

    gtk_stack_add_named(GTK_STACK(bottomStack), buildCalendarContent(), "calendar");
    gtk_stack_add_named(GTK_STACK(bottomStack), buildTimerContent(), "timer");
    gtk_stack_set_visible_child_name(GTK_STACK(bottomStack), "timer");

    // Nav Switch Handlers
    g_signal_connect_swapped(btnNavCalendar, "clicked", G_CALLBACK(+[](SidebarWindow *self) {
        gtk_stack_set_visible_child_name(GTK_STACK(self->bottomStack), "calendar");
        gtk_widget_remove_css_class(self->btnNavTimer, "active");
        gtk_widget_add_css_class(self->btnNavCalendar, "active");
        self->activeBottomTab = 0;
        self->updateCalendarDisplay();
    }), this);

    g_signal_connect_swapped(btnNavTimer, "clicked", G_CALLBACK(+[](SidebarWindow *self) {
        gtk_stack_set_visible_child_name(GTK_STACK(self->bottomStack), "timer");
        gtk_widget_remove_css_class(self->btnNavCalendar, "active");
        gtk_widget_add_css_class(self->btnNavTimer, "active");
        self->activeBottomTab = 1;
        self->updateTimerDisplay();
    }), this);

    gtk_box_append(GTK_BOX(card), bottomStack);
    return card;
}

// Timer Widget with Secondary Tab Bar, Oval Capsule, Presets & Action Buttons
GtkWidget* SidebarWindow::buildTimerContent() {
    GtkWidget *box = gtk_box_new(GTK_ORIENTATION_VERTICAL, 4);
    gtk_widget_set_hexpand(box, TRUE);

    // Secondary Tab Bar: [schedule Таймер] | [timer Секундомер]
    GtkWidget *tabBar = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 0);
    gtk_widget_add_css_class(tabBar, "timer-tab-bar");

    btnSubTabTimer = gtk_button_new();
    gtk_widget_add_css_class(btnSubTabTimer, "timer-subtab-btn");
    gtk_widget_add_css_class(btnSubTabTimer, "active");
    GtkWidget *st1Box = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 4);
    GtkWidget *st1Ico = createIconLabel("schedule", 16, false);
    GtkWidget *st1Txt = gtk_label_new("Таймер");
    gtk_box_append(GTK_BOX(st1Box), st1Ico);
    gtk_box_append(GTK_BOX(st1Box), st1Txt);
    gtk_button_set_child(GTK_BUTTON(btnSubTabTimer), st1Box);
    gtk_box_append(GTK_BOX(tabBar), btnSubTabTimer);

    btnSubTabStopwatch = gtk_button_new();
    gtk_widget_add_css_class(btnSubTabStopwatch, "timer-subtab-btn");
    GtkWidget *st2Box = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 4);
    GtkWidget *st2Ico = createIconLabel("timer", 16, false);
    GtkWidget *st2Txt = gtk_label_new("Секундомер");
    gtk_box_append(GTK_BOX(st2Box), st2Ico);
    gtk_box_append(GTK_BOX(st2Box), st2Txt);
    gtk_button_set_child(GTK_BUTTON(btnSubTabStopwatch), st2Box);
    gtk_box_append(GTK_BOX(tabBar), btnSubTabStopwatch);

    gtk_box_append(GTK_BOX(box), tabBar);

    // Tab Switch Signals
    g_signal_connect_swapped(btnSubTabTimer, "clicked", G_CALLBACK(+[](SidebarWindow *self) {
        self->activeTimerSubTab = 0;
        gtk_widget_add_css_class(self->btnSubTabTimer, "active");
        gtk_widget_remove_css_class(self->btnSubTabStopwatch, "active");
        gtk_widget_set_visible(self->presetsRow, TRUE);
        gtk_label_set_text(GTK_LABEL(self->timerSubLabel), "Таймер");
        self->updateTimerDisplay();
    }), this);

    g_signal_connect_swapped(btnSubTabStopwatch, "clicked", G_CALLBACK(+[](SidebarWindow *self) {
        self->activeTimerSubTab = 1;
        gtk_widget_add_css_class(self->btnSubTabStopwatch, "active");
        gtk_widget_remove_css_class(self->btnSubTabTimer, "active");
        gtk_widget_set_visible(self->presetsRow, FALSE);
        gtk_label_set_text(GTK_LABEL(self->timerSubLabel), "Секундомер");
        self->updateTimerDisplay();
    }), this);

    // ── OVAL PILL CAPSULE (260×74 px, radius = height/2) ──────────────────
    // Outer overlay: holds progress-fill behind, content on top
    timerCapsule = gtk_overlay_new();
    gtk_widget_add_css_class(timerCapsule, "timer-capsule");
    gtk_widget_set_halign(timerCapsule, GTK_ALIGN_CENTER);
    gtk_widget_set_valign(timerCapsule, GTK_ALIGN_CENTER);
    gtk_widget_set_size_request(timerCapsule, 260, 74);

    // Progress fill background (clipped by CSS border-radius)
    timerProgressFill = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 0);
    gtk_widget_add_css_class(timerProgressFill, "timer-capsule-fill");
    gtk_widget_set_halign(timerProgressFill, GTK_ALIGN_START);
    gtk_widget_set_valign(timerProgressFill, GTK_ALIGN_FILL);
    gtk_widget_set_size_request(timerProgressFill, 0, -1); // updated dynamically
    gtk_overlay_set_child(GTK_OVERLAY(timerCapsule), timerProgressFill);

    // Inner stack: "display" (running) vs "input" (stopped)
    timerInputStack = gtk_stack_new();
    gtk_stack_set_transition_type(GTK_STACK(timerInputStack), GTK_STACK_TRANSITION_TYPE_CROSSFADE);
    gtk_stack_set_transition_duration(GTK_STACK(timerInputStack), 200);
    gtk_widget_set_halign(timerInputStack, GTK_ALIGN_CENTER);
    gtk_widget_set_valign(timerInputStack, GTK_ALIGN_CENTER);

    // -- Page "display": big time + ms suffix + subtitle
    GtkWidget *displayBox = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0);
    gtk_widget_set_halign(displayBox, GTK_ALIGN_CENTER);
    gtk_widget_set_valign(displayBox, GTK_ALIGN_CENTER);

    GtkWidget *timeRow = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 0);
    gtk_widget_set_halign(timeRow, GTK_ALIGN_CENTER);

    timerTimeLabel = gtk_label_new("05:00");
    gtk_widget_add_css_class(timerTimeLabel, "timer-big-display");
    gtk_box_append(GTK_BOX(timeRow), timerTimeLabel);

    timerMsLabel = gtk_label_new("");
    gtk_widget_add_css_class(timerMsLabel, "timer-ms-display");
    gtk_widget_set_valign(timerMsLabel, GTK_ALIGN_END);
    gtk_widget_set_margin_bottom(timerMsLabel, 4);
    gtk_box_append(GTK_BOX(timeRow), timerMsLabel);

    gtk_box_append(GTK_BOX(displayBox), timeRow);

    timerSubLabel = gtk_label_new("Таймер");
    gtk_widget_add_css_class(timerSubLabel, "timer-sub-display");
    gtk_box_append(GTK_BOX(displayBox), timerSubLabel);

    gtk_stack_add_named(GTK_STACK(timerInputStack), displayBox, "display");

    // -- Page "input": H : M : S entry fields
    GtkWidget *inputBox = gtk_box_new(GTK_ORIENTATION_VERTICAL, 2);
    gtk_widget_set_halign(inputBox, GTK_ALIGN_CENTER);
    gtk_widget_set_valign(inputBox, GTK_ALIGN_CENTER);

    GtkWidget *fieldsRow = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 4);
    gtk_widget_set_halign(fieldsRow, GTK_ALIGN_CENTER);

    auto makeTimeField = [&](GtkWidget *&entryRef, const char *placeholder, int defVal) {
        GtkWidget *col = gtk_box_new(GTK_ORIENTATION_VERTICAL, 2);
        gtk_widget_set_halign(col, GTK_ALIGN_CENTER);
        entryRef = gtk_entry_new();
        gtk_widget_add_css_class(entryRef, "timer-entry");
        gtk_entry_set_max_length(GTK_ENTRY(entryRef), 2);
        gtk_entry_set_input_purpose(GTK_ENTRY(entryRef), GTK_INPUT_PURPOSE_DIGITS);
        gtk_entry_set_placeholder_text(GTK_ENTRY(entryRef), placeholder);
        char def[4]; std::snprintf(def, sizeof(def), "%02d", defVal);
        gtk_editable_set_text(GTK_EDITABLE(entryRef), def);
        gtk_widget_set_size_request(entryRef, 48, -1);
        GtkWidget *lbl = gtk_label_new(placeholder);
        gtk_widget_add_css_class(lbl, "timer-entry-label");
        gtk_box_append(GTK_BOX(col), entryRef);
        gtk_box_append(GTK_BOX(col), lbl);
        return col;
    };

    gtk_box_append(GTK_BOX(fieldsRow), makeTimeField(timerHEntry, "Ч", 0));
    GtkWidget *sep1 = gtk_label_new(":");
    gtk_widget_add_css_class(sep1, "timer-sep");
    gtk_widget_set_valign(sep1, GTK_ALIGN_START);
    gtk_widget_set_margin_top(sep1, 4);
    gtk_box_append(GTK_BOX(fieldsRow), sep1);
    gtk_box_append(GTK_BOX(fieldsRow), makeTimeField(timerMEntry, "М", 5));
    GtkWidget *sep2 = gtk_label_new(":");
    gtk_widget_add_css_class(sep2, "timer-sep");
    gtk_widget_set_valign(sep2, GTK_ALIGN_START);
    gtk_widget_set_margin_top(sep2, 4);
    gtk_box_append(GTK_BOX(fieldsRow), sep2);
    gtk_box_append(GTK_BOX(fieldsRow), makeTimeField(timerSEntry, "С", 0));
    gtk_box_append(GTK_BOX(inputBox), fieldsRow);

    gtk_stack_add_named(GTK_STACK(timerInputStack), inputBox, "input");
    gtk_stack_set_visible_child_name(GTK_STACK(timerInputStack), "input");

    gtk_overlay_add_overlay(GTK_OVERLAY(timerCapsule), timerInputStack);
    gtk_box_append(GTK_BOX(box), timerCapsule);

    // Commit H:M:S when focus leaves
    auto commitInput = [](GtkEventControllerFocus*, gpointer user_data) {
        auto *self = static_cast<SidebarWindow*>(user_data);
        if (self->timer.isRunning()) return;
        const char *ht = gtk_editable_get_text(GTK_EDITABLE(self->timerHEntry));
        const char *mt = gtk_editable_get_text(GTK_EDITABLE(self->timerMEntry));
        const char *st = gtk_editable_get_text(GTK_EDITABLE(self->timerSEntry));
        int h = ht && *ht ? std::atoi(ht) : 0;
        int m = mt && *mt ? std::atoi(mt) : 0;
        int s = st && *st ? std::atoi(st) : 0;
        int total = h*3600 + m*60 + s;
        if (total < 10) total = 300; // default 5m if input is garbage
        self->timer.setDuration(0, 0, total);
        self->updateTimerDisplay();
    };

    for (GtkWidget *entry : {timerHEntry, timerMEntry, timerSEntry}) {
        GtkEventController *fc = gtk_event_controller_focus_new();
        g_signal_connect(fc, "leave", G_CALLBACK(+commitInput), this);
        gtk_widget_add_controller(entry, fc);
    }

    // Quick Presets Row: -1м, 1м, 5м, 10м, 15м, 25м, 30м, +1м
    presetsRow = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 4);
    gtk_widget_set_halign(presetsRow, GTK_ALIGN_CENTER);
    gtk_widget_add_css_class(presetsRow, "presets-row");

    presetButtons.clear();
    const std::vector<std::pair<std::string, int>> presets = {
        {"-1м", -60}, {"1м", 60}, {"5м", 300}, {"10м", 600},
        {"15м", 900}, {"25м", 1500}, {"30м", 1800}, {"+1м", 60}
    };

    for (const auto &p : presets) {
        GtkWidget *b = gtk_button_new_with_label(p.first.c_str());
        gtk_widget_add_css_class(b, "preset-pill");
        if (p.first == "5м") gtk_widget_add_css_class(b, "active");

        g_object_set_data(G_OBJECT(b), "val", GINT_TO_POINTER(p.second));
        g_object_set_data(G_OBJECT(b), "is_add", GINT_TO_POINTER((p.first[0] == '+' || p.first[0] == '-') ? 1 : 0));
        g_object_set_data(G_OBJECT(b), "sidebar", this);

        g_signal_connect(b, "clicked", G_CALLBACK(+[](GtkButton *btn, gpointer) {
            auto *s = static_cast<SidebarWindow*>(g_object_get_data(G_OBJECT(btn), "sidebar"));
            int val = GPOINTER_TO_INT(g_object_get_data(G_OBJECT(btn), "val"));
            int isAdd = GPOINTER_TO_INT(g_object_get_data(G_OBJECT(btn), "is_add"));

            if (isAdd) {
                s->timer.addSeconds(val);
            } else {
                s->timer.setDuration(0, 0, val);
                for (auto *other : s->presetButtons) gtk_widget_remove_css_class(other, "active");
                gtk_widget_add_css_class(GTK_WIDGET(btn), "active");
            }
            s->updateTimerDisplay();
        }), nullptr);

        presetButtons.push_back(b);
        gtk_box_append(GTK_BOX(presetsRow), b);
    }
    gtk_box_append(GTK_BOX(box), presetsRow);

    // Action Buttons
    GtkWidget *actionsRow = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 8);
    gtk_widget_set_halign(actionsRow, GTK_ALIGN_CENTER);
    gtk_widget_add_css_class(actionsRow, "timer-actions-row");

    btnTimerAction = gtk_button_new_with_label("Старт");
    gtk_widget_add_css_class(btnTimerAction, "btn-action-primary");
    g_signal_connect_swapped(btnTimerAction, "clicked", G_CALLBACK(+[](SidebarWindow *self) {
        if (self->activeTimerSubTab == 0) {
            if (self->timer.isRunning()) self->timer.pause();
            else {
                // Commit any pending input before starting
                if (!self->timer.isRunning()) {
                    const char *ht = gtk_editable_get_text(GTK_EDITABLE(self->timerHEntry));
                    const char *mt = gtk_editable_get_text(GTK_EDITABLE(self->timerMEntry));
                    const char *st = gtk_editable_get_text(GTK_EDITABLE(self->timerSEntry));
                    int h = ht && *ht ? std::atoi(ht) : 0;
                    int m = mt && *mt ? std::atoi(mt) : 0;
                    int s = st && *st ? std::atoi(st) : 0;
                    int total = h*3600 + m*60 + s;
                    if (total >= 1) self->timer.setDuration(0, 0, total);
                }
                self->timer.start();
            }
        } else {
            if (self->stopwatch.isRunning()) self->stopwatch.pause();
            else self->stopwatch.start();
        }
        self->updateTimerDisplay();
    }), this);
    gtk_box_append(GTK_BOX(actionsRow), btnTimerAction);

    btnTimerReset = gtk_button_new_with_label("Сброс");
    gtk_widget_add_css_class(btnTimerReset, "btn-action-danger");
    g_signal_connect_swapped(btnTimerReset, "clicked", G_CALLBACK(+[](SidebarWindow *self) {
        if (self->activeTimerSubTab == 0) self->timer.reset();
        else self->stopwatch.reset();
        self->updateTimerDisplay();
    }), this);
    gtk_box_append(GTK_BOX(actionsRow), btnTimerReset);

    gtk_box_append(GTK_BOX(box), actionsRow);
    return box;
}


double SidebarWindow::getTimerProgress() const {
    return timer.getProgress();
}

void SidebarWindow::updateTimerDisplay() {
    bool running = false;
    bool finished = false;

    if (activeTimerSubTab == 0) {
        // --- Timer mode ---
        running = timer.isRunning();
        finished = timer.isFinished();

        if (running) {
            // Show display page with MM:SS and milliseconds
            if (timerInputStack)
                gtk_stack_set_visible_child_name(GTK_STACK(timerInputStack), "display");
            gtk_label_set_text(GTK_LABEL(timerTimeLabel), timer.getDisplayTime().c_str());
            gtk_label_set_text(GTK_LABEL(timerMsLabel), timer.getDisplayMs().c_str());
            gtk_button_set_label(GTK_BUTTON(btnTimerAction), "Пауза");
        } else if (finished) {
            // Finished: show time 00:00 in display page
            if (timerInputStack)
                gtk_stack_set_visible_child_name(GTK_STACK(timerInputStack), "display");
            gtk_label_set_text(GTK_LABEL(timerTimeLabel), "00:00");
            gtk_label_set_text(GTK_LABEL(timerMsLabel), "");
            gtk_button_set_label(GTK_BUTTON(btnTimerAction), "Старт");
        } else {
            // Stopped/paused: show input page
            if (timerInputStack)
                gtk_stack_set_visible_child_name(GTK_STACK(timerInputStack), "input");
            gtk_label_set_text(GTK_LABEL(timerMsLabel), "");
            gtk_button_set_label(GTK_BUTTON(btnTimerAction),
                timer.getRemainingMs() < timer.getDurationMs() && timer.getRemainingMs() > 0
                ? "Продолжить" : "Старт");
        }

        // Update progress fill width
        if (timerProgressFill && timerCapsule) {
            double progress = timer.getProgress();
            int capsuleW = gtk_widget_get_width(timerCapsule);
            if (capsuleW <= 0) capsuleW = 260;
            int fillW = (int)(capsuleW * progress);
            gtk_widget_set_size_request(timerProgressFill, fillW, -1);
        }
        // Running border indicator
        if (timerCapsule) {
            if (running) gtk_widget_add_css_class(timerCapsule, "running");
            else gtk_widget_remove_css_class(timerCapsule, "running");
        }

    } else {
        // --- Stopwatch mode ---
        running = stopwatch.isRunning();
        if (timerInputStack)
            gtk_stack_set_visible_child_name(GTK_STACK(timerInputStack), "display");
        gtk_label_set_text(GTK_LABEL(timerTimeLabel), stopwatch.getDisplayTime().c_str());
        gtk_label_set_text(GTK_LABEL(timerMsLabel), "");
        gtk_button_set_label(GTK_BUTTON(btnTimerAction), running ? "Пауза" : "Старт");

        // Progress fill for stopwatch: per-minute cycle
        if (timerProgressFill && timerCapsule) {
            double sec = stopwatch.getElapsedSeconds();
            double progress = std::fmod(sec, 60.0) / 60.0;
            int capsuleW = gtk_widget_get_width(timerCapsule);
            if (capsuleW <= 0) capsuleW = 260;
            int fillW = (int)(capsuleW * progress);
            gtk_widget_set_size_request(timerProgressFill, fillW, -1);
        }
    }
}


// 4. Calendar Content Builder
GtkWidget* SidebarWindow::buildCalendarContent() {
    GtkWidget *calBox = gtk_box_new(GTK_ORIENTATION_VERTICAL, 4);
    gtk_widget_add_css_class(calBox, "calendar-widget");
    gtk_widget_set_halign(calBox, GTK_ALIGN_CENTER);

    // Header: Month Year + Prev/Next
    GtkWidget *head = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 4);
    gtk_widget_set_size_request(head, 7 * 34 + 6 * 3, -1); // exact width = cells

    GtkWidget *btnMonthPill = gtk_button_new();
    gtk_widget_add_css_class(btnMonthPill, "cal-month-pill");
    calMonthLabel = gtk_label_new("Сентябрь 2026");
    gtk_label_set_xalign(GTK_LABEL(calMonthLabel), 0);
    gtk_button_set_child(GTK_BUTTON(btnMonthPill), calMonthLabel);
    gtk_widget_set_hexpand(btnMonthPill, TRUE);
    g_signal_connect_swapped(btnMonthPill, "clicked", G_CALLBACK(+[](SidebarWindow *self) {
        if (self->calMonthShift != 0) {
            self->calMonthShift = 0;
            self->updateCalendarDisplay();
        }
    }), this);
    gtk_box_append(GTK_BOX(head), btnMonthPill);

    GtkWidget *btnPrev = createIconButton("chevron_left", "cal-arrow-btn", 18);
    g_signal_connect_swapped(btnPrev, "clicked", G_CALLBACK(+[](SidebarWindow *self) {
        self->calMonthShift--;
        self->updateCalendarDisplay();
    }), this);
    gtk_box_append(GTK_BOX(head), btnPrev);

    GtkWidget *btnNext = createIconButton("chevron_right", "cal-arrow-btn", 18);
    g_signal_connect_swapped(btnNext, "clicked", G_CALLBACK(+[](SidebarWindow *self) {
        self->calMonthShift++;
        self->updateCalendarDisplay();
    }), this);
    gtk_box_append(GTK_BOX(head), btnNext);

    gtk_box_append(GTK_BOX(calBox), head);

    // Weekday headers row — fixed 34px each, 3px gap
    GtkWidget *wdRow = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 3);
    gtk_widget_set_halign(wdRow, GTK_ALIGN_CENTER);
    const char *days[] = {"Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"};
    for (int i = 0; i < 7; i++) {
        GtkWidget *l = gtk_label_new(days[i]);
        gtk_widget_set_size_request(l, 34, 26);
        gtk_label_set_xalign(GTK_LABEL(l), 0.5f);
        gtk_widget_add_css_class(l, "cal-weekday");
        gtk_box_append(GTK_BOX(wdRow), l);
    }
    gtk_box_append(GTK_BOX(calBox), wdRow);

    // Grid of day buttons — 6 rows × 7 cols, 34×34 each, 3px gap
    calGrid = gtk_grid_new();
    gtk_grid_set_row_spacing(GTK_GRID(calGrid), 3);
    gtk_grid_set_column_spacing(GTK_GRID(calGrid), 3);
    gtk_grid_set_row_homogeneous(GTK_GRID(calGrid), FALSE);
    gtk_grid_set_column_homogeneous(GTK_GRID(calGrid), FALSE);
    gtk_widget_set_halign(calGrid, GTK_ALIGN_CENTER);
    gtk_box_append(GTK_BOX(calBox), calGrid);

    updateCalendarDisplay();
    return calBox;
}


static bool isLeap(int y) {
    return (y % 400 == 0 || (y % 4 == 0 && y % 100 != 0));
}

static int getMonthDaysCount(int m, int y) {
    if ((m <= 7 && m % 2 == 1) || (m >= 8 && m % 2 == 0)) return 31;
    if (m == 2) return isLeap(y) ? 29 : 28;
    return 30;
}

void SidebarWindow::updateCalendarDisplay() {
    GtkWidget *child = gtk_widget_get_first_child(calGrid);
    while (child) {
        GtkWidget *next = gtk_widget_get_next_sibling(child);
        gtk_grid_remove(GTK_GRID(calGrid), child);
        child = next;
    }

    std::time_t t = std::time(nullptr);
    std::tm tm = *std::localtime(&t);
    int realCurDay = tm.tm_mday;
    int realCurMonth = tm.tm_mon + 1;
    int realCurYear = tm.tm_year + 1900;

    int targetMonth = realCurMonth + calMonthShift;
    int targetYear = realCurYear;
    while (targetMonth > 12) { targetMonth -= 12; targetYear++; }
    while (targetMonth < 1) { targetMonth += 12; targetYear--; }

    const char *monthsRu[] = {"Январь", "Февраль", "Март", "Апрель", "Май", "Июнь", "Июль", "Август", "Сентябрь", "Октябрь", "Ноябрь", "Декабрь"};
    std::string mStr = (calMonthShift != 0 ? "• " : "") + std::string(monthsRu[targetMonth - 1]) + " " + std::to_string(targetYear);
    gtk_label_set_text(GTK_LABEL(calMonthLabel), mStr.c_str());

    std::tm tFirst = {};
    tFirst.tm_year = targetYear - 1900;
    tFirst.tm_mon = targetMonth - 1;
    tFirst.tm_mday = 1;
    std::mktime(&tFirst);
    int startWday = (tFirst.tm_wday + 6) % 7; // Mon = 0

    int daysInMonth = getMonthDaysCount(targetMonth, targetYear);
    int prevMonth = (targetMonth == 1) ? 12 : (targetMonth - 1);
    int prevYear = (targetMonth == 1) ? (targetYear - 1) : targetYear;
    int daysInPrev = getMonthDaysCount(prevMonth, prevYear);
    int nextMonth = (targetMonth == 12) ? 1 : (targetMonth + 1);
    int nextYear = (targetMonth == 12) ? (targetYear + 1) : targetYear;
    int daysInNext = getMonthDaysCount(nextMonth, nextYear);

    int monthDiff = (startWday == 0 ? 0 : -1);
    int toFill = (startWday == 0) ? 1 : (daysInPrev - (startWday - 1));
    int dim = (startWday == 0) ? daysInMonth : daysInPrev;
    bool isCurrentMonth = (targetMonth == realCurMonth && targetYear == realCurYear);

    int i = 0, j = 0;
    while (i < 6 && j < 7) {
        GtkWidget *dBtn = gtk_button_new_with_label(std::to_string(toFill).c_str());
        gtk_widget_add_css_class(dBtn, "cal-day-btn");
        gtk_widget_set_size_request(dBtn, 34, 34);

        if (monthDiff == 0) {
            if (isCurrentMonth && toFill == realCurDay) {
                gtk_widget_add_css_class(dBtn, "cal-today");
            }
        } else {
            gtk_widget_add_css_class(dBtn, "cal-day-other");
        }

        gtk_grid_attach(GTK_GRID(calGrid), dBtn, j, i, 1, 1);

        toFill++;
        if (toFill > dim) {
            monthDiff++;
            if (monthDiff == 0) dim = daysInMonth;
            else if (monthDiff == 1) dim = daysInNext;
            toFill = 1;
        }

        j++;
        if (j == 7) {
            j = 0;
            i++;
        }
    }
}

// ==================== TICK TIMER ====================
gboolean SidebarWindow::onTick(gpointer data) {
    auto *self = static_cast<SidebarWindow*>(data);
    if (!self->isVisible()) return TRUE;

    if (self->activeTimerSubTab == 0) {
        if (self->timer.isRunning()) {
            self->timer.tick();
            self->updateTimerDisplay();
        }
    } else {
        if (self->stopwatch.isRunning()) {
            self->stopwatch.tick();
            self->updateTimerDisplay();
        }
    }
    return TRUE;
}

// ==================== OVERLAY DIALOGS ====================
// BluetoothDialog
GtkWidget* SidebarWindow::buildBluetoothDialog() {
    GtkWidget *dialog = gtk_box_new(GTK_ORIENTATION_VERTICAL, 10);
    gtk_widget_add_css_class(dialog, "dialog-sheet");

    GtkWidget *head = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 10);
    gtk_widget_add_css_class(head, "dialog-header");

    GtkWidget *btnBack = createIconButton("arrow_back", "dialog-back-btn", 20);
    g_signal_connect_swapped(btnBack, "clicked", G_CALLBACK(+[](SidebarWindow *self) {
        gtk_stack_set_visible_child_name(GTK_STACK(self->mainStack), "main");
    }), this);
    gtk_box_append(GTK_BOX(head), btnBack);

    GtkWidget *title = gtk_label_new("Устройства Bluetooth");
    gtk_widget_add_css_class(title, "dialog-title");
    gtk_widget_set_hexpand(title, TRUE);
    gtk_label_set_xalign(GTK_LABEL(title), 0);
    gtk_box_append(GTK_BOX(head), title);

    btSwitch = gtk_switch_new();
    gtk_widget_set_valign(btSwitch, GTK_ALIGN_CENTER);
    gtk_switch_set_active(GTK_SWITCH(btSwitch), BluetoothManager::isPowered());
    g_signal_connect(btSwitch, "state-set", G_CALLBACK(+[](GtkSwitch*, gboolean state, gpointer user_data) -> gboolean {
        auto *self = static_cast<SidebarWindow*>(user_data);
        BluetoothManager::setPowered(state);
        self->refreshBluetooth();
        return FALSE;
    }), this);
    gtk_box_append(GTK_BOX(head), btSwitch);
    gtk_box_append(GTK_BOX(dialog), head);

    btProgressBar = gtk_progress_bar_new();
    gtk_box_append(GTK_BOX(dialog), btProgressBar);

    GtkWidget *scrolled = gtk_scrolled_window_new();
    gtk_widget_set_vexpand(scrolled, TRUE);
    btListBox = gtk_box_new(GTK_ORIENTATION_VERTICAL, 6);
    gtk_scrolled_window_set_child(GTK_SCROLLED_WINDOW(scrolled), btListBox);
    gtk_box_append(GTK_BOX(dialog), scrolled);

    GtkWidget *bottomRow = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 8);
    GtkWidget *btnSearch = gtk_button_new_with_label("Поиск");
    gtk_widget_add_css_class(btnSearch, "dialog-connect-btn");
    g_signal_connect_swapped(btnSearch, "clicked", G_CALLBACK(+[](SidebarWindow *self) {
        gtk_progress_bar_pulse(GTK_PROGRESS_BAR(self->btProgressBar));
        BluetoothManager::startScan();
        std::thread([self]() {
            g_usleep(2500000);
            g_idle_add(+[](gpointer p) -> gboolean {
                static_cast<SidebarWindow*>(p)->refreshBluetooth();
                return FALSE;
            }, self);
        }).detach();
    }), this);
    gtk_box_append(GTK_BOX(bottomRow), btnSearch);

    GtkWidget *sp2 = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 0);
    gtk_widget_set_hexpand(sp2, TRUE);
    gtk_box_append(GTK_BOX(bottomRow), sp2);

    GtkWidget *btnDone = gtk_button_new_with_label("Готово");
    gtk_widget_add_css_class(btnDone, "btn-action-primary");
    g_signal_connect_swapped(btnDone, "clicked", G_CALLBACK(+[](SidebarWindow *self) {
        gtk_stack_set_visible_child_name(GTK_STACK(self->mainStack), "main");
    }), this);
    gtk_box_append(GTK_BOX(bottomRow), btnDone);

    gtk_box_append(GTK_BOX(dialog), bottomRow);
    return dialog;
}

void SidebarWindow::refreshBluetooth() {
    // Sync switch to real state
    bool btOn = BluetoothManager::isPowered();
    if (btSwitch) gtk_switch_set_active(GTK_SWITCH(btSwitch), btOn);
    if (btOn) gtk_widget_add_css_class(btnBtToggle, "active");
    else gtk_widget_remove_css_class(btnBtToggle, "active");

    GtkWidget *child = gtk_widget_get_first_child(btListBox);
    while (child) {
        GtkWidget *next = gtk_widget_get_next_sibling(child);
        gtk_box_remove(GTK_BOX(btListBox), child);
        child = next;
    }

    std::thread([this]() {
        auto devices = BluetoothManager::getDevices();
        g_idle_add(+[](gpointer data) -> gboolean {
            auto *pair = static_cast<std::pair<SidebarWindow*, std::vector<BluetoothDevice>>*>(data);
            auto *self = pair->first;
            auto devs = pair->second;

            if (devs.empty()) {
                GtkWidget *emp = gtk_label_new("Устройства не найдены");
                gtk_box_append(GTK_BOX(self->btListBox), emp);
            }

            for (const auto &dev : devs) {
                GtkWidget *card = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 8);
                gtk_widget_add_css_class(card, "dialog-list-item");

                GtkWidget *icon = createIconLabel(dev.icon, 20);
                gtk_box_append(GTK_BOX(card), icon);

                GtkWidget *infoBox = gtk_box_new(GTK_ORIENTATION_VERTICAL, 2);
                GtkWidget *name = gtk_label_new(dev.name.c_str());
                gtk_label_set_xalign(GTK_LABEL(name), 0);
                gtk_box_append(GTK_BOX(infoBox), name);

                std::string sub = dev.connected ? "Подключено" : "Сопряжено";
                if (dev.battery >= 0) sub += " • " + std::to_string(dev.battery) + "%";
                GtkWidget *status = gtk_label_new(sub.c_str());
                gtk_label_set_xalign(GTK_LABEL(status), 0);
                gtk_box_append(GTK_BOX(infoBox), status);

                gtk_widget_set_hexpand(infoBox, TRUE);
                gtk_box_append(GTK_BOX(card), infoBox);

                GtkWidget *btn = gtk_button_new_with_label(dev.connected ? "Отключить" : "Подключить");
                gtk_widget_add_css_class(btn, "dialog-connect-btn");

                g_object_set_data_full(G_OBJECT(btn), "mac", g_strdup(dev.mac.c_str()), g_free);
                g_object_set_data(G_OBJECT(btn), "connected", GINT_TO_POINTER(dev.connected ? 1 : 0));
                g_object_set_data(G_OBJECT(btn), "sidebar", self);

                g_signal_connect(btn, "clicked", G_CALLBACK(+[](GtkButton *b, gpointer) {
                    const char *m = (const char*)g_object_get_data(G_OBJECT(b), "mac");
                    int isC = GPOINTER_TO_INT(g_object_get_data(G_OBJECT(b), "connected"));
                    auto *s = static_cast<SidebarWindow*>(g_object_get_data(G_OBJECT(b), "sidebar"));
                    std::string macStr = m ? m : "";

                    std::thread([s, macStr, isC]() {
                        if (isC) BluetoothManager::disconnectDevice(macStr);
                        else BluetoothManager::connectDevice(macStr);
                        g_usleep(800000);
                        g_idle_add(+[](gpointer ptr) -> gboolean {
                            static_cast<SidebarWindow*>(ptr)->refreshBluetooth();
                            return FALSE;
                        }, s);
                    }).detach();
                }), nullptr);

                gtk_box_append(GTK_BOX(card), btn);
                gtk_box_append(GTK_BOX(self->btListBox), card);
            }
            delete pair;
            return FALSE;
        }, new std::pair<SidebarWindow*, std::vector<BluetoothDevice>>(this, devices));
    }).detach();
}

// WifiDialog
GtkWidget* SidebarWindow::buildWifiDialog() {
    GtkWidget *dialog = gtk_box_new(GTK_ORIENTATION_VERTICAL, 10);
    gtk_widget_add_css_class(dialog, "dialog-sheet");

    GtkWidget *head = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 10);
    gtk_widget_add_css_class(head, "dialog-header");

    GtkWidget *btnBack = createIconButton("arrow_back", "dialog-back-btn", 20);
    g_signal_connect_swapped(btnBack, "clicked", G_CALLBACK(+[](SidebarWindow *self) {
        gtk_stack_set_visible_child_name(GTK_STACK(self->mainStack), "main");
    }), this);
    gtk_box_append(GTK_BOX(head), btnBack);

    GtkWidget *title = gtk_label_new("Подключение к Wi-Fi");
    gtk_widget_add_css_class(title, "dialog-title");
    gtk_widget_set_hexpand(title, TRUE);
    gtk_label_set_xalign(GTK_LABEL(title), 0);
    gtk_box_append(GTK_BOX(head), title);

    wifiSwitch = gtk_switch_new();
    gtk_widget_set_valign(wifiSwitch, GTK_ALIGN_CENTER);
    gtk_switch_set_active(GTK_SWITCH(wifiSwitch), WifiManager::isPowered());
    g_signal_connect(wifiSwitch, "state-set", G_CALLBACK(+[](GtkSwitch*, gboolean state, gpointer user_data) -> gboolean {
        auto *self = static_cast<SidebarWindow*>(user_data);
        WifiManager::setPowered(state);
        self->refreshWifi();
        return FALSE;
    }), this);
    gtk_box_append(GTK_BOX(head), wifiSwitch);
    gtk_box_append(GTK_BOX(dialog), head);

    wifiProgressBar = gtk_progress_bar_new();
    gtk_box_append(GTK_BOX(dialog), wifiProgressBar);

    GtkWidget *scrolled = gtk_scrolled_window_new();
    gtk_widget_set_vexpand(scrolled, TRUE);
    wifiListBox = gtk_box_new(GTK_ORIENTATION_VERTICAL, 6);
    gtk_scrolled_window_set_child(GTK_SCROLLED_WINDOW(scrolled), wifiListBox);
    gtk_box_append(GTK_BOX(dialog), scrolled);

    GtkWidget *bottomRow = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 8);
    GtkWidget *btnRefresh = gtk_button_new_with_label("Обновить");
    gtk_widget_add_css_class(btnRefresh, "dialog-connect-btn");
    g_signal_connect_swapped(btnRefresh, "clicked", G_CALLBACK(+[](SidebarWindow *self) {
        gtk_progress_bar_pulse(GTK_PROGRESS_BAR(self->wifiProgressBar));
        WifiManager::rescan();
        std::thread([self]() {
            g_usleep(1500000);
            g_idle_add(+[](gpointer p) -> gboolean {
                static_cast<SidebarWindow*>(p)->refreshWifi();
                return FALSE;
            }, self);
        }).detach();
    }), this);
    gtk_box_append(GTK_BOX(bottomRow), btnRefresh);

    GtkWidget *sp2 = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 0);
    gtk_widget_set_hexpand(sp2, TRUE);
    gtk_box_append(GTK_BOX(bottomRow), sp2);

    GtkWidget *btnDone = gtk_button_new_with_label("Готово");
    gtk_widget_add_css_class(btnDone, "btn-action-primary");
    g_signal_connect_swapped(btnDone, "clicked", G_CALLBACK(+[](SidebarWindow *self) {
        gtk_stack_set_visible_child_name(GTK_STACK(self->mainStack), "main");
    }), this);
    gtk_box_append(GTK_BOX(bottomRow), btnDone);

    gtk_box_append(GTK_BOX(dialog), bottomRow);
    return dialog;
}

void SidebarWindow::refreshWifi() {
    GtkWidget *child = gtk_widget_get_first_child(wifiListBox);
    while (child) {
        GtkWidget *next = gtk_widget_get_next_sibling(child);
        gtk_box_remove(GTK_BOX(wifiListBox), child);
        child = next;
    }

    std::thread([this]() {
        auto networks = WifiManager::getNetworks();
        g_idle_add(+[](gpointer data) -> gboolean {
            auto *pair = static_cast<std::pair<SidebarWindow*, std::vector<WifiNetwork>>*>(data);
            auto *self = pair->first;
            auto nets = pair->second;

            if (nets.empty()) {
                GtkWidget *emp = gtk_label_new("Сети не найдены");
                gtk_box_append(GTK_BOX(self->wifiListBox), emp);
            }

            for (const auto &net : nets) {
                GtkWidget *row = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 8);
                gtk_widget_add_css_class(row, "dialog-list-item");

                GtkWidget *icon = createIconLabel(net.icon, 20);
                gtk_box_append(GTK_BOX(row), icon);

                GtkWidget *infoBox = gtk_box_new(GTK_ORIENTATION_VERTICAL, 2);
                GtkWidget *name = gtk_label_new(net.ssid.c_str());
                gtk_label_set_xalign(GTK_LABEL(name), 0);
                gtk_box_append(GTK_BOX(infoBox), name);

                std::string sub = net.inUse ? "Подключено" : (net.security.empty() ? "Открытая сеть" : net.security);
                GtkWidget *status = gtk_label_new(sub.c_str());
                gtk_label_set_xalign(GTK_LABEL(status), 0);
                gtk_box_append(GTK_BOX(infoBox), status);

                gtk_widget_set_hexpand(infoBox, TRUE);
                gtk_box_append(GTK_BOX(row), infoBox);

                if (!net.inUse) {
                    GtkWidget *btn = gtk_button_new_with_label("Подключить");
                    gtk_widget_add_css_class(btn, "dialog-connect-btn");

                    g_object_set_data_full(G_OBJECT(btn), "ssid", g_strdup(net.ssid.c_str()), g_free);
                    g_object_set_data(G_OBJECT(btn), "secure", GINT_TO_POINTER(net.secure ? 1 : 0));
                    g_object_set_data(G_OBJECT(btn), "sidebar", self);

                    g_signal_connect(btn, "clicked", G_CALLBACK(+[](GtkButton *b, gpointer) {
                        const char *targetSsid = (const char*)g_object_get_data(G_OBJECT(b), "ssid");
                        int isSec = GPOINTER_TO_INT(g_object_get_data(G_OBJECT(b), "secure"));
                        auto *s = static_cast<SidebarWindow*>(g_object_get_data(G_OBJECT(b), "sidebar"));
                        std::string ssidStr = targetSsid ? targetSsid : "";

                        if (!isSec) {
                            std::thread([s, ssidStr]() {
                                WifiManager::connect(ssidStr, "");
                                g_usleep(1500000);
                                g_idle_add(+[](gpointer ptr) -> gboolean {
                                    static_cast<SidebarWindow*>(ptr)->refreshWifi();
                                    return FALSE;
                                }, s);
                            }).detach();
                        } else {
                            std::thread([s, ssidStr]() {
                                std::string passCmd = "rofi -dmenu -password -p 'Пароль для " + ssidStr + ":'";
                                FILE *pipe = popen(passCmd.c_str(), "r");
                                char passBuf[256];
                                std::string pass = "";
                                if (pipe) {
                                    if (fgets(passBuf, sizeof(passBuf), pipe)) {
                                        pass = passBuf;
                                        while (!pass.empty() && (pass.back() == '\n' || pass.back() == '\r')) pass.pop_back();
                                    }
                                    pclose(pipe);
                                }
                                if (!pass.empty()) {
                                    WifiManager::connect(ssidStr, pass);
                                    g_usleep(2000000);
                                    g_idle_add(+[](gpointer ptr) -> gboolean {
                                        static_cast<SidebarWindow*>(ptr)->refreshWifi();
                                        return FALSE;
                                    }, s);
                                }
                            }).detach();
                        }
                    }), nullptr);

                    gtk_box_append(GTK_BOX(row), btn);
                }

                gtk_box_append(GTK_BOX(self->wifiListBox), row);
            }
            delete pair;
            return FALSE;
        }, new std::pair<SidebarWindow*, std::vector<WifiNetwork>>(this, networks));
    }).detach();
}

void SidebarWindow::refreshUptime() {
    std::ifstream f("/proc/uptime");
    if (f.is_open()) {
        double sec = 0;
        if (f >> sec) {
            long total = (long)sec;
            long days = total / 86400;
            long hours = (total % 86400) / 3600;
            long mins = (total % 3600) / 60;
            std::string s = "";
            if (days > 0) s += std::to_string(days) + "d, ";
            if (hours > 0 || days > 0) s += std::to_string(hours) + "h, ";
            s += std::to_string(mins) + "m";
            gtk_label_set_text(GTK_LABEL(uptimeLabel), s.c_str());
        }
    }
}

void SidebarWindow::refreshNotifications() {
    std::thread([this]() {
        char buf[64];
        int count = 0;
        bool dnd = false;
        FILE *pCount = popen("swaync-client -c 2>/dev/null", "r");
        if (pCount) {
            if (fgets(buf, sizeof(buf), pCount)) {
                try { count = std::stoi(buf); } catch (...) {}
            }
            pclose(pCount);
        }
        FILE *pDnd = popen("swaync-client -D 2>/dev/null", "r");
        if (pDnd) {
            if (fgets(buf, sizeof(buf), pDnd)) {
                if (std::string(buf).find("true") != std::string::npos) dnd = true;
            }
            pclose(pDnd);
        }

        g_idle_add(+[](gpointer data) -> gboolean {
            auto *tuple = static_cast<std::tuple<SidebarWindow*, int, bool>*>(data);
            auto *self = std::get<0>(*tuple);
            int c = std::get<1>(*tuple);
            bool d = std::get<2>(*tuple);

            self->currentNotifCount = c;
            self->dndActive = d;

            if (d) gtk_widget_add_css_class(self->btnDnd, "active");
            else gtk_widget_remove_css_class(self->btnDnd, "active");

            if (c <= 0) {
                gtk_label_set_text(GTK_LABEL(self->notifCountLabel), "Уведомлений нет");
                gtk_widget_set_visible(self->notifPlaceholder, TRUE);
                gtk_widget_set_visible(self->notifScrolled, FALSE);
            } else {
                std::string s = std::to_string(c) + " уведомл.";
                gtk_label_set_text(GTK_LABEL(self->notifCountLabel), s.c_str());
                gtk_widget_set_visible(self->notifPlaceholder, FALSE);
                gtk_widget_set_visible(self->notifScrolled, TRUE);

                // Populate notification item card if empty
                GtkWidget *first = gtk_widget_get_first_child(self->notifListBox);
                if (!first) {
                    GtkWidget *card = gtk_box_new(GTK_ORIENTATION_VERTICAL, 2);
                    gtk_widget_add_css_class(card, "notif-item");

                    GtkWidget *top = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 6);
                    GtkWidget *appIco = createIconLabel("crop", 18, false);
                    gtk_widget_add_css_class(appIco, "notif-app-icon");
                    gtk_box_append(GTK_BOX(top), appIco);

                    GtkWidget *appName = gtk_label_new("niri");
                    gtk_widget_add_css_class(appName, "notif-app-title");
                    gtk_box_append(GTK_BOX(top), appName);

                    GtkWidget *sp = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 0);
                    gtk_widget_set_hexpand(sp, TRUE);
                    gtk_box_append(GTK_BOX(top), sp);

                    GtkWidget *timeLbl = gtk_label_new("Now");
                    gtk_widget_add_css_class(timeLbl, "notif-time-label");
                    gtk_box_append(GTK_BOX(top), timeLbl);

                    GtkWidget *badge = gtk_label_new((std::to_string(c) + " ⌄").c_str());
                    gtk_widget_add_css_class(badge, "notif-count-badge");
                    gtk_box_append(GTK_BOX(top), badge);
                    gtk_box_append(GTK_BOX(card), top);

                    GtkWidget *sum = gtk_label_new("Screenshot captured");
                    gtk_widget_add_css_class(sum, "notif-summary");
                    gtk_label_set_xalign(GTK_LABEL(sum), 0);
                    gtk_box_append(GTK_BOX(card), sum);

                    GtkWidget *body = gtk_label_new("You can paste the image from the clipboard.");
                    gtk_widget_add_css_class(body, "notif-body");
                    gtk_label_set_xalign(GTK_LABEL(body), 0);
                    gtk_box_append(GTK_BOX(card), body);

                    gtk_box_append(GTK_BOX(self->notifListBox), card);
                }
            }

            delete tuple;
            return FALSE;
        }, new std::tuple<SidebarWindow*, int, bool>(this, count, dnd));
    }).detach();
}

void SidebarWindow::refreshAll() {
    refreshUptime();
    refreshNotifications();
    updateTimerDisplay();

    // Check wifi power state
    bool wifiOn = WifiManager::isPowered();
    if (wifiOn) {
        gtk_widget_add_css_class(btnWifiToggle, "active");
    } else {
        gtk_widget_remove_css_class(btnWifiToggle, "active");
    }
    if (wifiSwitch) gtk_switch_set_active(GTK_SWITCH(wifiSwitch), wifiOn);

    // Check bluetooth power state
    bool btOn = BluetoothManager::isPowered();
    if (btOn) {
        gtk_widget_add_css_class(btnBtToggle, "active");
    } else {
        gtk_widget_remove_css_class(btnBtToggle, "active");
    }
    if (btSwitch) gtk_switch_set_active(GTK_SWITCH(btSwitch), btOn);
}
