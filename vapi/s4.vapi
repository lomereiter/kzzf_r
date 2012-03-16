[CCode (cheader_filename = "s4.h")]
namespace S4 {
    [Flags]
    [CCode (cprefix = "S4_", has_type_id = false, cname = "s4_open_flag_t")]
    public enum OpenFlags {
        NEW    = 1 << 0,
        EXISTS = 1 << 1,
        MEMORY = 1 << 2
    }

    [Flags]
    [CCode (cprefix = "S4_TRANS_", has_type_id = false, cname = "s4_transaction_flag_t")]
    public enum TransactionFlags {
        READONLY = 1 << 0
    }
    
    [CCode (cname = "s4_errno_t", cprefix = "S4E_", has_type_id = false)]
    public enum Error {
        NOERROR, /**< No error to report */
        EXISTS, /**< Tried to open a database with S4_NEW, but the file already exists */
        NOENT, /**< Tried to open a database with S4_EXISTS, but it did not exist */
        OPEN, /**< fopen failed when trying to open the database. errno has more details */
        MAGIC, /**< Magic number was not correct. Probably not an S4 database */
        VERSION, /**< Version number was incorrect */
        INCONS, /**< Database is inconsistent. */
        LOGOPEN, /**< Could not open log file. See errno for more details */
        LOGREDO, /**< Could not redo changes in the log. Probably corrupted log */
        DEADLOCK, /**< The transaction deadlocked and was aborted */
        EXECUTE, /**< One of the operations in the transaction failed */
        LOGFULL, /**< Not enough room in the log for the transaction. */
        READONLY, /**< Tried to use s4_add or s4_del on a read-only transaction */
    }

    [CCode (cname = "s4_cmp_mode_t", cprefix = "S4_CMP_", has_type_id = false)]
    public enum CompareMode {
        BINARY, /**< Compare the values byte by byte */
        CASELESS, /**< Compare casefolded versions of the strings */
        COLLATE /**< Compare collated keys (taking locale into account) */
    }

    [Compact]
    [CCode (cname = "s4_val_t", copy_function = "s4_val_copy", free_function = "s4_val_free", cprefix = "s4_val_", has_type_id = false)]
    public class Value {
        [CCode (cname = "s4_val_new_string")]
        public Value.from_string (string str);
        [CCode (cname = "s4_val_new_int")]
        public Value.from_int (int32 i);

        public Value copy ();

        [CCode (cname = "s4_val_is_str")]
        public bool is_string ();
        [CCode (cname = "s4_val_is_int")]
        public bool is_int32 ();

        int get_str (string** str);
        public string? get_string () {
            unowned string str = null;
            if (0 == get_str (&str))
                return null;
            return str.dup ();
        }

        int get_int (out int32 i);
        public int32 get_int32 () {
            int32 i;
            if (0 == get_int (out i))
                return -1;
            return i;
        }

        public int cmp (Value v2, CompareMode mode);

        public string to_string () {
            if (is_string ()) 
                return get_string ();
            else
                return get_int32 ().to_string ();
        }

        public GLib.Variant to_glib_variant () {
            if (is_string ()) {
                return new GLib.Variant.string (get_string ());
            } else {
                return new GLib.Variant.int32 (get_int32 ());
            }
        }
    }

    [Compact]
    [CCode (cname="s4_t", has_type_id = false, cprefix="s4_", free_function = "")]
    public class Backend {                                    // FIXME: s4_close can't join sync_thread
       
        [CCode (cname="s4_open")]
        public Backend (string? name, [CCode (array_length = false, array_null_terminated = true)]string[] indices, int flags);

        public void sync ();
        public void get_uuid ([CCode (array_length = false, array_null_terminated = true)] uchar[] out_uuid);
        public string get_uuid_string ();
    }

    public static Error errno ();

    public static void create_uuid ([CCode (array_length = false, array_null_terminated = true)] uchar[] out_uuid);
    
    [Compact]
    [CCode (ref_function = "s4_sourcepref_ref", unref_function = "s4_sourcepref_unref", cname="s4_sourcepref_t", cprefix="s4_sourcepref_", free_function = "")]
    public class SourcePref {
        [CCode (cname="s4_sourcepref_create")]
        public SourcePref ([CCode (array_length = false, array_null_terminated = true)] string[] sourcepref);
        public int get_priority (string src);
    }

    [CCode (cname="s4_filter_type_t", cprefix="S4_FILTER_", has_type_id = false)]
    public enum FilterType {
        EQUAL,
        NOTEQUAL,
        GREATER,
        SMALLER,
        GREATEREQ,
        SMALLEREQ,
        MATCH,
        EXISTS,
        TOKEN,
        CUSTOM
    }

    [CCode (cname = "s4_combine_type_t", cprefix = "S4_COMBINE_", has_type_id = false)]
    public enum CombineType {
        AND,
        OR,
        NOT,
        CUSTOM
    }

    [CCode (cname = "S4_COND_PARENT")]
    public const int COND_PARENT;

    [CCode (cname = "check_function_t")]
    public delegate int CheckFunc (Condition cond);
    [CCode (cname = "filter_function_t", has_target = false)]
    public delegate int FilterFunc (Value val, Condition data);
    [CCode (cname = "combine_function_t")]
    public delegate int CombineFunc (Condition cond, CheckFunc func);
    [CCode (cname = "free_func_t", has_target = false)]
    public delegate void FreeFunc ();

    [Compact]
    [CCode (cname = "s4_condition_t", cprefix = "s4_cond_", ref_function = "s4_cond_ref", unref_function = "s4_cond_unref")]
    public class Condition {
        public Condition.combiner (CombineType type);

        public Condition.custom_combiner (CombineFunc func);

        public Condition.filter (FilterType type, 
                                 string key, 
                                 Value val,
                                 SourcePref? sourcepref, 
                                 CompareMode mode, 
                                 int flags);

        public Condition.custom_filter (FilterFunc func,
										void *funcdata,
                                        FreeFunc? free,
                                        string? key,
                                        SourcePref? sourcepref,
                                        CompareMode mode,
                                        int monotonic,
                                        int flags);

        public bool is_filter ();
        public bool is_combiner ();

        public void add_operand (Condition op);
        public Condition get_operand (int op);

        public FilterType filter_type { 
            [CCode (cname = "s4_cond_get_filter_type")]
            get;
        }

        public CombineType combiner_type {
            [CCode (cname = "s4_cond_get_combiner_type")]
            get;
        }
        
        public int flags {
            [CCode (cname = "s4_cond_get_flags")]
            get;
        }
        
        public string key {
            [CCode (cname = "s4_cond_get_key")]
            get;
        }

        public SourcePref sourcepref {
            [CCode (cname = "s4_cond_get_sourcepref")]
            get;
        }

        public bool is_monotonic ();
        public void update_key (Backend s4);
        public int cmp_mode {
            [CCode (cname = "s4_cond_get_cmp_mode")]
            get;
        }

        public FilterFunc filter_function {
            [CCode (cname = "s4_cond_get_filter_function")]
            get;
        }

        public CombineFunc combine_function {
            [CCode (cname = "s4_cond_get_combine_function")]
            get;
        }

		public void* get_funcdata ();
    }
 
    [CCode (cname = "S4_FETCH_PARENT")]
    public const int FETCH_PARENT;

    [CCode (cname = "S4_FETCH_DATA")]
    public const int FETCH_DATA;

    [Compact]
    [CCode (cname = "s4_fetchspec_t", cprefix = "s4_fetchspec_", ref_function = "s4_fetchspec_ref", unref_function = "s4_fetchspec_unref")]
    public class FetchSpec {
        [CCode (cname = "s4_fetchspec_create")]
        public FetchSpec ();
        public void add (string? key, SourcePref? sourcepref, int flags);
        public int size {
            [CCode (cname = "s4_fetchspec_size")]
            get;
        }
        public string? get_key (int index);
        public SourcePref? get_sourcepref (int index);
        public int get_flags (int index);

        [CCode (cname = "s4_fetchspec_update_key")]
        public static void _update_key (Backend s4, FetchSpec spec);
        public void update_key (Backend s4) {
            _update_key (s4, this);
        }
    }
   
    [Compact]
    [CCode (cname = "s4_result_t", cprefix = "s4_result_")]
    public class Result {
        public unowned Result next {
            [CCode (cname = "s4_result_next")]
            get;
        }
        public string key {
            [CCode (cname = "s4_result_get_key")]
            get;
        }
        public string src {
            [CCode (cname = "s4_result_get_src")]
            get;
        }
        public Value @value {
            [CCode (cname = "s4_result_get_val")]
            get;
        }
    }
   
    [Compact]
    [CCode (cname = "s4_resultrow_t", cprefix = "s4_resultrow_")]
    public class ResultRow {
        [CCode (cname = "s4_resultrow_set_col")]
        public void set_column (int col_no, Result col);
        [CCode (cname = "s4_resultrow_get_col")]
        public bool get_column (int col_no, out unowned Result col);

        public unowned Result? get (int col_no) {
            unowned Result res = null;
            if (!get_column (col_no, out res))
                return null;
            return res;
        }
    }

    [Compact]
    [CCode (cname = "s4_resultset_t", cprefix = "s4_resultset_", ref_function = "s4_resultset_ref", unref_function = "s4_resultset_unref")]
    public class ResultSet {
        [CCode (cname = "s4_resultset_create")]
        public ResultSet (int col_count);
        public void add_row (ResultRow row);
        public bool get_row (int row_no, out unowned ResultRow row);
        public unowned Result? get_result (int row, int col);
        public int colcount {
            [CCode (cname = "s4_resultset_get_colcount")]
            get;
        }
        public int rowcount {
            [CCode (cname = "s4_resultset_get_rowcount")]
            get;
        }

        public int size { get { return rowcount; } }
        public unowned ResultRow? get (int row_no) {
            unowned ResultRow r = null;
            if (!get_row (row_no, out r))
                return null;
            return r;
        }

        public void sort ([CCode (array_length = false, array_null_terminated = true)] int[] order);
        public void shuffle ();
    }
    
    [Compact]
    [CCode (cname = "s4_pattern_t", cprefix = "s4_pattern_", free_function = "s4_pattern_free")]
    public class Pattern {
        [CCode (cname = "s4_pattern_create")]
        public Pattern (int normalize);
        public int match (Value val);
    }
    
    [Compact]
    [CCode (cname = "s4_transaction_t", cprefix = "s4_", free_function = "")]
    public class Transaction {
        public static unowned Transaction begin (Backend s4, int flags);
        public bool commit ();
        public bool abort ();
        public bool add (string key_a, Value val_a,
                        string key_b, Value val_b,
                        string src);
        public bool del (string key_a, Value val_a,
                        string key_b, Value val_b,
                        string src);
        public ResultSet query (FetchSpec fs, Condition cond);
    }

}
