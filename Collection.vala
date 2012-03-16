namespace Xmms {

    public interface ICollectionVisitor : Object {
        internal abstract void visit_universe (Universe u);

        internal abstract void visit_intersection (IntersectionOperator op);
        internal abstract void visit_union (UnionOperator op);
        internal abstract void visit_complement (ComplementOperator op);
        
        internal abstract void visit_filter (FilterOperator op);
        internal abstract void visit_limit_operator (LimitOperator op);
    }

    public abstract class Collection : Object {
        public abstract bool has_order ();
        public abstract void accept (ICollectionVisitor v);

        // ------------------------------------------------
        // convenience methods

        public Collection and (Collection other) {
            return new IntersectionOperator ({this, other});
        }

        public Collection or (Collection other) {
            return new UnionOperator ({this, other});
        }

        public Collection complement () {
            return new ComplementOperator (this);
        }

        public Collection equal_filter (string field, S4.Value val) {
            return new EqualOperator (this, field, val);
        }

        public Collection not_equal_filter (string field, S4.Value val) {
            return new NotEqualOperator (this, field, val);
        }

        public Collection match_filter (string field, S4.Value val) {
            return new MatchOperator (this, field, val);
        }
        
        public Collection token_filter (string field, S4.Value val) {
            return new MatchOperator (this, field, val);
        }

        public Collection greater_equal_filter (string field, S4.Value val) {
            return new GreaterEqualOperator (this, field, val);
        }

        public Collection smaller_equal_filter (string field, S4.Value val) {
            return new SmallerEqualOperator (this, field, val);
        }

        public Collection greater_filter (string field, S4.Value val) {
            return new GreaterOperator (this, field, val);
        }

        public Collection smaller_filter (string field, S4.Value val) {
            return new SmallerOperator (this, field, val);
        }

        public Collection limit (int32 length, int32 start=0) {
            return new LimitOperator (this, length, start);
        }
    }

    public class Universe : Collection {
        public override bool has_order () {
            return true;
        }
        public override void accept (ICollectionVisitor v) {
            v.visit_universe (this);
        }
    }

    public class LimitOperator : Collection {
        public int32 start { get; construct; }
        public int32 length { get; construct; }
        public Collection operand { get; construct; }
        public override bool has_order () {
            return true;
        }
        public override void accept (ICollectionVisitor v) {
            v.visit_limit_operator (this);
        }
        public LimitOperator (Collection operand, int32 length, int32 start=0) {
            Object (operand: operand, start: start, length: length);
        }
    }

    public abstract class SetOperator : Collection {}

    public enum FilterOperatorType {
        ID,
        VALUE
    }

    public abstract class FilterOperator : Collection {

        public Collection operand { get; construct; }

        public override void accept (ICollectionVisitor v) {
            v.visit_filter (this);
        }

        internal string? _field = null;
        public string? field {
            get {
                if (operator_type == FilterOperatorType.ID)
                    return "song_id";
                else 
                    return _field;
            }
            internal set { 
                _field = value;
            }
        }

        public S4.Value? _value = null;
        public S4.Value? @value { 
            get {
                return _value;
            }
            set {
                _value = value.copy ();
            }
        }

        public FilterOperatorType operator_type { 
            get {
                return FilterOperatorType.VALUE;
            }
        }
        
        public int32 flags { 
            get {
                if (operator_type == FilterOperatorType.ID)
                    return S4.COND_PARENT;
                return 0;
            }
        }

        public override bool has_order () {
            return true;
        }
        
        public abstract S4.FilterType get_filter_type ();

        internal S4.CompareMode? _mode = null;
        public S4.CompareMode compare_mode {
            get {
                if (_mode == null) {
                    return default_compare_mode ();
                }
                return _mode;
            }
            set {
                _mode = value;
            }
        }

        internal virtual S4.CompareMode default_compare_mode () {
            return S4.CompareMode.CASELESS;
        }

        public S4.SourcePref? source_preferences { get; construct; }
    }

    public abstract class ListOperator : Collection {
    }

    // --------------  Set operators ----------------

    public class IntersectionOperator : SetOperator {
        public Collection[] operands;

        public IntersectionOperator (Collection[] operands) 
            requires (operands.length != 0) 
        {
            this.operands = operands;
        }

        public override bool has_order () {
            return operands[0].has_order ();
        }

        public override void accept (ICollectionVisitor v) {
            v.visit_intersection (this);
        }
    }

    public class UnionOperator : SetOperator {
        public Collection[] operands;

        public UnionOperator (Collection[] operands) 
            requires (operands.length != 0)
        {
            this.operands = operands;
        }

        public override bool has_order () {
            foreach (var op in operands)
                if (!op.has_order ()) 
                    return false;
            return true;
        }

        public override void accept (ICollectionVisitor v) {
            v.visit_union (this);
        }
    }

    public class ComplementOperator : SetOperator {
        public Collection operand;

        public ComplementOperator (Collection operand) { 
            this.operand = operand; 
        }

        public override bool has_order () {
            return false;
        }

        public override void accept (ICollectionVisitor v) {
            v.visit_complement (this);
        }
    }

    // ------------- Filter operators ------------

    public class HasOperator : FilterOperator {
        public override S4.FilterType get_filter_type () {
            return S4.FilterType.EXISTS;
        }
        public HasOperator (Collection operand, string field) {
            Object (operand: operand, field: field);
        }
    }
   
    public class MatchOperator : FilterOperator {
        public override S4.FilterType get_filter_type () {
            return S4.FilterType.MATCH;
        }
        public MatchOperator (Collection operand, string field, S4.Value @value) {
            Object (operand: operand, field: field, @value: @value);
        }
    }

    public class TokenOperator : FilterOperator {
        public override S4.FilterType get_filter_type () {
            return S4.FilterType.TOKEN;
        }
        public TokenOperator (Collection operand, string field, S4.Value @value) {
            Object (operand: operand, field: field, @value: @value);
        }
    }

    public class EqualOperator : FilterOperator {
        public override S4.FilterType get_filter_type () {
            return S4.FilterType.EQUAL;
        }
        public EqualOperator (Collection operand, string field, S4.Value @value) {
            Object (operand: operand, field: field, @value: @value);
        }
    }

    public class NotEqualOperator : FilterOperator {
        public override S4.FilterType get_filter_type () {
            return S4.FilterType.NOTEQUAL;
        }
        public NotEqualOperator (Collection operand, string field, S4.Value @value) {
            Object (operand: operand, field: field, @value: @value);
        }
    }

    public abstract class CollatingFilterOperator : FilterOperator {
        internal override S4.CompareMode default_compare_mode () {
            return S4.CompareMode.COLLATE;
        }
    }

    public class GreaterEqualOperator : CollatingFilterOperator {
        public override S4.FilterType get_filter_type () {
            return S4.FilterType.GREATEREQ;
        }
        public GreaterEqualOperator (Collection operand, string field, S4.Value @value) {
            Object (operand: operand, field: field, @value: @value);
        }
    }

    public class SmallerEqualOperator : CollatingFilterOperator {
        public override S4.FilterType get_filter_type () {
            return S4.FilterType.SMALLEREQ;
        }
        public SmallerEqualOperator (Collection operand, string field, S4.Value @value) {
            Object (operand: operand, field: field, @value: @value);
        }
    }

    public class GreaterOperator : CollatingFilterOperator {
        public override S4.FilterType get_filter_type () {
            return S4.FilterType.GREATER;
        }
        public GreaterOperator (Collection operand, string field, S4.Value @value) {
            Object (operand: operand, field: field, @value: @value);
        }
    }

    public class SmallerOperator : CollatingFilterOperator {
        public override S4.FilterType get_filter_type () {
            return S4.FilterType.SMALLER;
        }
        public SmallerOperator (Collection operand, string field, S4.Value @value) {
            Object (operand: operand, field: field, @value: @value);
        }
    }

    // --------------- List operators -------------------

}
