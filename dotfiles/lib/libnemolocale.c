#define _GNU_SOURCE
#include <dlfcn.h>
#include <string.h>
#include <stdlib.h>
#include <stdio.h>
#include <errno.h>
#include <gtk/gtk.h>
#include <gio/gio.h>
#include <libnemo-extension/nemo-file-info.h>

__attribute__((constructor))
static void libnemolocale_init(void) {
    // Unset LD_PRELOAD so child processes (like glycin-thumbnailer) never inherit it!
    unsetenv("LD_PRELOAD");
}

typedef char *(*bindtextdomain_fn)(const char *, const char *);

char *bindtextdomain(const char *domainname, const char *dirname) {
    static bindtextdomain_fn real_bind = NULL;
    if (!real_bind) {
        real_bind = (bindtextdomain_fn)dlsym(RTLD_NEXT, "bindtextdomain");
    }
    if (!program_invocation_short_name || strcmp(program_invocation_short_name, "nemo") != 0) {
        return real_bind(domainname, dirname);
    }
    const char *home = getenv("HOME");
    if (home && domainname && (strncmp(domainname, "nemo", 4) == 0)) {
        static char custom_dir[1024];
        snprintf(custom_dir, sizeof(custom_dir), "%s/.local/share/locale", home);
        return real_bind(domainname, custom_dir);
    }
    return real_bind(domainname, dirname);
}

/* ==================== DEBUG LOGGING ==================== */
static void debug_log(const char *format, ...) {
    FILE *f = fopen("/tmp/libnemolocale.log", "a");
    if (f) {
        va_list args;
        va_start(args, format);
        vfprintf(f, format, args);
        va_end(args);
        fclose(f);
    }
}

/* ==================== DYNAMIC CSS RELOADER ==================== */

static GtkCssProvider *dynamic_provider = NULL;
static char css_path[1024] = {0};
static guint debounce_timer_id = 0;

static gboolean do_reload_css(gpointer user_data) {
    debounce_timer_id = 0;
    GdkScreen *screen = gdk_screen_get_default();
    if (!screen) return G_SOURCE_REMOVE;

    if (dynamic_provider) {
        gtk_style_context_remove_provider_for_screen(screen, GTK_STYLE_PROVIDER(dynamic_provider));
        g_object_unref(dynamic_provider);
        dynamic_provider = NULL;
    }

    dynamic_provider = gtk_css_provider_new();
    gtk_css_provider_load_from_path(dynamic_provider, css_path, NULL);
    gtk_style_context_add_provider_for_screen(
        screen,
        GTK_STYLE_PROVIDER(dynamic_provider),
        GTK_STYLE_PROVIDER_PRIORITY_USER + 100
    );
    gtk_style_context_reset_widgets(screen);

    GtkIconTheme *icons = gtk_icon_theme_get_default();
    if (icons) {
        gtk_icon_theme_rescan_if_needed(icons);
    }
    return G_SOURCE_REMOVE;
}

static void on_css_file_changed(GFileMonitor *monitor, GFile *file, GFile *other_file,
                                GFileMonitorEvent event_type, gpointer user_data) {
    if (debounce_timer_id != 0) {
        g_source_remove(debounce_timer_id);
    }
    debounce_timer_id = g_timeout_add(60, do_reload_css, NULL);
}

/* ==================== NEMO VIEW VTABLE STUB ==================== */

typedef struct {
    GtkScrolledWindowClass parent_class;
    void (* clear) (void *view);
    void (* begin_file_changes) (void *view);
    void (* add_file) (void *view, void *file, void *directory);
    void (* remove_file) (void *view, void *file, void *directory);
    void (* file_changed) (void *view, void *file, void *directory);
    void (* end_file_changes) (void *view);
    void (* begin_loading) (void *view);
    void (* end_loading) (void *view, gboolean all_files_seen);
    void (* load_error) (void *view, GError *error);
    void (* reset_to_defaults) (void *view);
    char * (* get_backing_uri) (void *view);
    GList * (* get_selection) (void *view);
    GList * (* peek_selection) (void *view);
    gint (* get_selection_count) (void *view);
} NemoViewClassStub;

/* ==================== SIDEBAR INFO PANEL ==================== */

typedef struct {
    GtkWidget *panel_box;
    GtkWidget *icon_image;
    GtkWidget *name_label;
    GtkWidget *type_label;
    GtkWidget *count_label;
    GtkWidget *size_label;
    GtkWidget *date_label;
    GtkWidget *created_label;
    GtkWidget *path_label;
    char last_uri[1024];
} SidebarInfoPanel;

static SidebarInfoPanel *create_sidebar_info_panel(void) {
    SidebarInfoPanel *panel = g_new0(SidebarInfoPanel, 1);

    panel->panel_box = gtk_box_new(GTK_ORIENTATION_VERTICAL, 5);
    gtk_widget_set_name(panel->panel_box, "nemo-sidebar-info-panel");
    gtk_style_context_add_class(gtk_widget_get_style_context(panel->panel_box), "nemo-sidebar-info-panel");

    // Header: icon + name + type
    GtkWidget *header_box = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 8);
    panel->icon_image = gtk_image_new_from_icon_name("folder", GTK_ICON_SIZE_DND);
    gtk_widget_set_size_request(panel->icon_image, 36, 36);
    gtk_box_pack_start(GTK_BOX(header_box), panel->icon_image, FALSE, FALSE, 0);

    GtkWidget *name_vbox = gtk_box_new(GTK_ORIENTATION_VERTICAL, 2);
    panel->name_label = gtk_label_new("—");
    gtk_label_set_xalign(GTK_LABEL(panel->name_label), 0.0);
    gtk_label_set_ellipsize(GTK_LABEL(panel->name_label), PANGO_ELLIPSIZE_END);
    gtk_box_pack_start(GTK_BOX(name_vbox), panel->name_label, FALSE, FALSE, 0);

    panel->type_label = gtk_label_new("");
    gtk_label_set_xalign(GTK_LABEL(panel->type_label), 0.0);
    gtk_label_set_ellipsize(GTK_LABEL(panel->type_label), PANGO_ELLIPSIZE_END);
    gtk_style_context_add_class(gtk_widget_get_style_context(panel->type_label), "dim-label");
    gtk_box_pack_start(GTK_BOX(name_vbox), panel->type_label, FALSE, FALSE, 0);

    gtk_box_pack_start(GTK_BOX(header_box), name_vbox, TRUE, TRUE, 0);
    gtk_box_pack_start(GTK_BOX(panel->panel_box), header_box, FALSE, FALSE, 2);

    // Separator line
    GtkWidget *sep = gtk_separator_new(GTK_ORIENTATION_HORIZONTAL);
    gtk_box_pack_start(GTK_BOX(panel->panel_box), sep, FALSE, FALSE, 2);

    // Details labels
    panel->count_label = gtk_label_new("");
    gtk_label_set_xalign(GTK_LABEL(panel->count_label), 0.0);
    gtk_label_set_ellipsize(GTK_LABEL(panel->count_label), PANGO_ELLIPSIZE_END);
    gtk_box_pack_start(GTK_BOX(panel->panel_box), panel->count_label, FALSE, FALSE, 0);

    panel->size_label = gtk_label_new("");
    gtk_label_set_xalign(GTK_LABEL(panel->size_label), 0.0);
    gtk_label_set_ellipsize(GTK_LABEL(panel->size_label), PANGO_ELLIPSIZE_END);
    gtk_box_pack_start(GTK_BOX(panel->panel_box), panel->size_label, FALSE, FALSE, 0);

    panel->date_label = gtk_label_new("");
    gtk_label_set_xalign(GTK_LABEL(panel->date_label), 0.0);
    gtk_label_set_ellipsize(GTK_LABEL(panel->date_label), PANGO_ELLIPSIZE_END);
    gtk_box_pack_start(GTK_BOX(panel->panel_box), panel->date_label, FALSE, FALSE, 0);

    panel->created_label = gtk_label_new("");
    gtk_label_set_xalign(GTK_LABEL(panel->created_label), 0.0);
    gtk_label_set_ellipsize(GTK_LABEL(panel->created_label), PANGO_ELLIPSIZE_END);
    gtk_box_pack_start(GTK_BOX(panel->panel_box), panel->created_label, FALSE, FALSE, 0);

    panel->path_label = gtk_label_new("");
    gtk_label_set_xalign(GTK_LABEL(panel->path_label), 0.0);
    gtk_label_set_ellipsize(GTK_LABEL(panel->path_label), PANGO_ELLIPSIZE_END);
    gtk_box_pack_start(GTK_BOX(panel->panel_box), panel->path_label, FALSE, FALSE, 0);

    return panel;
}

static void free_sidebar_info_panel(gpointer data) {
    SidebarInfoPanel *panel = (SidebarInfoPanel *) data;
    if (panel) {
        g_free(panel);
    }
}

static void update_info_for_item(SidebarInfoPanel *panel, const char *name, const char *path,
                                gboolean is_dir, const char *mime, const char *size_str, const char *date_str) {
    if (!panel || !name) return;
    if (!GTK_IS_LABEL(panel->name_label)) return;

    // 1. Name label
    char *escaped_name = g_markup_escape_text(name, -1);
    char *name_markup = g_strdup_printf("<span weight=\"bold\" size=\"11000\">%s</span>", escaped_name);
    gtk_label_set_markup(GTK_LABEL(panel->name_label), name_markup);
    g_free(name_markup);
    g_free(escaped_name);

    // 2. Icon & Type label
    if (is_dir) {
        if (GTK_IS_IMAGE(panel->icon_image))
            gtk_image_set_from_icon_name(GTK_IMAGE(panel->icon_image), "folder", GTK_ICON_SIZE_DND);
        if (GTK_IS_LABEL(panel->type_label))
            gtk_label_set_text(GTK_LABEL(panel->type_label), "Папка с файлами");
    } else {
        if (GTK_IS_IMAGE(panel->icon_image))
            gtk_image_set_from_icon_name(GTK_IMAGE(panel->icon_image), "text-x-generic", GTK_ICON_SIZE_DND);
        if (GTK_IS_LABEL(panel->type_label))
            gtk_label_set_text(GTK_LABEL(panel->type_label), (mime && *mime) ? mime : "Файл");
    }

    // 3. Count label (for directories)
    if (is_dir && path && *path) {
        GFile *dir_file = g_file_new_for_path(path);
        GFileEnumerator *enumerator = g_file_enumerate_children(dir_file, "standard::name,standard::type", G_FILE_QUERY_INFO_NONE, NULL, NULL);
        if (enumerator) {
            int files_count = 0;
            int dirs_count = 0;
            GFileInfo *child;
            while ((child = g_file_enumerator_next_file(enumerator, NULL, NULL)) != NULL) {
                if (g_file_info_get_file_type(child) == G_FILE_TYPE_DIRECTORY)
                    dirs_count++;
                else
                    files_count++;
                g_object_unref(child);
            }
            g_object_unref(enumerator);
            char *count_txt = g_strdup_printf("Элементов: %d (%d файл., %d папок)", files_count + dirs_count, files_count, dirs_count);
            if (GTK_IS_LABEL(panel->count_label)) {
                gtk_label_set_text(GTK_LABEL(panel->count_label), count_txt);
                gtk_widget_show(panel->count_label);
            }
            g_free(count_txt);
        } else {
            if (GTK_IS_LABEL(panel->count_label)) {
                gtk_label_set_text(GTK_LABEL(panel->count_label), "Элементов: —");
                gtk_widget_show(panel->count_label);
            }
        }
        g_object_unref(dir_file);
    } else {
        if (GTK_IS_LABEL(panel->count_label)) {
            gtk_label_set_text(GTK_LABEL(panel->count_label), "");
            gtk_widget_hide(panel->count_label);
        }
    }

    // 4. Query rich details: size, format description, modified time, created time
    if (path && *path) {
        GFile *f = g_file_new_for_path(path);
        GFileInfo *fi = g_file_query_info(f, "standard::size,standard::content-type,time::modified,time::created", G_FILE_QUERY_INFO_NONE, NULL, NULL);
        if (fi) {
            // Type / format description
            const char *content_type = g_file_info_get_content_type(fi);
            if (content_type && GTK_IS_LABEL(panel->type_label)) {
                char *desc = g_content_type_get_description(content_type);
                if (desc) {
                    gtk_label_set_text(GTK_LABEL(panel->type_label), desc);
                    g_free(desc);
                }
            }

            // Size
            if (size_str && *size_str) {
                char *size_txt = g_strdup_printf("Размер: %s", size_str);
                if (GTK_IS_LABEL(panel->size_label)) {
                    gtk_label_set_text(GTK_LABEL(panel->size_label), size_txt);
                    gtk_widget_show(panel->size_label);
                }
                g_free(size_txt);
            } else {
                goffset sz = g_file_info_get_size(fi);
                char *sz_fmt = g_format_size(sz);
                char *size_txt = g_strdup_printf("Размер: %s", sz_fmt);
                if (GTK_IS_LABEL(panel->size_label)) {
                    gtk_label_set_text(GTK_LABEL(panel->size_label), size_txt);
                    gtk_widget_show(panel->size_label);
                }
                g_free(sz_fmt);
                g_free(size_txt);
            }

            // Modified date
            GDateTime *dt_mod = g_file_info_get_modification_date_time(fi);
            if (dt_mod) {
                char *dt_str = g_date_time_format(dt_mod, "%d.%m.%Y %H:%M");
                char *date_txt = g_strdup_printf("Изменён: %s", dt_str);
                if (GTK_IS_LABEL(panel->date_label)) {
                    gtk_label_set_text(GTK_LABEL(panel->date_label), date_txt);
                    gtk_widget_show(panel->date_label);
                }
                g_free(dt_str);
                g_free(date_txt);
                g_date_time_unref(dt_mod);
            } else if (date_str && *date_str && GTK_IS_LABEL(panel->date_label)) {
                char *date_txt = g_strdup_printf("Изменён: %s", date_str);
                gtk_label_set_text(GTK_LABEL(panel->date_label), date_txt);
                gtk_widget_show(panel->date_label);
                g_free(date_txt);
            }

            // Created date
            GDateTime *dt_cr = g_file_info_get_creation_date_time(fi);
            if (dt_cr) {
                char *dt_str = g_date_time_format(dt_cr, "%d.%m.%Y %H:%M");
                char *cr_txt = g_strdup_printf("Создан: %s", dt_str);
                if (GTK_IS_LABEL(panel->created_label)) {
                    gtk_label_set_text(GTK_LABEL(panel->created_label), cr_txt);
                    gtk_widget_show(panel->created_label);
                }
                g_free(dt_str);
                g_free(cr_txt);
                g_date_time_unref(dt_cr);
            } else if (GTK_IS_LABEL(panel->created_label)) {
                gtk_label_set_text(GTK_LABEL(panel->created_label), "");
                gtk_widget_hide(panel->created_label);
            }

            g_object_unref(fi);
        }
        g_object_unref(f);
    } else {
        if (size_str && *size_str && GTK_IS_LABEL(panel->size_label)) {
            char *size_txt = g_strdup_printf("Размер: %s", size_str);
            gtk_label_set_text(GTK_LABEL(panel->size_label), size_txt);
            gtk_widget_show(panel->size_label);
            g_free(size_txt);
        }
        if (date_str && *date_str && GTK_IS_LABEL(panel->date_label)) {
            char *date_txt = g_strdup_printf("Изменён: %s", date_str);
            gtk_label_set_text(GTK_LABEL(panel->date_label), date_txt);
            gtk_widget_show(panel->date_label);
            g_free(date_txt);
        }
        if (GTK_IS_LABEL(panel->created_label)) {
            gtk_label_set_text(GTK_LABEL(panel->created_label), "");
            gtk_widget_hide(panel->created_label);
        }
    }

    // 6. Path label
    if (path && *path && GTK_IS_LABEL(panel->path_label)) {
        const char *home = getenv("HOME");
        char *display_path = NULL;
        if (home && g_str_has_prefix(path, home)) {
            display_path = g_strdup_printf("~%s", path + strlen(home));
        } else {
            display_path = g_strdup(path);
        }
        char *path_txt = g_strdup_printf("Путь: %s", display_path);
        gtk_label_set_text(GTK_LABEL(panel->path_label), path_txt);
        gtk_widget_set_tooltip_text(panel->path_label, path);
        g_free(display_path);
        g_free(path_txt);
        gtk_widget_show(panel->path_label);
    } else if (GTK_IS_LABEL(panel->path_label)) {
        gtk_label_set_text(GTK_LABEL(panel->path_label), "");
        gtk_widget_hide(panel->path_label);
    }
}

static void update_sidebar_info_panel(SidebarInfoPanel *panel, GtkWidget *view, GtkWidget *window) {
    if (!panel) return;

    if (!view) {
        const char *title = gtk_window_get_title(GTK_WINDOW(window));
        if (title && (!panel->last_uri[0] || strcmp(panel->last_uri, title) != 0)) {
            strncpy(panel->last_uri, title, sizeof(panel->last_uri) - 1);
            update_info_for_item(panel, title, NULL, TRUE, NULL, NULL, NULL);
        }
        return;
    }

    static int logged_view = 0;
    if (!logged_view) {
        logged_view = 1;
        debug_log("[libnemolocale] view found: %s\n", view ? G_OBJECT_TYPE_NAME(view) : "NULL");
    }

    NemoViewClassStub *klass = (NemoViewClassStub *) G_OBJECT_GET_CLASS(view);
    GList *selection = (klass && klass->get_selection) ? klass->get_selection(view) : NULL;

    if (selection != NULL) {
        NemoFileInfo *first = (NemoFileInfo *) selection->data;
        char *name = nemo_file_info_get_name(first);
        char *uri = nemo_file_info_get_uri(first);
        gboolean is_dir = nemo_file_info_is_directory(first);
        char *mime = nemo_file_info_get_mime_type(first);
        GFile *loc = nemo_file_info_get_location(first);
        char *path = loc ? g_file_get_path(loc) : NULL;
        char *size_str = nemo_file_info_get_string_attribute(first, "size");
        char *date_str = nemo_file_info_get_string_attribute(first, "date_modified");

        if (uri && strcmp(panel->last_uri, uri) != 0) {
            strncpy(panel->last_uri, uri, sizeof(panel->last_uri) - 1);
            update_info_for_item(panel, name, path, is_dir, mime, size_str, date_str);
        }

        if (name) g_free(name);
        if (uri) g_free(uri);
        if (mime) g_free(mime);
        if (size_str) g_free(size_str);
        if (date_str) g_free(date_str);
        if (path) g_free(path);
        if (loc) g_object_unref(loc);

        g_list_free_full(selection, g_object_unref);
    } else {
        // Nothing selected: show info for current directory
        char *backing_uri = (klass && klass->get_backing_uri) ? klass->get_backing_uri(view) : NULL;
        static int logged_backing = 0;
        if (!logged_backing) {
            logged_backing = 1;
            debug_log("[libnemolocale] backing_uri: %s\n", backing_uri ? backing_uri : "NULL");
        }
        if (backing_uri) {
            if (strcmp(panel->last_uri, backing_uri) != 0) {
                strncpy(panel->last_uri, backing_uri, sizeof(panel->last_uri) - 1);
                GFile *bloc = g_file_new_for_uri(backing_uri);
                char *bpath = bloc ? g_file_get_path(bloc) : NULL;
                char *bname = bpath ? g_path_get_basename(bpath) : NULL;
                update_info_for_item(panel, bname ? bname : "Текущая папка", bpath, TRUE, NULL, NULL, NULL);
                if (bname) g_free(bname);
                if (bpath) g_free(bpath);
                if (bloc) g_object_unref(bloc);
            }
            g_free(backing_uri);
        }
    }
}

/* ==================== WIDGET TREE TRAVERSAL ==================== */

static void sanitize_nemo_window(GtkWidget *widget) {
    if (!widget) return;
    const char *type_name = G_OBJECT_TYPE_NAME(widget);

    // 1. Hide Tree/Places buttons in Statusbar
    if (GTK_IS_BUTTON(widget)) {
        GtkWidget *image = gtk_button_get_image(GTK_BUTTON(widget));
        if (image && GTK_IS_IMAGE(image)) {
            const gchar *icon_name = NULL;
            gtk_image_get_icon_name(GTK_IMAGE(image), &icon_name, NULL);
            if (icon_name && (strstr(icon_name, "places") || strstr(icon_name, "tree"))) {
                gtk_widget_set_no_show_all(widget, TRUE);
                gtk_widget_hide(widget);
            }
        }
        const gchar *tooltip = gtk_widget_get_tooltip_text(widget);
        if (tooltip && (strstr(tooltip, "Places") || strstr(tooltip, "Treeview") || strstr(tooltip, "Места") || strstr(tooltip, "Дерево"))) {
            gtk_widget_set_no_show_all(widget, TRUE);
            gtk_widget_hide(widget);
        }
    }

    // 3. Hide breadcrumb/text toggle button if rendered
    if (GTK_IS_TOGGLE_BUTTON(widget)) {
        const gchar *tooltip = gtk_widget_get_tooltip_text(widget);
        if (tooltip && (strstr(tooltip, "Toggle") || strstr(tooltip, "Location") || strstr(tooltip, "Переключ") || strstr(tooltip, "строк"))) {
            gtk_widget_set_no_show_all(widget, TRUE);
            gtk_widget_hide(widget);
        }
    }

    if (GTK_IS_CONTAINER(widget)) {
        GList *children = gtk_container_get_children(GTK_CONTAINER(widget));
        for (GList *l = children; l != NULL; l = l->next) {
            sanitize_nemo_window(GTK_WIDGET(l->data));
        }
        g_list_free(children);
    }
}

static void find_sidebar_box(GtkWidget *widget, GtkWidget **out_sidebar) {
    if (!widget || *out_sidebar) return;
    const char *type_name = G_OBJECT_TYPE_NAME(widget);
    if (type_name && (strstr(type_name, "NemoPlacesSidebar") || strstr(type_name, "PlacesSidebar") || strstr(type_name, "TreeSidebar"))) {
        GtkWidget *p = gtk_widget_get_parent(widget);
        while (p != NULL && !GTK_IS_PANED(p) && !GTK_IS_WINDOW(p)) {
            if (GTK_IS_BOX(p)) {
                *out_sidebar = p;
                return;
            }
            p = gtk_widget_get_parent(p);
        }
    }
    if (GTK_IS_CONTAINER(widget)) {
        GList *children = gtk_container_get_children(GTK_CONTAINER(widget));
        for (GList *l = children; l != NULL; l = l->next) {
            find_sidebar_box(GTK_WIDGET(l->data), out_sidebar);
            if (*out_sidebar) break;
        }
        g_list_free(children);
    }
}

static void find_active_view(GtkWidget *widget, GtkWidget **out_view) {
    if (!widget || *out_view) return;
    GType view_type = g_type_from_name("NemoView");
    if (view_type != G_TYPE_INVALID && g_type_is_a(G_OBJECT_TYPE(widget), view_type)) {
        if (gtk_widget_get_visible(widget)) {
            *out_view = widget;
            return;
        }
    }
    if (GTK_IS_CONTAINER(widget)) {
        GList *children = gtk_container_get_children(GTK_CONTAINER(widget));
        for (GList *l = children; l != NULL; l = l->next) {
            find_active_view(GTK_WIDGET(l->data), out_view);
            if (*out_view) break;
        }
        g_list_free(children);
    }
}

static void find_places_tree_view(GtkWidget *widget, GtkWidget **out_tv) {
    if (!widget || *out_tv) return;
    const char *type_name = G_OBJECT_TYPE_NAME(widget);
    if (type_name && (strstr(type_name, "NemoPlacesSidebar") || strstr(type_name, "PlacesSidebar"))) {
        if (GTK_IS_BIN(widget)) {
            GtkWidget *child = gtk_bin_get_child(GTK_BIN(widget));
            if (child && GTK_IS_TREE_VIEW(child)) {
                *out_tv = child;
                return;
            }
        }
    }
    if (GTK_IS_CONTAINER(widget)) {
        GList *children = gtk_container_get_children(GTK_CONTAINER(widget));
        for (GList *l = children; l != NULL; l = l->next) {
            find_places_tree_view(GTK_WIDGET(l->data), out_tv);
            if (*out_tv) break;
        }
        g_list_free(children);
    }
}

static gboolean custom_places_sidebar_visible_func(GtkTreeModel *model,
                                                   GtkTreeIter  *iter,
                                                   gpointer      data)
{
    int section_type = -1;
    int row_type = -1;
    char *uri = NULL;
    char *name = NULL;
    char *heading = NULL;

    gtk_tree_model_get(model, iter,
                       14 /* PLACES_SIDEBAR_COLUMN_SECTION_TYPE */, &section_type,
                       0  /* PLACES_SIDEBAR_COLUMN_ROW_TYPE */, &row_type,
                       1  /* PLACES_SIDEBAR_COLUMN_URI */, &uri,
                       5  /* PLACES_SIDEBAR_COLUMN_NAME */, &name,
                       15 /* PLACES_SIDEBAR_COLUMN_HEADING_TEXT */, &heading,
                       -1);

    // 1. Hide Network completely (section 4, or network uri, or network name)
    if (section_type == 4 /* SECTION_NETWORK */) {
        if (uri) g_free(uri);
        if (name) g_free(name);
        if (heading) g_free(heading);
        return FALSE;
    }
    if (uri && (g_str_has_prefix(uri, "network:") || strstr(uri, "network:///"))) {
        if (uri) g_free(uri);
        if (name) g_free(name);
        if (heading) g_free(heading);
        return FALSE;
    }
    if (name && (g_ascii_strcasecmp(name, "Network") == 0 || g_ascii_strcasecmp(name, "Сеть") == 0)) {
        if (uri) g_free(uri);
        if (name) g_free(name);
        if (heading) g_free(heading);
        return FALSE;
    }

    // 2. Hide Desktop ("Рабочий стол")
    if (uri && (g_str_has_suffix(uri, "/Desktop") || g_str_has_suffix(uri, "/Рабочий стол") ||
                strstr(uri, "/Desktop/") || strstr(uri, "/Рабочий стол/"))) {
        if (uri) g_free(uri);
        if (name) g_free(name);
        if (heading) g_free(heading);
        return FALSE;
    }
    if (name && (g_ascii_strcasecmp(name, "Desktop") == 0 || g_ascii_strcasecmp(name, "Рабочий стол") == 0)) {
        if (uri) g_free(uri);
        if (name) g_free(name);
        if (heading) g_free(heading);
        return FALSE;
    }

    // 3. Hide header "Мой компьютер" / "Компьютер"
    if (row_type == 4 /* PLACES_HEADING */ && section_type == 0 /* SECTION_COMPUTER */) {
        if (uri) g_free(uri);
        if (name) g_free(name);
        if (heading) g_free(heading);
        return FALSE;
    }
    if (row_type == 4 /* PLACES_HEADING */ && heading &&
        (strstr(heading, "компьютер") || strstr(heading, "Компьютер") || strstr(heading, "Computer") || strstr(heading, "computer"))) {
        if (uri) g_free(uri);
        if (name) g_free(name);
        if (heading) g_free(heading);
        return FALSE;
    }

    if (uri) g_free(uri);
    if (name) g_free(name);
    if (heading) g_free(heading);
    return TRUE;
}

void gtk_tree_model_filter_set_visible_func(GtkTreeModelFilter *filter_model,
                                            GtkTreeModelFilterVisibleFunc func,
                                            gpointer data,
                                            GDestroyNotify destroy)
{
    static void (*real_set_visible_func)(GtkTreeModelFilter *, GtkTreeModelFilterVisibleFunc, gpointer, GDestroyNotify) = NULL;
    if (!real_set_visible_func) {
        real_set_visible_func = (void (*)(GtkTreeModelFilter *, GtkTreeModelFilterVisibleFunc, gpointer, GDestroyNotify))dlsym(RTLD_NEXT, "gtk_tree_model_filter_set_visible_func");
    }

    if (!program_invocation_short_name || strcmp(program_invocation_short_name, "nemo") != 0) {
        real_set_visible_func(filter_model, func, data, destroy);
        return;
    }

    if (data && G_IS_OBJECT(data)) {
        const char *tname = G_OBJECT_TYPE_NAME(data);
        if (tname && strstr(tname, "NemoPlacesSidebar")) {
            debug_log("[libnemolocale] Intercepted gtk_tree_model_filter_set_visible_func for NemoPlacesSidebar!\n");
            real_set_visible_func(filter_model, custom_places_sidebar_visible_func, data, destroy);
            return;
        }
    }

    real_set_visible_func(filter_model, func, data, destroy);
}

/* Periodic tick to ensure clean state and update sidebar info panel */
static gboolean nemo_window_monitor_tick(gpointer user_data) {
    GList *toplevels = gtk_window_list_toplevels();
    for (GList *l = toplevels; l != NULL; l = l->next) {
        GtkWidget *win = GTK_WIDGET(l->data);
        if (!GTK_IS_WINDOW(win)) continue;
        const char *type_name = G_OBJECT_TYPE_NAME(win);
        if (!type_name || strstr(type_name, "NemoWindow") == NULL) continue;

        static int logged = 0;
        if (!logged) {
            logged = 1;
            debug_log("[libnemolocale] Found NemoWindow of type: %s\n", type_name);
        }

        // 1. Sanitize controls
        sanitize_nemo_window(win);

        // 2. Flatten places tree (remove expander arrows)
        GtkWidget *places_tv = NULL;
        find_places_tree_view(win, &places_tv);
        if (places_tv && GTK_IS_TREE_VIEW(places_tv)) {
            gtk_tree_view_set_show_expanders(GTK_TREE_VIEW(places_tv), FALSE);
        }

        // 3. Attach or retrieve sidebar info panel
        SidebarInfoPanel *panel = (SidebarInfoPanel *) g_object_get_data(G_OBJECT(win), "sidebar_info_panel");
        if (panel && (!GTK_IS_WIDGET(panel->panel_box) || !GTK_IS_LABEL(panel->name_label))) {
            g_object_set_data(G_OBJECT(win), "sidebar_info_panel", NULL);
            panel = NULL;
        }
        if (!panel) {
            GtkWidget *sidebar = NULL;
            find_sidebar_box(win, &sidebar);
            if (sidebar && GTK_IS_BOX(sidebar)) {
                debug_log("[libnemolocale] Found sidebar GtkBox! Attaching info panel...\n");
                panel = create_sidebar_info_panel();
                gtk_box_pack_end(GTK_BOX(sidebar), panel->panel_box, FALSE, FALSE, 0);
                gtk_widget_show_all(panel->panel_box);
                g_object_set_data_full(G_OBJECT(win), "sidebar_info_panel", panel, free_sidebar_info_panel);
            }
        }

        // 4. Update info panel with currently selected item or folder
        if (panel) {
            GtkWidget *view = NULL;
            find_active_view(win, &view);
            update_sidebar_info_panel(panel, view, win);
        }
    }
    g_list_free(toplevels);
    return G_SOURCE_CONTINUE;
}

/* ==================== INITIALIZATION ==================== */

static gboolean init_css_monitor_idle(gpointer user_data) {
    const char *home = getenv("HOME");
    if (!home) return G_SOURCE_REMOVE;
    snprintf(css_path, sizeof(css_path), "%s/.config/gtk-3.0/gtk.css", home);

    GdkScreen *screen = gdk_screen_get_default();
    if (!screen) return G_SOURCE_CONTINUE;

    GtkSettings *settings = gtk_settings_get_default();
    if (settings) {
        g_object_set(settings,
                     "gtk-tooltip-timeout", 150,
                     "gtk-tooltip-browse-timeout", 60,
                     NULL);
    }

    dynamic_provider = gtk_css_provider_new();
    gtk_css_provider_load_from_path(dynamic_provider, css_path, NULL);
    gtk_style_context_add_provider_for_screen(
        screen,
        GTK_STYLE_PROVIDER(dynamic_provider),
        GTK_STYLE_PROVIDER_PRIORITY_USER + 100
    );
    gtk_style_context_reset_widgets(screen);

    GFile *gfile = g_file_new_for_path(css_path);
    GFileMonitor *monitor = g_file_monitor_file(gfile, G_FILE_MONITOR_NONE, NULL, NULL);
    if (monitor) {
        g_signal_connect(monitor, "changed", G_CALLBACK(on_css_file_changed), NULL);
    }
    g_object_unref(gfile);

    // Start 150ms periodic monitor for UI sanitization and info panel updates
    g_timeout_add(150, nemo_window_monitor_tick, NULL);

    return G_SOURCE_REMOVE;
}

static void setup_dynamic_css_monitor(void) {
    static int initialized = 0;
    if (initialized) return;
    initialized = 1;
    g_idle_add(init_css_monitor_idle, NULL);
}

int g_application_run(GApplication *application, int argc, char **argv) {
    static int (*real_run)(GApplication *, int, char **) = NULL;
    if (!real_run) {
        real_run = (int (*)(GApplication *, int, char **))dlsym(RTLD_NEXT, "g_application_run");
    }
    if (!program_invocation_short_name || strcmp(program_invocation_short_name, "nemo") != 0) {
        return real_run(application, argc, argv);
    }
    setup_dynamic_css_monitor();
    return real_run(application, argc, argv);
}
