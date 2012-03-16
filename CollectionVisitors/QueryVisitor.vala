namespace Xmms {

    internal S4.ResultSet medialib_query_recursive (MedialibSession session,
                                                    Collection coll,
                                                    FetchInfo fetch)
    {
        var qv = new QueryVisitor (session, coll, fetch, null); 
        coll.accept (qv);
        
        var ret = session.query (fetch.fetch_spec, qv.get_condition ());
//        return medialib_result_sort (ret, fetch, order);
        return ret;
    }

    // TODO
    //S4.ResultSet medialib_result_sort (S4.ResultSet @set, FetchInfo fetch_info, 

    internal class QueryVisitor : Object, ICollectionVisitor {
        MedialibSession session;
        Collection coll;
        FetchInfo fetch;

        S4.Condition condition; // stores the resulting condition

        public S4.Condition get_condition () {
            return condition;
        }

        Ordering[]? order;

        public QueryVisitor (MedialibSession session, Collection coll, 
                             FetchInfo fetch, Ordering[]? order) 
        {
            this.session = session;
            this.coll = coll;
            this.fetch = fetch;
            this.order = order; // TODO: currently unused
        }

        void visit_universe (Universe u) {
            condition = new S4.Condition.custom_filter ((val, cond) => { return 0; }, 
                                                        null, null,
                                                        "song_id", null,
                                                        S4.CompareMode.BINARY, 0,
                                                        S4.COND_PARENT);
        }

        void visit_limit_operator (LimitOperator op) {
            var stop = op.start + op.length;
            var @set = Xmms.medialib_query_recursive (session, op.operand, fetch);
            GLib.HashTable<int32, int32?>* id_table = new GLib.HashTable<int32, int32?> (null, null);
            int32[] id_list = new int32[0];
            for (var i = op.start; i < stop; i++) {
                unowned S4.ResultRow? row = @set[i];
                unowned S4.Result? result;
                if (row == null)
                    break;
                if ((result = row[0]) == null)
                    continue;

                int32 val;
                if ((val = result.value.get_int32 ()) == -1) 
                    continue;
                id_list += val;
                id_table->insert (val, val);
            }

            order += new ListOrdering (id_list);
            condition = create_idlist_filter (id_table);
        }

        private S4.Condition create_idlist_filter (GLib.HashTable<int32, int32?>* id_table) {
            return new S4.Condition.custom_filter (
                        (val, cond) => {
                            var ival = val.get_int32 ();
                            if (ival == -1)
                                return 1;
                            var table = (GLib.HashTable<int32, int32?>)cond.get_funcdata ();
                            if (table.lookup (ival) == null)
                                return 1;
                            return 0;
                        }, id_table, (S4.FreeFunc)g_hash_table_destroy,
                        "song_id", session.source_preferences, 
                        S4.CompareMode.BINARY, 0, S4.COND_PARENT);
        }

        void visit_intersection (IntersectionOperator op) {
            var cond = new S4.Condition.combiner (S4.CombineType.AND);

            var len = op.operands.length;

            // we keep the ordering of the first operand
            op.operands[0].accept (this);
            cond.add_operand (condition);
           
            var old_order = order;
            order = null;

            for (var i = 1; i < len; i++) {
                op.operands[i].accept (this);
                cond.add_operand (condition);
            }
            
            order = old_order;
            condition = cond;
        }

        void visit_union (UnionOperator op) {
            if (op.has_order ()) {
                visit_ordered_union (op);
            } else {
                visit_unordered_union (op);
            }
        }
        
        void visit_ordered_union (UnionOperator op) {
            GLib.HashTable<int32, int32?>* id_table = 
                new GLib.HashTable<int32, int32?> (null, null);

            int32[] id_list = new int32[0];
            foreach (var operand in op.operands) {
                var @set = medialib_query_recursive (session, operand, fetch);
                foreach (unowned S4.ResultRow row in @set) {
                    unowned S4.Result? result = row[0];
                    if (result == null)
                        continue;

                    int32 val = result.value.get_int32 ();
                    if (val == -1)
                        continue;

                    id_list += val;
                    id_table->insert (val, val);
                }
            }

            order += new ListOrdering (id_list);
            condition = create_idlist_filter (id_table);
        }

        void visit_unordered_union (UnionOperator op) {
            var cond = new S4.Condition.combiner (S4.CombineType.OR);
            foreach (var operand in op.operands) {
                operand.accept (this);
                cond.add_operand (condition);
            }
            condition = cond;
        }

        void visit_complement (ComplementOperator op) {
            var cond = new S4.Condition.combiner (S4.CombineType.NOT);

            op.operand.accept (this);
            cond.add_operand (condition);

            condition = cond;
        }
        
        void visit_filter (FilterOperator op) {
            var cond = new S4.Condition.filter (op.get_filter_type (),
                                                op.field,
                                                op.value,
                                                op.source_preferences ?? session.source_preferences,
                                                op.compare_mode, 
                                                op.flags);
            Collection operand = op.operand;
            if (!(operand is Universe)) {
                var op_cond = cond;
                cond = new S4.Condition.combiner (S4.CombineType.AND);
                cond.add_operand (op_cond);

                operand.accept (this);
                cond.add_operand (this.condition);
            }
            condition = cond;
        }
    }
}
