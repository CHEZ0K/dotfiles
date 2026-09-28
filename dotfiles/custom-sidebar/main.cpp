#include "sidebar.hpp"
#include <gtk/gtk.h>
#include <iostream>

static SidebarWindow *g_sidebar = nullptr;

static void init_sidebar(GtkApplication *app) {
    if (!g_sidebar) {
        g_sidebar = new SidebarWindow(app);
        g_application_hold(G_APPLICATION(app));
    }
}


static int on_command_line(GApplication *app, GApplicationCommandLine *cmdline, gpointer) {
    init_sidebar(GTK_APPLICATION(app));
    int argc = 0;
    char **argv = g_application_command_line_get_arguments(cmdline, &argc);
    bool daemon = false;
    for (int i = 1; i < argc; i++) {
        if (argv[i] && (std::string(argv[i]) == "--daemon" || std::string(argv[i]) == "-d")) {
            daemon = true;
            break;
        }
    }
    g_strfreev(argv);
    if (!daemon) {
        g_sidebar->toggle();
    }
    return 0;
}

static void on_activate(GtkApplication *app, gpointer) {
    init_sidebar(app);
    g_sidebar->toggle();
}

int main(int argc, char **argv) {
    GtkApplication *app = gtk_application_new("org.chezok.customsidebar", G_APPLICATION_HANDLES_COMMAND_LINE);
    g_signal_connect(app, "activate", G_CALLBACK(on_activate), NULL);
    g_signal_connect(app, "command-line", G_CALLBACK(on_command_line), NULL);

    int status = g_application_run(G_APPLICATION(app), argc, argv);
    delete g_sidebar;
    g_object_unref(app);
    return status;
}
