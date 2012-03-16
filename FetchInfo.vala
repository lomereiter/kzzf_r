namespace Xmms {
    public class FetchInfo {
        S4.FetchSpec _fetch_spec;
        public S4.FetchSpec fetch_spec {
            get {
                return _fetch_spec;
            }
        }
        GLib.HashTable<void*, GLib.HashTable<string, int?>?> fetch_table;

        public FetchInfo (S4.SourcePref prefs) {
            fetch_table = new GLib.HashTable<void*, GLib.HashTable<string, int?>?> (GLib.direct_hash,
                                                                                    GLib.direct_equal);

            _fetch_spec = new S4.FetchSpec ();
            _fetch_spec.add ("song_id", prefs, S4.FETCH_PARENT);
        }

        public int add_key (void* object, string? key, S4.SourcePref prefs) {
            if (key == "id") {
                return 0;
            }
            
            var table = fetch_table.lookup (object);
            if (table == null) {
                table = new GLib.HashTable<string, int?> (GLib.str_hash, GLib.str_equal);
                fetch_table.insert (object, table);
            }
            
            bool key_is_null = false;
            if (key == null) {
                // TODO: ????
                key = "__NULL__";
                key_is_null = true;
            }

            var index = table.lookup (key);
            if (index == null) {
                index = _fetch_spec.size;
                table.insert (key, index);
                if (key_is_null) 
                    key = null;
                _fetch_spec.add (key, prefs, S4.FETCH_DATA);
            }

            return index;
        }
    }
}
