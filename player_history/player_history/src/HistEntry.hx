package mods.player_history;

/** A player met in a dungeon: who, the hero last seen, and how often and when. */
class HistEntry {
	public var id:Int;
	public var name:String;

	/** GameMaster hero class id of the hero last seen, 0 when not known. */
	public var cls:Int = 0;

	public var level:Int = 0;
	/** How many times the hero ascended, 0 for a hero that never did. */
	public var ascension:Int = 0;
	public var skin:Int = 0;

	/** How many dungeons (from the first floor to leaving the dungeon) were played together. */
	public var count:Int = 0;

	/** Milliseconds since 1970. */
	public var first:Float;

	public var last:Float;

	/** The map constant of the last floor played together. */
	public var map:String = "";

	/** Blocked from this board. */
	public var blocked:Bool = false;

	public function new(id:Int, name:String, time:Float) {
		this.id = id;
		this.name = name;
		first = last = time;
	}

	public static function read(data:Dynamic):HistEntry {
		var time:Float = data.last;
		var entry = new HistEntry(Std.int(data.id), Std.string(data.name), time);
		entry.cls = Std.int(data.cls);
		entry.level = Std.int(data.level);
		entry.ascension = data.ascension == null ? 0 : Std.int(data.ascension);
		entry.skin = Std.int(data.skin);
		entry.count = Std.int(data.count);
		var first:Float = data.first;
		entry.first = first;
		entry.map = data.map == null ? "" : Std.string(data.map);
		entry.blocked = data.blocked == true;
		return entry;
	}

	public function write():Dynamic {
		return {
			id: id,
			name: name,
			cls: cls,
			level: level,
			ascension: ascension,
			skin: skin,
			count: count,
			first: first,
			last: last,
			map: map,
			blocked: blocked
		};
	}
}
