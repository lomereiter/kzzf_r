void main () {
    Xmms.Log.init (2);
    Xmms.Config.init ("/home/lomereiter/.config/xmms2/xmms2.conf");

    var medialib = new Xmms.Medialib ();
    var session = new Xmms.MedialibSession (medialib);

    // --------------------------------------------------------------------

    var query = new Xmms.Universe ().equal_filter (
                    "artist", new S4.Value.from_string ("Metallica")
                ).or (new Xmms.Universe ().equal_filter (
                             "artist", new S4.Value.from_string ("Nirvana")
                      )
                ).greater_equal_filter (
                    "bitrate", new S4.Value.from_int (256000)
                ).limit (10);

    stdout.printf ("%s\n", Xmms.serialize_collection (query)); 

    string[] fields = { "artist", "album", "bitrate", "title", "year" };
    var fi = new Xmms.FetchInfo (session.source_preferences);
    foreach (var f in fields)
        fi.add_key (null, f, session.source_preferences);

    var results = Xmms.medialib_query_recursive (session, query, fi);

    foreach (unowned S4.ResultRow row in results) {
        for (var i = 0; i < results.colcount; i++) {
            unowned S4.Result? result = row[i];
            if (result == null)
                continue;
            stdout.printf (@"$(result.key): $(result.value)\n");
        }
        stdout.printf ("\n");
    }
}
