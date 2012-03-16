s4:
	valac s4_test.vala Common.vala Error.vala Ordering.vala Playlist.vala Medialib.vala MedialibSession.vala CollectionVisitors/SerializeVisitor.vala CollectionVisitors/QueryVisitor.vala Collection.vala FetchInfo.vala Config.vala Log.vala --pkg s4 --vapidir ./vapi -X -L./lib/s4/_build_/src/lib -X -ls4 -X -fPIC -X -I./lib/s4/include --pkg posix --pkg helpers -g -X -Wno-incompatible-pointer-types -X -Wno-unused-value --pkg gio-2.0

s4src:
	valac s4_test.vala Common.vala Error.vala Ordering.vala Playlist.vala Medialib.vala MedialibSession.vala CollectionVisitors/SerializeVisitor.vala CollectionVisitors/QueryVisitor.vala Collection.vala FetchInfo.vala Config.vala Log.vala --pkg s4 --vapidir ./vapi -X -L./lib/s4/_build_/src/lib -X -ls4 -X -fPIC -X -I./lib/s4/include --pkg posix -C --pkg helpers --pkg gio-2.0
