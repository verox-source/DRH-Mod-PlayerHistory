package mods.player_history;

import brain.uI.UIButton;
import dBGlobals.DBGlobal;
import distributedObjects.HeroGameObjectOwner;
import facade.DBFacade;
import mods.api.Context;
import mods.api.dungeon.Hero;
import openfl.display.DisplayObject;
import openfl.display.MovieClip;
import openfl.display.Sprite;
import openfl.events.MouseEvent;
import openfl.events.Event;
import openfl.events.KeyboardEvent;
import openfl.filters.GlowFilter;
import openfl.geom.Vector3D;
import openfl.text.TextField;
import openfl.text.TextFieldType;
import openfl.text.TextFormatAlign;

/**
 * The player history board: the game's town popup stretched to a table of the players met, ten to a page.
 * Four tabs: the latest players, the ones most played with, friends, and the manager.
 */
class HistPopup {
	/** The popup's size in its own units; the game shows its popups at `SCALE`. */
	static inline final W = 800.0;
	static inline final H = 470.0;
	static inline final SCALE = 1.8;

	/** The centre of the popup symbol's frame, which the board keeps. */
	static inline final CX = 380.0;
	static inline final CY = 253.0;
	static inline final POPUP_LAYER = 105;

	/** The menu layer that gives Escape to the board. */
	static inline final NAV_LAYER = "PLAYER_HISTORY";

	static inline final MARGIN = 36.0;
	static inline final ROW = 27.0;
	static inline final PER_PAGE = 10;
	static inline final ICON = 22.0;

	/** Extra room for the title above the popup base, used when fitting the screen. */
	static inline final TOP_ROOM = 28.0;

	static inline final GOLD = 0xFFCC00;
	static inline final WHITE = 0xFFFFFF;
	static inline final CLEAN = 0xF2F6F8;
	static inline final ACCENT = 0x9FD8FF;
	static inline final DIM = 0xB8A48C;
	static inline final LIVE = 0x77FF99;
	static inline final DAY = 86400000.0;

	/** How often the open board checks presence and relative times. */
	static inline final REFRESH_MS = 500.0;

	static var TABS:Array<String> = ["RECENT", "MOST PLAYED", "FRIENDS", "MANAGER"];

	/** The heroes: GameMaster ids, constants (for the default skin) and the names the game shows. */
	static var HERO_IDS:Array<Int> = [101, 102, 103, 104, 105, 106, 107, 108];
	static var HERO_CONSTANTS:Array<String> = ["BERSERKER", "RANGER", "SORCERER", "BATTLE_CHEF", "VAMPIRE_HUNTER", "GHOST_SAMURAI", "PYROMANCER", "DRAGON_KNIGHT"];
	static var HERO_NAMES:Array<String> = ["BERSERKER", "RANGER", "SORCERER", "BATTLE CHEF", "VAMPIRE HUNTER", "GHOST SAMURAI", "PYROMANCER", "DRAGON KNIGHT"];

	static var MAPS:Array<String> = [
		"INFINITE_ARENA", "INFINITE_CATACOMBS", "INFINITE_PRISON", "INFINITE_ICE_CAVES", "INFINITE_VILLAGE", "INFINITE_TEMPLE", "INFINITE_DINO",
		"INFINITE_AZTECH", "INFINITE_TRIBAL"
	];
	static var MAP_NAMES:Array<String> = ["ARENA", "BARROWS", "PRISON", "CAVERNS", "BATTLEHEIM", "FROSTGAARD", "DINO PARK", "RUINS", "JUNGLE"];

	var ctx:Context;
	var facade:DBFacade;
	var art:HistArt;
	var store:HistStore;
	var activity:ActivitySource;
	var onAdd:HistEntry->Void;
	var onBlock:HistEntry->Void;
	var onUnfriend:Array<HistEntry>->Void;
	var requested:Map<Int, Bool>;
	var onClose:Void->Void;
	var holder:Sprite;
	var frame:MovieClip;
	var status:TextField;
	var body:Null<Sprite>;
	var texts:Sprite;
	var actions:Null<Sprite>;
	var armedNext:Int = -1;
	var closeButton:UIButton;
	var tabs:Array<UIButton> = [];
	var previous:UIButton;
	var next:UIButton;
	var previousClip:MovieClip;
	var nextClip:MovieClip;
	var tab:Int = 0;
	var page:Int = 0;
	var open:Bool = true;
	var selected:Map<Int, Bool> = new Map();
	var searchText:String = "";
	var searchField:TextField;
	var liveDot:Sprite;
	var boardScale:Float = SCALE;

	/** MANAGER sorts by Online Tracker activity; false is most active first. */
	var leastFirst:Bool = false;

	var nextActivityReload:Float = 0;

	/** The last built view, so the board only rebuilds when something a player can see changed. */
	var lastSignature:String = "";

	var refreshAt:Float = 0;

	public function new(ctx:Context, facade:DBFacade, art:HistArt, store:HistStore, activity:ActivitySource, requested:Map<Int, Bool>, onAdd:HistEntry->Void,
			onBlock:HistEntry->Void, onUnfriend:Array<HistEntry>->Void, onClose:Void->Void) {
		this.ctx = ctx;
		this.facade = facade;
		this.art = art;
		this.store = store;
		this.activity = activity;
		this.requested = requested;
		this.onAdd = onAdd;
		this.onBlock = onBlock;
		this.onUnfriend = onUnfriend;
		this.onClose = onClose;

		frame = art.popup();
		layoutFrame();
		var stage = facade.stageRef;
		var maxW = stage.stageWidth - 24;
		var maxH = stage.stageHeight - 24;
		boardScale = SCALE;
		if (maxW > 0 && W * boardScale > maxW)
			boardScale = maxW / W;
		if (maxH > 0 && (H + TOP_ROOM) * boardScale > maxH)
			boardScale = maxH / (H + TOP_ROOM);
		frame.scaleX = frame.scaleY = boardScale;
		holder = new Sprite();
		holder.addChild(frame);
		facade.sceneGraphManager.showPopupCurtain();
		facade.sceneGraphManager.addChild(holder, POPUP_LAYER);
		frame.x = stage.stageWidth / 2 - CX * boardScale;
		frame.y = stage.stageHeight / 2 - CY * boardScale;
		facade.menuNavigationController.pushNewLayer(NAV_LAYER, close, closeButton);
		show(0, 0);
		frame.addEventListener(Event.ENTER_FRAME, tick);
	}

	public function refresh():Void {
		if (open)
			show(tab, page);
	}

	/** Sends the keyboard to the search box, as the game's other lists do. */
	public function focusSearch():Void {
		if (open && searchField != null)
			facade.stageRef.focus = searchField;
	}

	/** Keeps the LIVE pip alive and the visible rows current without rebuilding on every frame. */
	function tick(_:Event):Void {
		if (!open)
			return;
		var now = Date.now().getTime();
		if (liveDot != null)
			liveDot.alpha = 0.35 + 0.65 * (0.5 + 0.5 * Math.sin(now / 260));
		if (tab == 3 && now >= nextActivityReload) {
			nextActivityReload = now + 10000;
			activity.reload();
		}
		if (now < refreshAt)
			return;
		refreshAt = now + REFRESH_MS;
		if (signature() != lastSignature)
			show(tab, page);
	}

	public function close():Void {
		if (!open)
			return;
		open = false;
		frame.removeEventListener(Event.ENTER_FRAME, tick);
		facade.menuNavigationController.popLayer(NAV_LAYER);
		facade.sceneGraphManager.removeChild(holder);
		facade.sceneGraphManager.removePopupCurtain();
		closeButton.destroy();
		previous.destroy();
		next.destroy();
		for (button in tabs)
			button.destroy();
		if (searchField != null && searchField.parent != null)
			frame.removeChild(searchField);
		onClose();
	}

	function layoutFrame():Void {
		for (name in ["message_label", "left_button", "center_button", "right_button", "content"]) {
			var child = frame.getChildByName(name);
			if (child != null)
				child.visible = false;
		}
		var top = CY - H / 2;
		fit(frame.getChildByName("popup_base"), W, H);
		var base = frame.getChildByName("popup_base");
		base.x = CX;
		base.y = CY;

		var banner = frame.getChildByName("banner_title_label");
		fit(banner, W * 0.7, banner.height * 1.3);
		banner.x = CX;
		banner.y = top - 4;
		var title = HistArt.field(frame, "title_label");
		var format = title.defaultTextFormat;
		format.size = 26;
		format.color = CLEAN;
		format.align = TextFormatAlign.CENTER;
		title.defaultTextFormat = format;
		title.width = W * 0.7;
		title.height = 42;
		title.x = CX - title.width / 2;
		title.y = banner.y - 17;
		title.filters = [new GlowFilter(ACCENT, 0.45, 6, 6, 2)];
		title.text = "PLAYER HISTORY";

		var rule = new Sprite();
		rule.graphics.lineStyle(2, ACCENT, 0.45);
		rule.graphics.moveTo(CX - W / 2 + MARGIN, top + 44);
		rule.graphics.lineTo(CX + W / 2 - MARGIN, top + 44);
		frame.addChild(rule);

		liveDot = new Sprite();
		liveDot.graphics.beginFill(LIVE);
		liveDot.graphics.drawCircle(0, 0, 4);
		liveDot.graphics.endFill();
		liveDot.x = CX + W / 2 - MARGIN - 12;
		liveDot.y = top + 14;
		frame.addChild(liveDot);
		var liveLabel = art.text(true, 10, LIVE, 42, TextFormatAlign.LEFT);
		liveLabel.text = "LIVE";
		liveLabel.x = liveDot.x - 48;
		liveLabel.y = top + 7;
		frame.addChild(liveLabel);

		var cross:MovieClip = cast frame.getChildByName("close");
		cross.x = CX + W / 2 - 6;
		cross.y = top + 8;
		closeButton = new UIButton(facade, cross);
		closeButton.rolloverFilter = DBGlobal.UI_ROLLOVER_FILTER;
		closeButton.releaseCallback = close;

		for (i in 0...TABS.length)
			addTab(i, top);

		status = art.text(false, 11, CLEAN, 440, TextFormatAlign.LEFT);
		status.selectable = false;
		status.mouseEnabled = false;
		status.x = CX - W / 2 + MARGIN + 8;
		status.y = top + 24;
		frame.addChild(status);

		// Search box
		var searchLabel = art.text(true, 10, ACCENT, 60, TextFormatAlign.LEFT);
		searchLabel.text = "SEARCH:";
		searchLabel.x = CX + W / 2 - MARGIN - 220;
		searchLabel.y = top + 24;
		frame.addChild(searchLabel);
		searchField = art.text(false, 11, WHITE, 150, TextFormatAlign.LEFT);
		searchField.type = TextFieldType.INPUT;
		searchField.selectable = true;
		searchField.mouseEnabled = true;
		searchField.border = true;
		searchField.borderColor = 0x5C7C90;
		searchField.background = true;
		searchField.backgroundColor = 0x141C22;
		searchField.x = CX + W / 2 - MARGIN - 160;
		searchField.y = top + 20;
		searchField.height = 20;
		searchField.text = searchText;
		searchField.addEventListener(Event.CHANGE, function(_:Event) {
			searchText = searchField.text;
			show(tab, 0);
		});
		frame.addChild(searchField);

		previousClip = pageButton("< PREV", CX - 150, top + H - 30);
		nextClip = pageButton("NEXT >", CX + 150, top + H - 30);
		previous = new UIButton(facade, previousClip);
		previous.rolloverFilter = DBGlobal.UI_ROLLOVER_FILTER;
		previous.releaseCallback = function() show(tab, page - 1);
		next = new UIButton(facade, nextClip);
		next.rolloverFilter = DBGlobal.UI_ROLLOVER_FILTER;
		next.releaseCallback = function() show(tab, page + 1);
	}

	static function fit(art:DisplayObject, width:Float, height:Float):Void {
		art.scaleX = art.scaleY = 1;
		art.scaleX = width / art.width;
		art.scaleY = height / art.height;
	}

	function addTab(index:Int, top:Float):Void {
		var clip = art.tab();
		clip.x = CX + (index - 1) * 150.0;
		clip.y = top + 56;
		var label = HistArt.field(clip, "label");
		if (label != null)
			label.text = TABS[index];
		frame.addChild(clip);
		var button = new UIButton(facade, clip);
		button.rolloverFilter = DBGlobal.UI_ROLLOVER_FILTER;
		button.selectedFilter = DBGlobal.UI_SELECTED_FILTER;
		button.releaseCallback = function() show(index, 0);
		tabs.push(button);
	}

	function pageButton(text:String, x:Float, y:Float):MovieClip {
		var clip = art.tab();
		clip.x = x;
		clip.y = y;
		clip.scaleX = clip.scaleY = 0.8;
		var label = HistArt.field(clip, "label");
		if (label != null)
			label.text = text;
		frame.addChild(clip);
		return clip;
	}

	function isFriend(entry:HistEntry):Bool {
		var info = facade.dbAccountInfo;
		return info != null && info.isFriend(entry.id);
	}

	function liveStatus(entry:HistEntry):String {
		try {
			var info = facade.dbAccountInfo;
			var friend = info == null ? null : info.friendInfos.itemFor(entry.id);
			if (friend == null)
				return "";
			if (!friend.isOnline())
				return "OFFLINE";
			var presence = facade.mDistributedObjectManager == null ? null : facade.mDistributedObjectManager.mPresenceManager;
			if (presence != null && presence.isInDungeon(entry.id))
				return "IN DUNGEON";
			return "ONLINE";
		} catch (_:Dynamic) {}
		return "";
	}

	function players(tab:Int):Array<HistEntry> {
		var list:Array<HistEntry> = [];
		var needle = searchText == null ? "" : searchText.toLowerCase();
		for (entry in store.entries) {
			// FRIENDS and MANAGER are friends only. The other tabs keep everyone met.
			if ((tab == 2 || tab == 3) && !isFriend(entry))
				continue;
			if (needle.length > 0 && !matches(entry, needle))
				continue;
			list.push(entry);
		}
		if (tab == 1)
			list.sort(function(a, b) return a.count != b.count ? b.count - a.count : (b.last > a.last ? 1 : -1));
		else if (tab == 3)
			list.sort(function(a, b) {
				var ta = activity.lastOnline(a.id);
				var tb = activity.lastOnline(b.id);
				if (ta != tb)
					return leastFirst ? (ta < tb ? -1 : 1) : (ta > tb ? -1 : 1); // 0 = never, last when most-active first
				return b.last > a.last ? 1 : (b.last < a.last ? -1 : 0);
			});
		else
			list.sort(function(a, b) return b.last > a.last ? 1 : (b.last < a.last ? -1 : 0));
		return list;
	}

	/** Search finds part of a name, hero or last map, rather than only the start of a name. */
	static function matches(entry:HistEntry, needle:String):Bool {
		if (entry.name != null && entry.name.toLowerCase().indexOf(needle) >= 0)
			return true;
		if (heroNameOf(entry.cls).toLowerCase().indexOf(needle) >= 0)
			return true;
		return mapName(entry.map).toLowerCase().indexOf(needle) >= 0;
	}

	/** A fingerprint of what is on screen, used to refresh without rebuilding unchanged rows. */
	function signature():String {
		var list = players(tab);
		var parts:Array<String> = [Std.string(tab), Std.string(page), searchText, Std.string(list.length), Std.string(leastFirst)];
		var from = page * PER_PAGE;
		for (i in 0...PER_PAGE) {
			var index = from + i;
			if (index >= list.length)
				break;
			var entry = list[index];
			parts.push([entry.id, entry.count, Std.int(entry.last / 60000), liveStatus(entry),
				isFriend(entry) ? 1 : 0, entry.blocked ? 1 : 0,
				requested.exists(entry.id) && requested.get(entry.id) ? 1 : 0,
				tab == 3 ? Std.string(activity.lastOnline(entry.id)) : ""].join(":"));
		}
		return parts.join("|");
	}

	/** One line telling you at a glance what the board knows, not just how many rows it has. */
	function summary(now:Float):String {
		var total = store.entries.length;
		var friends = 0;
		var dungeons = 0;
		var repeats = 0;
		var today = 0;
		for (entry in store.entries) {
			if (isFriend(entry))
				friends++;
			if (liveStatus(entry) == "IN DUNGEON")
				dungeons++;
			if (entry.count > 1)
				repeats++;
			if (now - entry.last < DAY)
				today++;
		}
		return "TOTAL " + total + "  |  FRIENDS " + friends + "  |  IN DUNGEONS " + dungeons
			+ "  |  REPEATS " + repeats + "  |  24H " + today;
	}

	/** True when the player is in a dungeon right now, so JOIN can be highlighted. */
	function canJoin(entry:HistEntry):Bool {
		try {
			if (entry.id <= 0)
				return false;
			var presence = facade.mDistributedObjectManager == null ? null : facade.mDistributedObjectManager.mPresenceManager;
			return presence != null && presence.isInDungeon(entry.id);
		} catch (_:Dynamic) {}
		return false;
	}

	function show(newTab:Int, newPage:Int):Void {
		tab = newTab;
		for (i in 0...tabs.length)
			tabs[i].selected = i == tab;
		if (body != null)
			frame.removeChild(body);
		body = new Sprite();
		body.mouseEnabled = false;
		body.mouseChildren = true;
		frame.addChild(body);
		if (actions != null)
			frame.removeChild(actions);
		actions = new Sprite();
		frame.addChild(actions);
		var armed = armedNext;
		armedNext = -1;
		texts = art.labels();
		texts.mouseEnabled = false;
		texts.mouseChildren = false;
		
		var top = CY - H / 2;
		var list = players(tab);
		var pages = Std.int(Math.max(1, Math.ceil(list.length / PER_PAGE)));
		page = Std.int(Math.max(0, Math.min(pages - 1, newPage)));
		setEnabled(previous, previousClip, page > 0);
		setEnabled(next, nextClip, page < pages - 1);

		if (list.length == 0)
			empty(top);
		else if (tab == 3)
			manager(top, list);
		else
			rows(top, list, armed);

		// The counts live in the top strip now, so the PREV/NEXT row stays clear.
		setStatus(summary(Date.now().getTime()));
		add(art.text(true, 12, ACCENT, 120, TextFormatAlign.CENTER), "PAGE " + (page + 1) + "/" + pages, CX - 60, top + H - 52);
		body.addChild(texts);
		lastSignature = signature();
	}

	function setStatus(text:String):Void {
		if (status == null)
			return;
		status.text = text;
		// Join messages are temporary; the counts come back so the top strip stays useful.
		if (text != summary(Date.now().getTime())) {
			haxe.Timer.delay(function() {
				if (open && status != null)
					status.text = summary(Date.now().getTime());
			}, 2500);
		}
	}

	static function setEnabled(button:UIButton, clip:MovieClip, on:Bool):Void {
		button.enabled = on;
		clip.alpha = on ? 1 : 0.4;
	}

	function empty(top:Float):Void {
		var title = art.text(true, 16, CLEAN, W, TextFormatAlign.CENTER);
		title.text = tab == 2 ? "NO FRIENDS MET YET" : "NO PLAYERS YET";
		title.x = CX - W / 2;
		title.y = top + 170;
		texts.addChild(title);
		var hint = art.text(false, 12, WHITE, W - 2 * MARGIN, TextFormatAlign.CENTER);
		hint.text = "Players you meet in dungeons are listed here.";
		hint.x = CX - W / 2 + MARGIN;
		hint.y = top + 205;
		texts.addChild(hint);
	}

	function rows(top:Float, list:Array<HistEntry>, armed:Int):Void {
		var left = CX - W / 2 + MARGIN;
		var right = CX + W / 2 - MARGIN;
		var checkX = left + 6;
		var iconX = left + 24;
		var starX = left + 56;
		var nameX = left + 72;
		var heroX = left + 196;
		var timesX = left + 328;
		var mapX = left + 374;
		var seenX = left + 454;
		var headTop = top + 86;

		var selLabel = art.text(true, 10, ACCENT, 30, TextFormatAlign.LEFT);
		selLabel.text = "SEL";
		selLabel.x = checkX;
		selLabel.y = headTop;
		texts.addChild(selLabel);

		var heads = ["PLAYER", "HERO", "WITH", "LAST MAP", "SEEN"];
		var xs = [nameX, heroX, timesX, mapX, seenX];
		for (i in 0...heads.length) {
			var head = art.text(true, 11, ACCENT, 116, TextFormatAlign.LEFT);
			head.text = heads[i];
			head.x = xs[i];
			head.y = headTop;
			texts.addChild(head);
		}

		var now = Date.now().getTime();
		var from = page * PER_PAGE;
		for (i in 0...PER_PAGE) {
			var index = from + i;
			if (index >= list.length)
				break;
			var entry = list[index];
			var y = headTop + 24 + ROW * i;
			if (i % 2 == 0)
				stripe(left, y, right - left);
			var isSel = selected.exists(entry.id) && selected.get(entry.id);
			drawCheckbox(checkX + 6, y + ROW / 2, isSel, entry.id);
			heroIcon(entry.cls, entry.skin, iconX + ICON / 2, y + ROW / 2);
			if (isFriend(entry))
				star(starX, y + ROW / 2);
			var fresh = now - entry.first < DAY;
			add(art.text(true, 13, entry.blocked ? DIM : fresh ? CLEAN : WHITE, 116, TextFormatAlign.LEFT), cut(entry.name, 14), nameX, y);
			var heroName = heroNameOf(entry.cls);
			var heroText = entry.level > 0 ? heroName + " LV " + entry.level : heroName;
			if (entry.ascension > 0)
				heroText += " AS " + entry.ascension;
			add(art.text(true, 10, entry.cls > 0 ? WHITE : DIM, 128, TextFormatAlign.LEFT), heroText, heroX, y);
			add(art.text(false, 13, entry.count > 1 ? ACCENT : DIM, 40, TextFormatAlign.LEFT), "x" + entry.count, timesX, y);
			add(art.text(true, 10, CLEAN, 72, TextFormatAlign.LEFT), cut(mapName(entry.map), 10), mapX, y);
			var live = liveStatus(entry);
			if (live == "") {
				add(art.text(false, 11, DIM, 72, TextFormatAlign.LEFT), ago(now - entry.last), seenX + 8, y);
			} else {
				var liveColor = live == "OFFLINE" ? DIM : LIVE;
				livePip(seenX + 2, y + ROW / 2, liveColor);
				add(art.text(true, 10, liveColor, 72, TextFormatAlign.LEFT), live, seenX + 12, y);
			}

			var joinX = right - 2 - 46;
			var addX = joinX - 2 - 40;
			var blockX = addX - 2 - 44;
			var removeX = blockX - 2 - 48;
			smallButton("JOIN", joinX, y, 46, canJoin(entry) ? 0x2E7D32 : 0x3A4448, function() joinPlayer(entry));
			if (isFriend(entry))
				smallButton("FRIEND", addX, y, 40, 0x3A4448, null);
			else if (requested.exists(entry.id) && requested.get(entry.id))
				smallButton("SENT", addX, y, 40, 0x3A4448, null);
			else
				smallButton("ADD", addX, y, 40, 0x2E7D32, function() {
					requested.set(entry.id, false);
					show(tab, page);
					onAdd(entry);
				});
			if (entry.blocked)
				smallButton("BLOCKED", blockX, y, 44, 0x4A4038, null);
			else
				smallButton("BLOCK", blockX, y, 44, 0xA3342B, function() onBlock(entry));
			var sure = armed == entry.id;
			smallButton(sure ? "SURE?" : "REMOVE", removeX, y, 48, sure ? 0xC25A10 : 0x5A4630, function() {
				if (sure) {
					store.remove(entry.id);
					show(tab, page);
				} else {
					armedNext = entry.id;
					show(tab, page);
				}
			});
		}

		var picked = selectedCount(list);
		var by = top + H - 80;
		smallButton("ADD SELECTED (" + picked + ")", left + 8, by, 142, 0x2E7D32, function() {
			for (entry in list) {
				if (selected.exists(entry.id) && selected.get(entry.id) && !isFriend(entry)) {
					requested.set(entry.id, false);
					onAdd(entry);
				}
			}
			selected = new Map();
			show(tab, page);
		});
		smallButton("BLOCK SELECTED (" + picked + ")", left + 158, by, 158, 0xA3342B, function() {
			for (entry in list) {
				if (selected.exists(entry.id) && selected.get(entry.id))
					onBlock(entry);
			}
			selected = new Map();
			show(tab, page);
		});
	}

	function manager(top:Float, list:Array<HistEntry>):Void {
		var left = CX - W / 2 + MARGIN;
		var right = CX + W / 2 - MARGIN;
		var checkX = left + 6;
		var iconX = left + 24;
		var starX = left + 56;
		var nameX = left + 72;
		var heroX = left + 196;
		var timesX = left + 328;
		var mapX = left + 374;
		var seenX = left + 454;
		var headTop = top + 86;

		var selLabel = art.text(true, 10, ACCENT, 60, TextFormatAlign.LEFT);
		selLabel.text = "SEL";
		selLabel.x = checkX;
		selLabel.y = headTop;
		texts.addChild(selLabel);

		var heads = ["PLAYER", "HERO", "WITH", "LAST MAP", "ONLINE"];
		var xs = [nameX, heroX, timesX, mapX, seenX];
		for (i in 0...heads.length) {
			var head = art.text(true, 11, ACCENT, 116, TextFormatAlign.LEFT);
			head.text = heads[i];
			head.x = xs[i];
			head.y = headTop;
			texts.addChild(head);
		}

		var now = Date.now().getTime();
		var from = page * PER_PAGE;
		for (i in 0...PER_PAGE) {
			var index = from + i;
			if (index >= list.length)
				break;
			var entry = list[index];
			var y = headTop + 24 + ROW * i;
			if (i % 2 == 0)
				stripe(left, y, right - left);
			var isSel = selected.exists(entry.id) && selected.get(entry.id);
			drawCheckbox(checkX + 6, y + ROW / 2, isSel, entry.id);
			heroIcon(entry.cls, entry.skin, iconX + ICON / 2, y + ROW / 2);
			if (isFriend(entry))
				star(starX, y + ROW / 2);
			var fresh = now - entry.first < DAY;
			add(art.text(true, 13, entry.blocked ? DIM : fresh ? CLEAN : WHITE, 116, TextFormatAlign.LEFT), cut(entry.name, 14), nameX, y);
			var heroName = heroNameOf(entry.cls);
			var heroText = entry.level > 0 ? heroName + " LV " + entry.level : heroName;
			if (entry.ascension > 0)
				heroText += " AS " + entry.ascension;
			add(art.text(true, 10, entry.cls > 0 ? WHITE : DIM, 128, TextFormatAlign.LEFT), heroText, heroX, y);
			add(art.text(false, 13, entry.count > 1 ? ACCENT : DIM, 40, TextFormatAlign.LEFT), "x" + entry.count, timesX, y);
			add(art.text(true, 10, CLEAN, 72, TextFormatAlign.LEFT), cut(mapName(entry.map), 10), mapX, y);
			// MANAGER shows the Online Tracker stamp, so "least active" is visible as well as sortable.
			var stamp = activityStamp(entry.id);
			var live = liveStatus(entry);
			if (live == "") {
				add(art.text(false, 10, DIM, 72, TextFormatAlign.LEFT), stamp, seenX + 8, y);
			} else {
				var liveColor = live == "OFFLINE" ? DIM : LIVE;
				livePip(seenX + 2, y + ROW / 2, liveColor);
				add(art.text(false, 10, live == "OFFLINE" ? DIM : CLEAN, 72, TextFormatAlign.LEFT), stamp, seenX + 12, y);
			}
		}

		var picked = selectedCount(list);
		var by = top + H - 80;
		smallButton("SELECT PAGE", left + 8, by, 116, 0x3A5A70, function() {
			var allOn = picked >= PER_PAGE;
			for (i in 0...PER_PAGE) {
				var index = from + i;
				if (index >= list.length)
					break;
				selected.set(list[index].id, !allOn);
			}
			show(tab, page);
		});
		// In MANAGER this takes them off the friend list, not off the history board.
		smallButton("UNFRIEND (" + picked + ")", left + 132, by, 132, 0x5A4630, function() {
			var chosen:Array<HistEntry> = [];
			for (entry in list) {
				if (selected.exists(entry.id) && selected.get(entry.id))
					chosen.push(entry);
			}
			selected = new Map();
			if (chosen.length > 0)
				onUnfriend(chosen);
			if (open)
				show(tab, page);
		});
		smallButton("BLOCK (" + picked + ")", left + 272, by, 132, 0xA3342B, function() {
			for (entry in list) {
				if (selected.exists(entry.id) && selected.get(entry.id))
					onBlock(entry);
			}
			selected = new Map();
			show(tab, page);
		});
		smallButton(leastFirst ? "MOST ACTIVE" : "LEAST ACTIVE", left + 412, by, 146, 0x3A5A70, function() {
			leastFirst = !leastFirst;
			show(tab, 0);
		});
	}

	/** Online Tracker's date in a compact form, or NEVER when it has no record. */
	function activityStamp(id:Int):String {
		var stamp = activity.lastOnline(id);
		if (stamp <= 0)
			return "NEVER";
		var date = Date.fromTime(stamp);
		return pad2(date.getMonth() + 1) + "-" + pad2(date.getDate()) + " "
			+ pad2(date.getHours()) + ":" + pad2(date.getMinutes());
	}

	static function pad2(value:Int):String {
		return value < 10 ? "0" + value : "" + value;
	}

	function selectedCount(list:Array<HistEntry>):Int {
		var count = 0;
		for (entry in list)
			if (selected.exists(entry.id) && selected.get(entry.id))
				count++;
		return count;
	}

	/** A small presence light beside a friend's status. */
	function livePip(x:Float, y:Float, color:Int):Void {
		var pip = new Sprite();
		pip.x = x;
		pip.y = y;
		pip.graphics.beginFill(color, 1);
		pip.graphics.drawCircle(0, 0, 3);
		pip.graphics.endFill();
		body.addChild(pip);
	}

	function drawCheckbox(x:Float, y:Float, checked:Bool, id:Int):Void {
		var box = new Sprite();
		box.x = x;
		box.y = y - 8;
		box.graphics.lineStyle(1, 0xFFFFFF, 1);
		box.graphics.beginFill(checked ? 0x2E6B8F : 0x18222A, 1);
		box.graphics.drawRect(0, 0, 14, 14);
		box.graphics.endFill();
		if (checked) {
			box.graphics.lineStyle(2, CLEAN, 1);
			box.graphics.moveTo(2, 7);
			box.graphics.lineTo(6, 11);
			box.graphics.lineTo(12, 2);
		}
		box.buttonMode = true;
		box.mouseEnabled = true;
		box.addEventListener(MouseEvent.CLICK, function(_:MouseEvent) {
			var cur = selected.exists(id) && selected.get(id);
			selected.set(id, !cur);
			show(tab, page);
		});
		body.addChild(box);
	}

	function joinPlayer(entry:HistEntry):Void {
		if (facade == null || entry.id <= 0) {
			setStatus("Cannot join this player.");
			return;
		}
		if (facade.mainStateMachine.currentStateName != "TownState") {
			setStatus("Join works from Town.");
			return;
		}
		var avatar = facade.dbAccountInfo.activeAvatarInfo;
		if (avatar == null || facade.dbAccountInfo.inventoryInfo.getEquipedItemsOnAvatar(avatar.id).length == 0) {
			setStatus("Equip a weapon to join.");
			return;
		}
		var presence = facade.mDistributedObjectManager == null ? null : facade.mDistributedObjectManager.mPresenceManager;
		if (presence == null || !presence.isInDungeon(entry.id)) {
			setStatus(entry.name + " is not in a dungeon right now.");
			return;
		}
		ctx.log("player_history: joining " + entry.name + " (" + entry.id + ")");
		close();
		facade.mainStateMachine.enterLoadingScreenState(0, "", entry.id, 0, false);
	}

	function smallButton(text:String, x:Float, y:Float, width:Float, fill:Int, action:Null<Void->Void>):Void {
		var button = new Sprite();
		button.x = x;
		button.y = y + 4;
		var height = ROW - 8;
		button.graphics.lineStyle(1.5, 0x330000, 1);
		button.graphics.beginFill(fill, 1);
		button.graphics.drawRoundRect(0, 0, width, height, 8, 8);
		button.graphics.endFill();
		button.mouseChildren = false;
		var label = art.text(true, 9, WHITE, width, TextFormatAlign.CENTER);
		label.text = text;
		label.y = (height - label.textHeight) / 2 - 2;
		button.addChild(label);
		if (action != null) {
			button.buttonMode = true;
			button.addEventListener(MouseEvent.ROLL_OVER, function(_:MouseEvent) button.alpha = 0.8);
			button.addEventListener(MouseEvent.ROLL_OUT, function(_:MouseEvent) button.alpha = 1);
			button.addEventListener(MouseEvent.CLICK, function(_:MouseEvent) action());
		} else
			button.alpha = 0.7;
		actions.addChild(button);
	}

	static function heroNameOf(cls:Int):String {
		var index = HERO_IDS.indexOf(cls);
		return index < 0 ? "HERO" : HERO_NAMES[index];
	}

	static function mapName(constant:String):String {
		if (constant == "")
			return "-";
		var index = MAPS.indexOf(constant);
		return index >= 0 ? MAP_NAMES[index] : StringTools.replace(constant, "_", " ");
	}

	static function cut(text:String, length:Int):String {
		return text.length <= length ? text : text.substr(0, length - 2) + "..";
	}

	function add(label:TextField, text:String, x:Float, rowY:Float):Void {
		label.text = text;
		label.x = x;
		label.y = rowY + (ROW - label.textHeight) / 2 - 2;
		texts.addChild(label);
	}

	static function ago(ms:Float):String {
		var minutes = Std.int(ms / 60000);
		if (minutes < 1)
			return "JUST NOW";
		if (minutes < 60)
			return minutes + " MIN AGO";
		if (ms < DAY)
			return Std.int(minutes / 60) + " H AGO";
		var days = Std.int(ms / DAY);
		return days == 1 ? "YESTERDAY" : days + " DAYS AGO";
	}

	function heroIcon(cls:Int, skin:Int, x:Float, y:Float):Void {
		var index = HERO_IDS.indexOf(cls);
		if (index < 0)
			return;
		var icon = new Sprite();
		icon.x = x;
		icon.y = y;
		art.hero(HERO_CONSTANTS[index], skin, ICON, icon);
		body.addChild(icon);
	}

	function star(x:Float, y:Float):Void {
		var mark = new Sprite();
		mark.x = x;
		mark.y = y;
		mark.graphics.lineStyle(1, 0x382209);
		mark.graphics.beginFill(GOLD, 1);
		for (i in 0...11) {
			var angle = i * Math.PI / 5 - Math.PI / 2;
			var radius = i % 2 == 0 ? 7 : 3;
			var px = Math.cos(angle) * radius;
			var py = Math.sin(angle) * radius;
			if (i == 0)
				mark.graphics.moveTo(px, py);
			else
				mark.graphics.lineTo(px, py);
		}
		mark.graphics.endFill();
		body.addChild(mark);
	}

	function stripe(x:Float, y:Float, width:Float):Void {
		var band = new Sprite();
		band.graphics.beginFill(0x000000, 0.22);
		band.graphics.drawRoundRect(x, y, width, ROW, 8, 8);
		band.graphics.endFill();
		body.addChild(band);
	}
}