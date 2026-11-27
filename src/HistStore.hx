package mods.player_history;

import haxe.Json;
import sys.FileSystem;
import sys.io.File;

/** The players met, kept between sessions in the mod's data folder. */
class HistStore {
	static inline final FILE = "players.json";

	/** How many players are kept; the ones not seen for longest go first. */
	static inline final KEEP = 300;

	/** Do not write more often than this unless forced, in milliseconds. */
	static inline final SAVE_EVERY = 3000.0;

	public var entries(default, null):Array<HistEntry> = [];

	var path:String;
	var log:String->Void;
	var dirty:Bool = false;
	var lastSave:Float = 0;

	public function new(folder:String, log:String->Void) {
		path = folder + "/" + FILE;
		this.log = log;
		load();
	}

	public function find(id:Int):Null<HistEntry> {
		for (entry in entries)
			if (entry.id == id)
				return entry;
		return null;
	}

	/** A player is in the dungeon now. `newTrip` is true the first time in this trip to town and back. */
	public function seen(id:Int, name:String, cls:Int, level:Int, skin:Int, map:String, time:Float, newTrip:Bool, ascension:Int = 0):Void {
		var entry = find(id);
		if (entry == null) {
			entry = new HistEntry(id, name, time);
			entries.push(entry);
			if (entries.length > KEEP)
				dropOldest();
		}
		entry.name = name;
		if (cls > 0) {
			entry.cls = cls;
			entry.level = level;
			entry.skin = skin;
		}
		entry.ascension = ascension;
		if (map != "")
			entry.map = map;
		entry.last = time;
		if (newTrip)
			entry.count++;
		dirty = true;
	}

	/** Takes a player off the list. They are listed again if met again. */
	public function remove(id:Int):Void {
		var entry = find(id);
		if (entry == null)
			return;
		entries.remove(entry);
		dirty = true;
		flush(true);
	}

	/** The player was blocked on the server. */
	public function setBlocked(id:Int):Void {
		var entry = find(id);
		if (entry == null)
			return;
		entry.blocked = true;
		dirty = true;
		flush(true);
	}

	function dropOldest():Void {
		var oldest = entries[0];
		for (entry in entries)
			if (entry.last < oldest.last)
				oldest = entry;
		entries.remove(oldest);
	}

	/** Writes the file when something changed: at once if `force`, else at most every few seconds. */
	public function flush(force:Bool):Void {
		if (!dirty)
			return;
		var now = Date.now().getTime();
		if (!force && now - lastSave < SAVE_EVERY)
			return;
		save();
		lastSave = now;
	}

	function load():Void {
		if (!FileSystem.exists(path))
			return;
		try {
			var data:Dynamic = Json.parse(File.getContent(path));
			var list:Array<Dynamic> = data.players;
			for (item in list)
				entries.push(HistEntry.read(item));
		} catch (error:Dynamic) {
			// Set aside, so the next save does not overwrite what it held.
			log("could not read " + FILE + ", set aside as " + FILE + ".bad: " + error);
			entries = [];
			FileSystem.rename(path, path + ".bad");
		}
	}

	function save():Void {
		var list:Array<Dynamic> = [];
		for (entry in entries)
			list.push(entry.write());
		try {
			File.saveContent(path, Json.stringify({version: 1, players: list}, null, "\t"));
			dirty = false;
		} catch (error:Dynamic) {
			log("could not save " + FILE + ": " + error);
		}
	}
}
