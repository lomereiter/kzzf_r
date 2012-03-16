namespace Xmms {

    [SimpleType]
    [CCode (has_type_id = false)]
    public struct MedialibEntry : int32 {
        public const string PROPERTY_MIME = "mime";
        public const string PROPERTY_ID = "id";
        public const string PROPERTY_URL = "url";
        public const string PROPERTY_ARTIST = "artist";
        public const string PROPERTY_ALBUM = "album";
        public const string PROPERTY_TITLE = "title";
        public const string PROPERTY_YEAR = "date";
        public const string PROPERTY_TRACKNR = "tracknr";
        public const string PROPERTY_GENRE = "genre";
        public const string PROPERTY_BITRATE = "bitrate";
        public const string PROPERTY_COMMENT = "comment";
        public const string PROPERTY_COMMENT_LANG = "commentlang";
        public const string PROPERTY_DURATION = "duration";
        public const string PROPERTY_CHANNEL = "channel";
        public const string PROPERTY_CHANNELS = "channels";
        public const string PROPERTY_SAMPLE_FMT = "sample_format";
        public const string PROPERTY_SAMPLERATE = "samplerate";
        public const string PROPERTY_LMOD = "lmod";
        public const string PROPERTY_GAIN_TRACK = "gain_track";
        public const string PROPERTY_GAIN_ALBUM = "gain_album";
        public const string PROPERTY_PEAK_TRACK = "peak_track";
        public const string PROPERTY_PEAK_ALBUM = "peak_album";
        public const string PROPERTY_COMPILATION = "compilation";
        public const string PROPERTY_ALBUM_ID = "album_id";
        public const string PROPERTY_ARTIST_ID = "artist_id";
        public const string PROPERTY_TRACK_ID = "track_id";
        public const string PROPERTY_ADDED = "added";
        public const string PROPERTY_BPM = "bpm";
        public const string PROPERTY_LASTSTARTED = "laststarted";
        public const string PROPERTY_SIZE = "size";
        public const string PROPERTY_IS_VBR = "isvbr";
        public const string PROPERTY_SUBTUNES = "subtunes";
        public const string PROPERTY_CHAIN = "chain";
        public const string PROPERTY_TIMESPLAYED = "timesplayed";
        public const string PROPERTY_PARTOFSET = "partofset";
        public const string PROPERTY_PICTURE_FRONT = "picture_front";
        public const string PROPERTY_PICTURE_FRONT_MIME = "picture_front_mime";
        public const string PROPERTY_STARTMS = "startms";
        public const string PROPERTY_STOPMS = "stopms";
        public const string PROPERTY_STATUS = "status";
        public const string PROPERTY_DESCRIPTION = "description";
        public const string PROPERTY_GROUPING = "grouping";
        public const string PROPERTY_PERFORMER = "performer";
        public const string PROPERTY_CONDUCTOR = "conductor";
        public const string PROPERTY_ARRANGER = "arranger";
        public const string PROPERTY_ORIGINAL_ARTIST = "original_artist";
        public const string PROPERTY_ALBUM_ARTIST = "album_artist";
        public const string PROPERTY_PUBLISHER = "publisher";
        public const string PROPERTY_COMPOSER = "composer";
        public const string PROPERTY_ASIN = "asin";
        public const string PROPERTY_COPYRIGHT = "copyright";
        public const string PROPERTY_WEBSITE_ARTIST = "website_artist";
        public const string PROPERTY_WEBSITE_FILE = "website_file";
        public const string PROPERTY_WEBSITE_PUBLISHER = "website_publisher";
        public const string PROPERTY_WEBSITE_COPYRIGHT = "website_copyright";
    }

    public enum MedialibEntryStatus {
        NEW,
        OK,
        RESOLVING,
        NOT_AVAILABLE,
        REHASH
    }

    public interface IMedialib : Object {

        public signal void entry_added (MedialibEntry entry);
        public signal void entry_updated (MedialibEntry entry);
        public signal void entry_removed (MedialibEntry entry);

        internal abstract S4.SourcePref source_preferences { get; }
        internal abstract S4.Backend database_backend { get; }

        public abstract void remove_entry (MedialibEntry entry) throws Xmms.Error;
        public abstract void rehash (MedialibEntry entry) throws Xmms.Error;
    }
    
    public class Medialib : Object, IMedialib {
        const string[] source_pref = { "server", "client/*", "plugin/playlist",
                                       "plugin/id3v2", "plugin/segment", 
                                       "plugin/*", "*", null };
        
        ~Medialib () {
            Log.debug ("Deactivating medialib object.");
        }

        const string SOURCE_SERVER = "server";

        S4.Backend backend;
        S4.SourcePref default_sp;

        public Medialib () {
            const string indices[] = { MedialibEntry.PROPERTY_URL,
                                       MedialibEntry.PROPERTY_STATUS,
                                       null };
            
            var path = Xmms.build_path ("medialib.s4");
            var cfg = ConfigProperty.register ("medialib.path", path);
            var medialib_path = cfg.get_string ();
            backend = database_open (medialib_path, indices);
            default_sp = new S4.SourcePref (source_pref);
        }

        public S4.SourcePref source_preferences {
            get {
                return default_sp;
            }
        }

        public S4.Backend database_backend {
            get {
                return backend;
            }
        }
        
        static string database_converted_name (string conf_path) {
            var dirname = GLib.Path.get_dirname (conf_path);
            var filename = GLib.Path.get_basename (conf_path);

            var dot = filename.last_index_of (".");
            if (dot != -1) 
                filename = filename[0 : dot];

            var converted_name = @"$filename.s4";
            return GLib.Path.build_path (GLib.Path.DIR_SEPARATOR_S,
                                         dirname,
                                         converted_name,
                                         null);
        }

        static S4.Backend database_convert (string database_name, string[] indices) {
            ConfigProperty cfg = Config.lookup ("collection.directory");
            var coll_conf = cfg.get_string ();

            cfg = Config.lookup ("sqlite2s4.path");
            var conv_conf = cfg.get_string ();

            var new_name = database_converted_name (database_name);

            var cmdline = string.join (" ", conv_conf, database_name, 
                                       new_name, coll_conf, null);
            
            Log.info ("Attempting to migrate database to new format.");

            int exit_status;
            try {
                if (!GLib.Process.spawn_command_line_sync (cmdline, null, null, out exit_status) 
                        || exit_status != 0) 
                {
                    Log.fatal (@"Could not run \"$cmdline\", try to run it manually");
                }
            } catch (GLib.SpawnError e) {
                Log.fatal (@"Could not run \"cmdline\": $(e.message)");
            }
            
            var s4 = new S4.Backend (new_name, indices, 0);
            if (s4 == null) {
                Log.fatal ("Could not open the S4 database");
            }

            Log.info ("Migration successful.");

            var obsolete_name = @"$database_name.obsolete";
            GLib.FileUtils.rename (database_name, obsolete_name);

            Config.lookup ("medialib.path").value = new_name;

            return s4;
        }

        static S4.Backend database_open (string database_name, string[] indices) 
            requires (database_name != null) 
        {
            int flags = (database_name == "memory://") ? S4.OpenFlags.MEMORY : 0;
            
            var s4 = new S4.Backend (database_name, indices, flags);
            if (s4 != null) {
                return s4;
            }

            if (S4.errno () != S4.Error.MAGIC) {
                Log.fatal ("Could not open the S4 database");
            }

            return database_convert (database_name, indices);
        }

        public string uuid {
            owned get {
                return backend.get_uuid_string ();
            }
        }
        

        // FIXME: what the fuck is all this shit and why doesn't it use QueryVisitor?!!!
        static S4.ResultSet filter (MedialibSession session,
                                    string filter_key, S4.Value filter_val,
                                    int filter_flags, S4.SourcePref? source_pref,
                                    string? fetch_key, int fetch_flags) 
        {
            var cond = new S4.Condition.filter (S4.FilterType.EQUAL, filter_key, filter_val,
                                                source_pref, S4.CompareMode.CASELESS, filter_flags);
            
            var spec = new S4.FetchSpec ();
            spec.add (fetch_key, source_pref, fetch_flags);
            return session.query (spec, cond);
        }

        static S4.Value? entry_property_get (MedialibSession session, MedialibEntry entry,
                                             string property) 
            requires (property != null)
        {
            var song_id = new S4.Value.from_int (entry);
            if (property == MedialibEntry.PROPERTY_ID) {
                return song_id;
            }

            var source_pref = session.source_preferences;
            var @set = filter (session, "song_id", song_id, S4.COND_PARENT,
                               source_pref, property, S4.FETCH_DATA);

            unowned S4.Result? res = @set.get_result (0, 0);
            if (res != null) {
                return res.value.copy ();
            }
            return null;
        }

        public static GLib.Variant? entry_property_get_value (MedialibSession session,
                                                             MedialibEntry id_num,
                                                             string property)
        {
            var prop = entry_property_get (session, id_num, property);
            if (prop == null)
                return null;

            return prop.to_glib_variant ();
        }

        public static string? entry_property_get_str (MedialibSession session, 
                                                      MedialibEntry entry, string property)
        {
            var val = entry_property_get (session, entry, property);
            if (val != null)
                return val.get_string ();
            return null; 
        }

        public static int32 entry_property_get_int32 (MedialibSession session, 
                                                      MedialibEntry entry, string property)
        {
            var val = entry_property_get (session, entry, property);
            if (val != null)
                return val.get_int32 ();
            return -1;
        }

        public static bool entry_property_set_int32 (MedialibSession session, MedialibEntry entry,
                                                     string property, int32 @value)
        {
            return entry_property_set_int32_source (session, entry, property, @value, "server");
        }
        
        public static bool entry_property_set_int32_source (MedialibSession session, MedialibEntry id_num,
                                                            string property, int32 @value, string source)
        {
            GLib.return_val_if_fail (property == null, false);
            var prop = new S4.Value.from_int (@value);
            return session.set_property (id_num, property, prop, source);
        }

        public static bool entry_property_set_str (MedialibSession session, MedialibEntry entry,
                                                   string property, string @value) 
        {
            return entry_property_set_str_source (session, entry, property, @value, "server");
        }

        public static bool entry_property_set_str_source (MedialibSession session, MedialibEntry id_num,
                                                          string property, string @value, string source)
        {
            GLib.return_val_if_fail (property == null, false);

            if (@value != null && !@value.validate ()) {
                Log.debug (@"OOOOOPS! Trying to set property $property to a NON UTF-8 string ($value) I will deny that!");
                return false;
            }

            return session.set_property (id_num, property, new S4.Value.from_string (@value), source);
        }
       
        internal static bool check_id (MedialibSession session, MedialibEntry entry) {
            return null != entry_property_get_value (session, entry, MedialibEntry.PROPERTY_URL);
        }

        internal static void entry_remove (MedialibSession session, MedialibEntry entry) {
            var @set = filter (session, "song_id", new S4.Value.from_int (entry),
                               S4.COND_PARENT, null, null, S4.FETCH_DATA); 
            
            foreach (unowned S4.ResultRow row in @set) {
                for (unowned S4.Result? res = row[0]; res != null; res = res.next) {
                    session.unset_property (entry, res.key, res.value, res.src);
                }
            }
        }

        public void remove_entry (MedialibEntry entry) throws Xmms.Error {
            MedialibSession session = null;
            do {
                session = new MedialibSession (this);
                if (check_id (session, entry))
                    entry_remove (session, entry);
                else
                    throw new Xmms.Error.NO_ENTRY ("No such entry");
            } while (!session.commit ());
        }

        static bool entry_attribute_is_derived (string source, string key) {
            if (source == Medialib.SOURCE_SERVER) {
                switch (key) {
                    case MedialibEntry.PROPERTY_URL:
                    case MedialibEntry.PROPERTY_ADDED:
                    case MedialibEntry.PROPERTY_STATUS:
                    case MedialibEntry.PROPERTY_LMOD:
                    case MedialibEntry.PROPERTY_LASTSTARTED:
                        return false;
                    default:
                        return true;
                }
            } else if (source.has_prefix ("plugin/")) {
                return source != "plugin/playlist"; 
            }
            return false;
        }

        internal static void entry_cleanup (MedialibSession session, MedialibEntry entry) {
            var @set = filter (session, "song_id", new S4.Value.from_int (entry),
                               S4.COND_PARENT, null, null, S4.FETCH_DATA);
            foreach (unowned S4.ResultRow row in @set) {
                for (unowned S4.Result? res = row[0]; res != null; res = res.next) {
                    if (entry_attribute_is_derived (res.src, res.key))
                        session.unset_property (entry, res.key, res.value, res.src);
                }
            }
        }

        internal static void entry_status_set (MedialibSession session, MedialibEntry entry,
                                      MedialibEntryStatus status)
        {
            entry_property_set_int32_source (session, entry, MedialibEntry.PROPERTY_STATUS,
                                             status, "server"); // TODO: hardcoded server id?
        }
        
        public void rehash (MedialibEntry entry) throws Xmms.Error {
            MedialibSession session = null;
            do {
                session = new MedialibSession (this);
                if (check_id (session, entry)) {
                    entry_status_set (session, entry, MedialibEntryStatus.REHASH);
                } else if (entry == 0) {
                    var sourcepref = session.source_preferences;
                    var status = new S4.Value.from_int (MedialibEntryStatus.OK);
                    var @set = filter (session, MedialibEntry.PROPERTY_STATUS,
                                       status, 0, sourcepref, "song_id", S4.FETCH_PARENT);
                    foreach (unowned S4.ResultRow row in @set) {
                        for (unowned S4.Result? res = row[0]; res != null; res = res.next) {
                            entry_status_set (session, res.value.get_int32 (), 
                                              MedialibEntryStatus.REHASH);
                        }
                    }
                } else {
                    throw new Xmms.Error.NO_ENTRY ("No such entry");
                }
            } while (!session.commit ());
        }
       
        /*public Collection add_recursive (string path) throws Xmms.Error {
            var entries = new Collection.id_list ();
            GLib.return_val_if_fail (path, ref entries);
            process_dir (ref entries, path);
            return entries;
        }*/
    }
}
