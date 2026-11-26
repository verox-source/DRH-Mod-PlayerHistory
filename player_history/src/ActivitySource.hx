package mods.player_history;

import haxe.Json;
import mods.api.Context;
import sys.FileSystem;
import sys.io.File;

/**
 * Reads the last-online dates kept by the Online Tracker mod, so Player History can sort friends by
 * activity without changing or depending on that mod. The file is a sibling data folder.
 */
class ActivitySource {
	var path:String;
	var log:String->Void;
	var lastOnlineByFriend:Map<Int, Float> = new Map();
	var warned:Bool = false;

	public function new(ctx:Context) {
		log = ctx.log;
		var base = ctx.data;
		var slash = base.lastIndexOf("/");
		if (slash < 0)
			slash = base.lastIndexOf("\\");
		var parent = slash >= 0 ? base.substring(0, slash) : base;
		path = parent + "/online_tracker/activity_history.json";
		reload();
	}

	/** Re-reads the tracker file, which can change while the game is open. */
	public function reload():Void {
		lastOnlineByFriend = new Map();
		if (!FileSystem.exists(path)) {
			if (!warned) {
				warned = true;
				log("player_history: no online_tracker activity file at " + path);
			}
			return;
		}
		try {
			var data:Dynamic = Json.parse(File.getContent(path));
			var activity:Dynamic = data.activity;
			if (activity == null)
				return;
			for (id in Reflect.fields(activity)) {
				var stamp = parseDate(Std.string(Reflect.field(activity, id)));
				if (stamp > 0)
					lastOnlineByFriend.set(Std.parseInt(id), stamp);
			}
		} catch (error:Dynamic) {
			if (!warned) {
				warned = true;
				log("player_history: could not read online_tracker activity: " + Std.string(error));
			}
		}
	}

	/** Milliseconds of the friend's last recorded online moment; 0 when never recorded. */
	public function lastOnline(id:Int):Float {
		var stamp = lastOnlineByFriend.get(id);
		return stamp == null ? 0 : stamp;
	}

	static function parseDate(value:String):Float {
		if (value == null || value.length < 16)
			return 0;
		var text = value;
		if (text.charAt(10) == " ")
			text = text.substring(0, 10) + "T" + text.substring(11);
		try {
			return Date.fromString(text).getTime();
		} catch (_:Dynamic) {}
		return 0;
	}
}
