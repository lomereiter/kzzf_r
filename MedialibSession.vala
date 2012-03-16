namespace Xmms {

    public class MedialibSession {
        unowned S4.Transaction trans;
        IMedialib medialib;
        GLib.Variant[] vals;
        
        GLib.HashTable<int32, int32> added;
        GLib.HashTable<int32, int32> updated;
        GLib.HashTable<int32, int32> removed;

        internal MedialibSession.with_flags (IMedialib medialib, S4.TransactionFlags flags) {
            this.medialib = medialib;
            unowned S4.Backend s4 = medialib.database_backend;
            trans = S4.Transaction.begin (s4, flags);
            added = new GLib.HashTable<int32, int32> (null, null);
            updated = new GLib.HashTable<int32, int32> (null, null);
            removed = new GLib.HashTable<int32, int32> (null, null);
            vals = new GLib.Variant[0];
        }

        public MedialibSession (IMedialib medialib) {
            this.with_flags (medialib, 0);
        }

        public MedialibSession.read_only (IMedialib medialib) {
            this.with_flags (medialib, S4.TransactionFlags.READONLY);
        }
        
        public void abort () {
            trans.abort ();
        }

        public bool commit () {
            if (!trans.commit ()) {
                return false;
            }
            
            foreach (var key in added.get_keys ()) {
                medialib.entry_added (key);
                updated.remove (key);
            }
            
            foreach (var key in removed.get_keys ()) {
                medialib.entry_removed (key);
                updated.remove (key);
            }

            foreach (var key in updated.get_keys ()) {
                medialib.entry_updated (key);
            }

            return true;
        }

        public S4.SourcePref source_preferences { 
            get {
                return medialib.source_preferences;
            }
        }

        public S4.ResultSet query (S4.FetchSpec specification, S4.Condition condition) {
            return trans.query (specification, condition);
        }

        public bool set_property (MedialibEntry entry, string key, S4.Value val, string src) {
            var song_id = new S4.Value.from_int (entry);

            string[] sources = { src, null };
            var sp = new S4.SourcePref (sources);

            var cond = new S4.Condition.filter (S4.FilterType.EQUAL, "song_id", song_id,
                                                sp, S4.CompareMode.CASELESS, S4.COND_PARENT);

            var spec = new S4.FetchSpec ();
            spec.add (key, sp, S4.FETCH_DATA);

            S4.ResultSet @set = trans.query (spec, cond);

            unowned S4.Result? res = @set.get_result (0, 0);
            if (res != null) {
                unowned S4.Value old_value = res.value;
                trans.del ("song_id", song_id, key, old_value, src);
            }

            var events = (key == MedialibEntry.PROPERTY_URL) ? added : updated;
            events.insert (entry, entry);

            return trans.add ("song_id", song_id, key, val, src);
        }

        public bool unset_property (MedialibEntry entry, string key, S4.Value val, string src) {
            var events = (key == MedialibEntry.PROPERTY_URL) ? removed : updated;
            events.insert (entry, entry);

            return trans.del ("song_id", new S4.Value.from_int (entry), key, val, src);
        }

        public void track_garbage (GLib.Variant data) {
            vals += data;
        }
    }
}
