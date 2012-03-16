namespace Xmms {
    // TODO
    public enum SortDirection {
        ASCENDING,
        DESCENDING
    }

    public abstract class Ordering : Object {
    }

    public class OrderById : Ordering {
    }

    public class OrderByValue : Ordering {
    }

    public class RandomOrdering : Ordering {
    }

    public class ListOrdering : Ordering {
        int32[] id_list = null;
        public ListOrdering (int32[] id_list) {
            this.id_list = id_list;
        }
    }

}
