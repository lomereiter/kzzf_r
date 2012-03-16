namespace Xmms {

    public class ConfigProperty : GLib.Object {
        string _name;
        public string name { get { return _name; } }

        public ConfigProperty (string name) {
            _name = name;
        }

        string _value = null;

        [CCode (notify=false)]
        public string @value {
            get {
                return _value; 
            }
            set {
                if (_value == null || _value != value) {
                    _value = value;
                    changed (_value);
                    Config.instance.value_changed (_name, _value);
                    Config.save ();
                }
            }
        }

        public static ConfigProperty register (string path, string default_value) {
            return Config.register_property (path, default_value);
        }

        public signal void changed (string @value);

        public string get_string () { return _value; }
        public int get_int () { return int.parse (_value); }
        public double get_double () { return double.parse (_value); }
    }

    public class Config : GLib.Object {

        public static const int VERSION = 2;

        public signal void value_changed (string name, string @value);

        internal Config () {
            states = new GLib.Queue<State> ();
            sections = new GLib.Queue<string> ();
            properties = create_tree ();
        }

        internal static Config global_config = null;
        
        public static Config instance {
            get {
                lock (global_config) {
                    if (global_config == null) {
                        global_config = new Config ();
                    }
                }
                return global_config;
            }
        }

        public static void init (string filename) {
            instance.filename = filename;
            instance.version = 0;
            instance.load (filename);
        }

        internal enum State { INVALID, START, SECTION, PROPERTY }

        GLib.Queue<State> states;
        GLib.Queue<string> sections;
        internal GLib.Tree<string, ConfigProperty> properties;

        public static ConfigProperty? lookup (string path) {
            ConfigProperty? prop;
            lock (global_config) {
                prop = instance.properties.lookup (path);
            }
            return prop;
        }

        public string lookup_get_string (string key) throws Xmms.Error {
            var prop = lookup (key);
            if (prop == null) {
                throw new Xmms.Error.NO_ENTRY ("Trying to get non-existent property");
            }
            return prop.get_string ();
        }

        public static bool save () 
            requires (global_config != null)
        {
            if (instance.filename == "memory://" || 
                instance.is_parsing) {
                return false;
            }

            var fs = GLib.FileStream.open (instance.filename, "w");

            if (fs == null) {
                Log.error (@"Couldn't open $(instance.filename) for writing.");
                return false;
            }

            fs.printf ("<?xml version=\"1.0\"?>\n<xmms version=\"%i\">\n", VERSION);
            
            var indent = new GLib.StringBuilder ("\t");
            uint indent_level = 1;
            string? prev_key = null;

            instance.properties.foreach ((k, p) => {
                string key = (string)k;
                ConfigProperty prop = (ConfigProperty)p;

                int start = 0;

                if (prev_key != null) {

                    int i = 0;
                    int dots = 0;
                    var max = int.min (key.length, prev_key.length);

                    for ( ; i < max; i++) {
                        if (key[i] == '.') 
                            start = i + 1;
                        if (key[i] != prev_key[i])
                            break;
                    }

                    for ( ; i < prev_key.length; i++) {
                        if (prev_key[i] == '.')
                            dots++;
                    }

                    if (dots > 0) 
                        prev_key = null;

                    for ( ; dots > 0; dots--) {
                        indent.truncate (--indent_level);
                        fs.printf ("%s</section>\n", indent.str);
                    }
                }
               
                string[] sections = key.substring (start).split (".");
                int len = sections.length;
                string propname = sections[len - 1];
                foreach (var section in sections[0 : (len - 1)]) {
                    fs.printf ("%s<section name=\"%s\">\n", indent.str, section);
                    indent_level++;
                    indent.append_c ('\t');
                }
                
                prev_key = key;

                fs.printf ("%s<property name=\"%s\">%s</property>\n",
                           indent.str, propname, prop.get_string ());

                return (int)false;
            });

            while (indent_level > 1) {
                indent.truncate (--indent_level);
                fs.printf ("%s</section>\n", indent.str);
            }

            fs.puts ("</xmms>\n");
            return true;
        }

        /* ----------------------- internal logic -------------------------------- */
        bool is_parsing;
        bool parserr;

        string value_name;
        int version;
        string filename;

        State get_current_state (string name) {
            var state = State.INVALID;
            switch (name) {
                case "xmms":
                    state = State.START; break;
                case "section":
                    state = State.SECTION; break;
                case "property":
                    state = State.PROPERTY; break;
                default:
                    break;
            }
            return state;
        }

        string? lookup_attribute (string[] names, string[] values, string needle) {
            var len = int.min (names.length, values.length);
            for (var i = 0; i < len; i++) 
                if (names[i] == needle) 
                    return values[i];
            return null;
        }

        void parse_start (GLib.MarkupParseContext context, string name,
                          string[] attr_names, string[] attr_values) 
            throws GLib.MarkupError 
        {
            var state = get_current_state (name);
            states.push_head (state);
            
            switch (state) {
                case State.INVALID:
                    throw new GLib.MarkupError.UNKNOWN_ELEMENT (@"Unknown element '$name'");
                case State.START:
                    string? attr = lookup_attribute (attr_names, attr_values, "version"); 
                    if (attr != null) {
                        version = (attr == "0.02") ? 2 : int.parse (attr);
                    }
                    return;
                default:
                    break;
            }

            string? _name = lookup_attribute (attr_names, attr_values, "name");
            if (_name == null) {
                throw new GLib.MarkupError.INVALID_CONTENT ("Attribute 'name' missing");
            }

            switch (state) {
                case State.SECTION:
                    sections.push_head (_name); break;
                case State.PROPERTY:
                    value_name = _name; break;
                default:
                    break;
            }
        }

        void parse_end (GLib.MarkupParseContext context, string name) 
            throws GLib.MarkupError 
        {
            var state = states.pop_head ();
            switch (state) {
                case State.SECTION:
                    sections.pop_head (); break;
                case State.PROPERTY:
                    value_name = null; break;
                default:
                    break;
            }
        }

        void parse_text (GLib.MarkupParseContext context, string text) 
            throws GLib.MarkupError
        {
            var state = states.peek_head ();
            if (state != State.PROPERTY) 
                return;
            
            string key = "";
            unowned GLib.List<string> tail = sections.tail;
            while (tail != null) {
                key += tail.data + ".";
                tail = tail.prev;
            }
            key += value_name;
           
            var prop = new ConfigProperty (key);
            prop.value = text;
            properties.replace (key, prop);
        }

        void load (string filename) {
            GLib.MarkupParser parser = {
                parse_start,
                parse_end,
                parse_text,
                null, null
            };

            if (filename == "memory://") {
                return;
            }
            
            string contents = "";
            if (GLib.FileUtils.test (filename, GLib.FileTest.EXISTS)) {
                try {
                    if (!GLib.FileUtils.get_contents (filename, out contents)) {
                        Log.info ("No configfile specified, using default values.");
                        return;
                    }
                } catch (GLib.FileError e) {
                    Log.info ("Failed to read config file: $(e.message)");
                    return;
                }
            }

            is_parsing = true;

            var context = new GLib.MarkupParseContext (parser, 0, this, null);     
            try {
                context.parse (contents, -1);
            } catch (GLib.MarkupError e) {
                Log.error (@"Cannot parse config file: $(e.message)");
                parserr = true;
            }

            if (Config.VERSION > version) {
                clear ();
            }
            
            is_parsing = false;

            if (parserr) {
                Log.info ("The config file could not be parsed, reverting to default configuration..");
                clear ();
            }
        }

        void clear () {
            properties = create_tree ();
            version = Config.VERSION;
            value_name = null;
        }

        static GLib.Tree<string, ConfigProperty> create_tree () {
            return new GLib.Tree<string, ConfigProperty> (GLib.strcmp);
        }

        internal static ConfigProperty register_property (string path, string default_value) {
            ConfigProperty prop;
            lock (Config.global_config) {
                prop = Config.instance.properties.lookup (path);
                if (prop == null) {
                    prop = new ConfigProperty (path);
                    prop.value = default_value;
                    Config.instance.properties.replace (prop.name, prop);
                }
            }
            return prop;
        }
       
    }
}
