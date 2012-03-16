namespace Xmms {
    
    public class Log {
        static string ts_format;
        public static void set_format (string format) {
            ts_format = format;
        }
        
        static int verbosity_level;
        public static void init (int verbosity) {
            verbosity_level = verbosity; 
            GLib.Log.set_handler (null, 
                LogLevelFlags.LEVEL_MASK | LogLevelFlags.FLAG_FATAL,
                (_, log_level, message) => {
                     string level = "??";
                     if (LogLevelFlags.LEVEL_CRITICAL in log_level) {
                         level = " FAIL";
                     } else if (LogLevelFlags.LEVEL_ERROR in log_level) {
                         level = "FATAL";
                     } else if (LogLevelFlags.LEVEL_WARNING in log_level) {
                         level = "ERROR";
                     } else if (LogLevelFlags.LEVEL_MESSAGE in log_level) {
                         level = " INFO";
                         if (verbosity_level < 1)
                             return;
                     } else if (LogLevelFlags.LEVEL_DEBUG in log_level) {
                         level = "DEBUG";
                         if (verbosity_level < 2)
                             return;
                     }

                     // uses localtime_r, so thread-safe
                     var time_now = GLib.Time.local (time_t ()); 

                     string ts = "";
                     if (ts_format != null) {
                         ts = time_now.format (ts_format);
                         ts = ts ?? "";
                     }

                     stdout.printf ("%s%s: %s\n", ts, level, message);
                     stdout.flush ();

                     if (LogLevelFlags.LEVEL_ERROR in log_level) {
                         Posix.exit (Posix.EXIT_FAILURE);
                     }
                });
            info ("Initialized logging system :)");
        }

        public static void debug (string str) {
            GLib.debug (str);
        }
        public static void fatal (string str) {
            GLib.error (str);
        }
        public static void info (string str) {
            GLib.message (str);
        }
        public static void error (string str) {
            GLib.warning (str);
        }
    }
}
