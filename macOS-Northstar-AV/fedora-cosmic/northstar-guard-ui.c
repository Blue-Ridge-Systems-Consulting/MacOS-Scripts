#include <gtk/gtk.h>
#include <stdlib.h>

static gchar *cli_path(void) {
    return g_build_filename(g_get_home_dir(), ".local", "bin", "northstar-guard", NULL);
}

static void run_cmd(const char *subcommand) {
    gchar *cli = cli_path();
    gchar *cmd = g_strdup_printf("%s %s", cli, subcommand);
    GError *error = NULL;
    if (!g_spawn_command_line_async(cmd, &error) && error) {
        g_warning("Northstar command failed: %s", error->message);
        g_error_free(error);
    }
    g_free(cmd); g_free(cli);
}

static void open_reports(GtkWidget *button, gpointer data) {
    (void)button; (void)data;
    const char *home = g_get_home_dir();
    char *reports = g_build_filename(home, ".local/share/northstar-guard/reports", NULL);
    char *uri = g_filename_to_uri(reports, NULL, NULL);
    g_free(reports);
    if (uri) { gtk_show_uri(NULL, uri, GDK_CURRENT_TIME); g_free(uri); }
}

static void action(GtkWidget *button, gpointer data) {
    (void)button;
    run_cmd((const char *)data);
}

static gboolean refresh_status(gpointer data) {
    GtkLabel *label = GTK_LABEL(data);
    GError *error = NULL; gchar *out = NULL; gchar *err = NULL; gint status = 0;
    gchar *cli = cli_path();
    gchar *argv[] = { cli, (gchar *)"status", NULL };
    if (g_spawn_sync(NULL, argv, NULL, G_SPAWN_SEARCH_PATH, NULL, NULL, &out, &err, &status, &error)) {
        if (out && *out) { g_strchomp(out); gtk_label_set_text(label, out); }
    }
    g_free(out); g_free(err); g_free(cli); if (error) g_error_free(error); return G_SOURCE_CONTINUE;
}

static void activate(GtkApplication *app, gpointer data) {
    (void)data;
    GtkWidget *window = gtk_application_window_new(app);
    gtk_window_set_title(GTK_WINDOW(window), "Northstar Guard");
    gtk_window_set_default_size(GTK_WINDOW(window), 500, 360);
    gtk_window_set_resizable(GTK_WINDOW(window), FALSE);
    GtkWidget *box = gtk_box_new(GTK_ORIENTATION_VERTICAL, 12);
    gtk_widget_set_margin_top(box, 18); gtk_widget_set_margin_bottom(box, 18);
    gtk_widget_set_margin_start(box, 18); gtk_widget_set_margin_end(box, 18);
    gtk_window_set_child(GTK_WINDOW(window), box);
    GtkWidget *title = gtk_label_new(NULL);
    gtk_label_set_markup(GTK_LABEL(title), "<span size='x-large' weight='bold'>Northstar Guard</span>");
    gtk_box_append(GTK_BOX(box), title);
    GtkWidget *sub = gtk_label_new("Lightweight Fedora COSMIC malware monitor"); gtk_box_append(GTK_BOX(box), sub);
    GtkWidget *status = gtk_label_new("Checking monitor status…"); gtk_box_append(GTK_BOX(box), status);
    GtkWidget *grid = gtk_grid_new(); gtk_grid_set_row_spacing(GTK_GRID(grid), 8); gtk_grid_set_column_spacing(GTK_GRID(grid), 8); gtk_box_append(GTK_BOX(box), grid);
    const char *labels[] = {"Start Live Scan", "Stop Live Scan", "Quick Scan", "Full Scan", "Open Reports"};
    const char *commands[] = {"start", "stop", "scan quick", "scan full", NULL};
    for (int i=0;i<5;i++) { GtkWidget *b=gtk_button_new_with_label(labels[i]); gtk_widget_set_hexpand(b, TRUE); if(commands[i]) g_signal_connect(b,"clicked",G_CALLBACK(action),(gpointer)commands[i]); else g_signal_connect(b,"clicked",G_CALLBACK(open_reports),NULL); gtk_grid_attach(GTK_GRID(grid),b,i%2,i/2,1,1); }
    GtkWidget *hint = gtk_label_new("Engines: ClamAV + YARA  •  CPU budget: 12%  •  User-folder monitoring"); gtk_box_append(GTK_BOX(box), hint);
    g_timeout_add_seconds(2, refresh_status, status); refresh_status(status); gtk_window_present(GTK_WINDOW(window));
}

int main(int argc, char **argv) { GtkApplication *app=gtk_application_new("com.owensreo.NorthstarGuard",G_APPLICATION_DEFAULT_FLAGS); g_signal_connect(app,"activate",G_CALLBACK(activate),NULL); int rc=g_application_run(G_APPLICATION(app),argc,argv); g_object_unref(app); return rc; }
