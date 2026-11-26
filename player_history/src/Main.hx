package mods.player_history;

import brain.jsonRPC.JSONRPCService;
import distributedObjects.PresenceManager;
import brain.stateMachine.State;
import brain.stateMachine.StateMachine;
import brain.uI.UIButton;
import dBGlobals.DBGlobal;
import events.FriendSummaryNewsFeedEvent;
import facade.DBFacade;
import facade.Locale;
import flash.text.TextFormat;
import mods.api.Context;
import mods.api.Mod;
import mods.api.dungeon.Floor;
import mods.api.dungeon.Hero;
import openfl.display.MovieClip;
import openfl.display.Sprite;
import town.HomeState;
import uI.friendManager.UIFriendManager;
import uI.popup.DBUITwoButtonPopup;

/**
 * Player History: remembers the players met in dungeons (name, hero, level, how many dungeons together, last
 * map, when) and shows them in a board opened from a round button on the town's home screen, or with H.
 */
@:privateAccess
class Main extends Mod {
	/** Under the Ultimate Records button, at the options button's scale, in the home screen's units. */
	static inline final BUTTON_X = 1861.0;

	static inline final BUTTON_Y = 316.0;
	static inline final BUTTON_SCALE = 1.19;

	/** The town screens' layer. */
	static inline final TOWN_LAYER = 50;

	static inline final KEY_H:UInt = 72;
	static inline final KEY_ESCAPE:UInt = 27;
	static inline final KEY_SLASH:UInt = 191;

	var ctx:Context;
	var facade:Null<DBFacade>;
	var art:Null<HistArt>;
	var store:HistStore;
	var activity:ActivitySource;
	var board:Null<HistPopup>;
	var button:Null<UIButton>;
	var buttonClip:Null<MovieClip>;
	var atHome:Bool = false;

	/** The map of the floor being played, and the players already counted in the dungeon being played. */
	var map:String = "";

	var trip:Map<Int, Bool> = new Map();

	/** Players a friend request went to this session: true once sent. */
	var requested:Map<Int, Bool> = new Map();

	override public function init(ctx:Context):Void {
		this.ctx = ctx;
		store = new HistStore(ctx.data, ctx.log);
		activity = new ActivitySource(ctx);
		ctx.onFloorEnter(floorEntered);
		// Leaving a dungeon empties the players, whether for the town or another dungeon: that ends a dungeon.
		ctx.onFloorExit(function(_) record());
		ctx.onHeroSpawned(function(_:Hero) record());
		ctx.onHeroDespawned(function(_:Hero) record());
		ctx.onTownEnter(function() {
			record();
			trip = new Map();
			map = "";
			store.flush(true);
		});
		ctx.core.onStateEnter(stateEntered);
		ctx.core.onStateExit(stateExited);
		// The board's key can be changed by the player, as for the other mods; Escape closes the board.
		ctx.keys.action("open", "Open the board", "Opens the player history board from the home screen.", KEY_H).onPress(function() {
			if (atHome && board == null)
				openBoard();
		});
		ctx.onKeyDown(keyDown);
	}

	override public function ready(ctx:Context):Void {
		facade = ctx.core.facade;
		art = new HistArt(facade, function() {
			if (atHome)
				showButton();
		});
	}

	override public function dispose():Void {
		store.flush(true);
		closeBoard();
		hideButton();
		if (art != null)
			art.destroy();
	}

	function floorEntered(floor:Floor):Void {
		map = floor.map;
		record();
	}

	/** Reads the players of the dungeon in progress, the ones who left included. */
	function record():Void {
		if (ctx.state.players.length == 0) {
			// No dungeon: the next one counts its players again.
			trip = new Map();
			map = "";
			store.flush(false);
			return;
		}
		var now = Date.now().getTime();
		for (player in ctx.state.players) {
			if (player.local)
				continue;
			var name = player.name;
			if (name == null || name == "")
				continue;
			var id:Int = player.accountId;
			var hero = player.hero;
			var cls:Int = hero == null ? 0 : hero.classId;
			var level:Int = hero == null ? 0 : hero.level;
			var asc:Int = hero == null ? 0 : hero.ascension;
			// What the player's hero last showed, read by `name` just above.
			var skin:Int = player.knownSkin;
			store.seen(id, name, cls, level, skin, map, now, !trip.exists(id), asc);
			trip.set(id, true);
		}
		store.flush(false);
	}

	/** Escape closes the board, and the town does not see it. */
	function keyDown(key:UInt):Bool {
		if (board == null)
			return false;
		if (key == KEY_ESCAPE) {
			closeBoard();
			return true;
		}
		if (key == KEY_SLASH) {
			board.focusSearch();
			return true;
		}
		return false;
	}

	function stateEntered(machine:StateMachine, state:State):Void {
		if (Std.isOfType(state, HomeState)) {
			atHome = true;
			showButton();
		}
	}

	function stateExited(machine:StateMachine, state:State):Void {
		if (Std.isOfType(state, HomeState)) {
			atHome = false;
			closeBoard();
			hideButton();
		}
	}

	/** The options button's round frame, its gear swapped for two little players. */
	function showButton():Void {
		if (buttonClip != null || art == null || !art.ready || facade == null)
			return;
		var clip = art.roundButton();
		var up:MovieClip = cast clip.getChildByName("up");
		if (up != null) {
			// The gear is drawn last, over the frame and its gold ring.
			if (up.numChildren > 2)
				up.getChildAt(up.numChildren - 1).visible = false;
			up.addChild(people());
		}
		clip.x = BUTTON_X;
		clip.y = BUTTON_Y;
		clip.scaleX = clip.scaleY = BUTTON_SCALE;
		facade.sceneGraphManager.addChild(clip, TOWN_LAYER);
		buttonClip = clip;
		button = new UIButton(facade, clip);
		button.rolloverFilter = DBGlobal.UI_ROLLOVER_FILTER;
		button.releaseCallback = openBoard;
	}

	/** Two players, as heads and shoulders, in gold with the popups' dark outline. */
	function people():Sprite {
		var icon = new Sprite();
		var g = icon.graphics;
		g.lineStyle(2, 0x330000, 1);
		for (offset in [-7.0, 7.0]) {
			g.beginFill(offset < 0 ? 0xE0A800 : 0xFFCC00, 1);
			g.drawCircle(offset, -7, 5.5);
			g.endFill();
			g.beginFill(offset < 0 ? 0xE0A800 : 0xFFCC00, 1);
			g.drawRoundRect(offset - 8, 0, 16, 11, 8, 8);
			g.endFill();
		}
		return icon;
	}

	function hideButton():Void {
		if (button != null)
			button.destroy();
		if (buttonClip != null && facade != null)
			facade.sceneGraphManager.removeChild(buttonClip);
		button = null;
		buttonClip = null;
	}

	function openBoard():Void {
		if (board != null || art == null || !art.ready || facade == null)
			return;
		activity.reload();
		board = new HistPopup(ctx, facade, art, store, activity, requested, addFriend, blockPlayer, unfriendPlayers, function() board = null);
	}

	/**
	 * Sends a friend request by account id, as `Player.addFriend` does for a player in a dungeon. If the other side
	 * had already asked, the answer lists the new friend, and the game's friend list and presence are told of it.
	 */
	function addFriend(entry:HistEntry):Void {
		var info = facade == null ? null : facade.dbAccountInfo;
		if (info == null || entry.id == Std.int(info.id))
			return;
		var rpc = JSONRPCService.getFunction("DRFriendRequest", facade.rpcRoot + "friendrequests");
		var onError = UIFriendManager.createFriendRPCErrorCallback(facade, "player history addFriend");
		var id = entry.id;
		// no Facebook id since 1.0: null, as the end screen sends
		rpc(info.name, info.trophies, info.activeAvatarSkinId, null, info.id, id, facade.demographics, facade.validationToken, function(result:Dynamic) {
			if (!answered(result))
				return;
			if (Std.isOfType(result, Array)) {
				var list:Array<Dynamic> = result;
				// `new Vector` has no runtime class to build from a script: its UInt form is openfl's IntVector.
				var ids:Dynamic = Type.createInstance(Type.resolveClass("openfl._Vector.IntVector"), [0, false, null]);
				ids.push(ASCompat.asUint(Reflect.field(list[1], "account_id")));
				PresenceManager.instance().addFriends(ids);
				facade.dbAccountInfo.addFriendCallback(list[0]);
			}
			requested.set(id, true);
			ctx.log("friend request sent to " + entry.name);
			if (board != null)
				board.refresh();
		}, onError);
	}

	/**
	 * Asks with the game's popup, then blocks the player on the server, as `Player.block` does for a player in a
	 * dungeon, here by account id. The game's popup sits under the board, so the board is closed and opened again.
	 */
	function blockPlayer(entry:HistEntry):Void {
		var info = facade == null ? null : facade.dbAccountInfo;
		if (info == null || entry.id == Std.int(info.id))
			return;
		var person = entry.name;
		var id = entry.id;
		closeBoard();
		var popup = new DBUITwoButtonPopup(facade, "PLAYER_HISTORY_BLOCK_POPUP", Locale.getString("BLOCK") + " " + person + "?",
			person + Locale.getString("VICTORY_SCREEN_BLOCK_POPUP_MESSAGE"), Locale.getString("BLOCK"), function() {
				var rpc = JSONRPCService.getFunction("IgnoreFriend", facade.rpcRoot + "friendrequests");
				rpc(facade.dbAccountInfo.id, id, facade.validationToken, function(result:Dynamic) {
					if (answered(result)) {
						store.setBlocked(id);
						ctx.log("blocked " + person);
					}
					reopenSoon();
				});
			}, Locale.getString("CANCEL"), function() reopenSoon());
		var format = new TextFormat();
		format.color = FriendSummaryNewsFeedEvent.FRIEND_NAME_HIGHLIGHT_COLOR;
		popup.colorizeMessage(format, 0, person.length);
	}

	/**
	 * Removes friends from the game's friend list, as the game's own friend manager does. The players stay in the
	 * history board; only the friendship is undone. The game's confirmation popup sits under the board, so the
	 * board is closed and opened again afterwards.
	 */
	function unfriendPlayers(entries:Array<HistEntry>):Void {
		var info = facade == null ? null : facade.dbAccountInfo;
		if (info == null)
			return;
		var ids:Array<Int> = [];
		var names:Array<String> = [];
		for (entry in entries) {
			if (entry.id > 0 && info.isFriend(entry.id)) {
				ids.push(entry.id);
				names.push(entry.name);
			}
		}
		if (ids.length == 0)
			return;
		var label = ids.length == 1 ? names[0] : ids.length + " FRIENDS";
		closeBoard();
		var popup = new DBUITwoButtonPopup(facade, "PLAYER_HISTORY_UNFRIEND_POPUP", "REMOVE " + label.toUpperCase() + "?",
			"Remove " + label + " from your friend list? They will stay in your player history.", Locale.getString("REMOVE"), function() {
				var rpc = JSONRPCService.getFunction("DRFriendRemove", facade.rpcRoot + "friendrequests");
				rpc(facade.accountId, ids, facade.validationToken, function(result:Dynamic) {
					// As the game's own friend manager: its callback tolerates an empty or false answer.
					facade.dbAccountInfo.removeFriendCallback(result);
					ctx.log("removed friends: " + names.join(", "));
					reopenSoon();
				});
			}, Locale.getString("CANCEL"), function() reopenSoon());
		var format = new TextFormat();
		format.color = FriendSummaryNewsFeedEvent.FRIEND_NAME_HIGHLIGHT_COLOR;
		popup.colorizeMessage(format, 7, label.length);
	}

	/** The end screen's test for a successful answer, kept as written: an object answer has no length, and passes. */
	static function answered(result:Dynamic):Bool {
		return result != null && !(ASCompat.toNumberField(result, "length") <= 0);
	}

	/** A moment after the game's popup has gone, so its closing does not take the board's menu layer with it. */
	function reopenSoon():Void {
		haxe.Timer.delay(openBoard, 200);
	}

	function closeBoard():Void {
		if (board != null)
			board.close();
	}
}
