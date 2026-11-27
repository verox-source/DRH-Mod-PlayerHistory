package mods.player_history;

import brain.assetRepository.AssetLoadingComponent;
import brain.assetRepository.SwfAsset;
import brain.uI.UIObject;
import facade.DBFacade;
import gameMasterDictionary.GMSkin;
import openfl.display.MovieClip;
import openfl.display.Sprite;
import openfl.filters.ColorMatrixFilter;
import openfl.filters.GlowFilter;
import openfl.text.TextField;
import openfl.text.TextFormat;
import openfl.text.TextFormatAlign;

/**
 * The game's art the board is made of: the town popup, tab and round button, the hero icons, and the
 * popup's two fonts (its title's comic one, its message's bold one). As in the Ultimate Records mod.
 */
class HistArt {
	static inline final TOWN_SWF = "Resources/Art2D/UI/db_UI_town.swf";

	/** Where every hero skin's icon is. */
	static inline final AVATARS_SWF = "Resources/Art2D/Icons/Avatars/db_icons_avatars.swf";

	/** The outline of the game's popup text. */
	static inline final OUTLINE = 0x330000;

	public var ready(get, never):Bool;

	var facade:DBFacade;
	var loader:AssetLoadingComponent;
	var town:Null<SwfAsset>;
	var titleFont:String = "_sans";
	var bodyFont:String = "_sans";
	var embedded:Bool = false;

	/** Runs `loaded` once the town art is in. */
	public function new(facade:DBFacade, loaded:Void->Void) {
		this.facade = facade;
		loader = new AssetLoadingComponent(facade);
		loader.getSwfAsset(DBFacade.buildFullDownloadPath(TOWN_SWF), function(asset:SwfAsset) {
			var sample = create(asset, "popup");
			var title = sample == null ? null : field(sample, "title_label");
			var body = sample == null ? null : field(sample, "message_label");
			if (title == null || body == null)
				return;
			titleFont = title.defaultTextFormat.font;
			bodyFont = body.defaultTextFormat.font;
			embedded = title.embedFonts;
			town = asset;
			loaded();
		});
		// Loaded now, so the hero icons do not wait on it at the board's first opening.
		loader.getSwfAsset(DBFacade.buildFullDownloadPath(AVATARS_SWF), function(_) {});
	}

	function get_ready():Bool {
		return town != null;
	}

	/** The game's town popup: a frame (`popup_base`), a banner and its title, a close button. */
	public function popup():MovieClip {
		return create(town, "popup");
	}

	/** The round button of the town's options. */
	public function roundButton():MovieClip {
		return create(town, "options_panel_button");
	}

	/** The game's prompt button, used for the tabs and the page buttons. */
	public function tab():MovieClip {
		return create(town, "UI_prompt_button_extended");
	}

	public static function field(clip:MovieClip, name:String):Null<TextField> {
		var child = clip.getChildByName(name);
		return Std.isOfType(child, TextField) ? cast child : null;
	}

	/** A layer for labels, outlined as the game's popups are: one outline for all of them. */
	public function labels():Sprite {
		var layer = new Sprite();
		layer.mouseEnabled = false;
		layer.mouseChildren = false;
		layer.filters = [new GlowFilter(OUTLINE, 1, 4, 4, 4)];
		return layer;
	}

	/** A label in the popup's title font, or else its message font, to go in `labels()`. */
	public function text(title:Bool, size:Int, color:Int, width:Float, align:TextFormatAlign):TextField {
		var label = new TextField();
		label.selectable = false;
		label.mouseEnabled = false;
		label.embedFonts = embedded;
		label.width = width;
		label.height = size * 1.7;
		var format = new TextFormat(title ? titleFont : bodyFont, size, color);
		format.align = align;
		label.defaultTextFormat = format;
		return label;
	}

	/** A hero's round icon: the skin's when known, else the class's default skin. */
	public function hero(constant:String, skinId:Int, size:Float, into:Sprite):Void {
		var gm = facade.gameMaster;
		var skin:GMSkin = skinId > 0 ? gm.getSkinByType(skinId) : null;
		if (skin == null) {
			var gmHero = gm.getHeroByConstant(constant);
			if (gmHero != null)
				skin = gm.getSkinByConstant(gmHero.DefaultSkin);
		}
		if (skin != null)
			icon(skin.UISwfFilepath, skin.IconName, size, into);
	}

	/** Greys out art, as for what is not there. */
	public static function grey(target:openfl.display.DisplayObject):Void {
		target.filters = [
			new ColorMatrixFilter([
				0.3, 0.59, 0.11, 0, 0,
				0.3, 0.59, 0.11, 0, 0,
				0.3, 0.59, 0.11, 0, 0,
				  0,    0,    0, 1, 0
			])
		];
		target.alpha = 0.45;
	}

	function icon(swf:String, name:String, size:Float, into:Sprite):Void {
		loader.getSwfAsset(DBFacade.buildFullDownloadPath(swf), function(asset:SwfAsset) {
			var clip = create(asset, name);
			if (clip == null)
				return;
			UIObject.scaleToFit(clip, size);
			into.addChild(clip);
		});
	}

	static function create(asset:SwfAsset, name:String):Null<MovieClip> {
		var type:Dynamic = asset.getClass(name);
		return type == null ? null : cast ASCompat.createInstance(type, []);
	}

	public function destroy():Void {
		loader.destroy();
	}
}
