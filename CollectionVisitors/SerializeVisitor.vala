namespace Xmms {
    internal class SerializeVisitor : Object, ICollectionVisitor {
        
        GLib.DataOutputStream stream;
        
        uint indent = 0;

        public SerializeVisitor (GLib.DataOutputStream stream) {
            this.stream = stream;
        }
       
        void _ (string str) {
            try {
                for (var i = 0; i < indent; i++)
                    stream.put_byte ('\t');
                stream.put_string (str);
                stream.put_byte ('\n');
            } catch (GLib.IOError e) {
                Log.error (@"Collection serialization error: $(e.message)");
            }
        }

        public void visit_collection (Collection coll) {
            _ (@"<collection type=\"$(coll.get_type ().name ())\">");
            ++indent;
            coll.accept (this);
            --indent;
            _ ( "</collection>");
        }

        void visit_universe (Universe u) {
        }

        void visit_operands (Collection[] operands) {
            _ ("<operands>");
            ++indent;
            foreach (var op in operands) {
                visit_collection (op);
            }
            --indent;
            _ ("</operands>");
        }

        void visit_intersection (IntersectionOperator op) {
            visit_operands (op.operands); 
        }

        void visit_union (UnionOperator op) {
            visit_operands (op.operands); 
        }

        void visit_complement (ComplementOperator op) {
            visit_collection (op.operand);
        }
        
        void visit_filter (FilterOperator op) {
            if (op.value == null) {
                _ (@"<field name=\"$(op.field)\"/>");
            } else {
                var type = op.value.is_int32 () ? "int32" : "string";
                _ (@"<field name=\"$(op.field)\" type=\"$type\" value=\"$(op.value)\"/>");
            }
            visit_collection (op.operand);
        }

        void visit_limit_operator (LimitOperator op) {
            _ (@"<length>$(op.length)</length>");
            _ (@"<start>$(op.start)</start>");
            visit_collection (op.operand);
        }

    }

    internal string serialize_collection (Collection coll) {
        var memory_stream = new GLib.MemoryOutputStream (null, realloc, free);
        var stream = new GLib.DataOutputStream (memory_stream);
        var visitor = new SerializeVisitor (stream);
        visitor.visit_collection (coll);
        return (string)(memory_stream.get_data ());
    }
}
