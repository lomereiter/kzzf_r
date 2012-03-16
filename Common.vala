namespace Xmms {
    public string build_path (string filename) {
        unowned string user = GLib.Environment.get_user_name ();
        return "/home/" + user + "/.config/xmms2/" + filename; // FIXME
    }
}
