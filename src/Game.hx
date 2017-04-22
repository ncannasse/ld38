class Game extends hxd.App {

	public static inline var LAYER_CURSOR = 2;
	public static inline var LAYER_UI = 3;
	public static inline var LAYER_EDITOR = 4;

	static inline var WIDTH = 86;
	static inline var HEIGHT = 48;

	static var p = Macro.getPassword();

	var ui : h2d.Flow;
	var buttons : h2d.Flow;
	var banner : h2d.Flow;
	var cursor : h2d.Bitmap;
	var tilesData : Map<Int,{ data : haxe.io.Bytes, author : String, time : Float }> = new Map();
	var texture : h3d.mat.Texture;
	var pixels : hxd.Pixels;
	var view : h2d.Bitmap;
	var cnx : org.mongodb.Mongo;
	var infos : h2d.Text;

	var prefs : { name : String };

	public var editor : Editor;
	public var palette : Array<Int>;

	override function init() {
		inst = this;
		@:privateAccess hxd.Stage.getInstance().window.title = "Your Small World";
		#if release
		engine.fullScreen = true;
		hl.UI.closeConsole();
		#end

		var pal = hxd.Res.palette.getPixels();
		palette = [for( y in 0...pal.height ) for( x in 0...pal.width ) pal.getPixel(x, y)];
		palette[0] = 0;

		texture = new h3d.mat.Texture(WIDTH * 16, HEIGHT * 16);
		view = new h2d.Bitmap(h2d.Tile.fromTexture(texture), s2d);
		pixels = hxd.Pixels.alloc(texture.width, texture.height, ARGB);

		ui = new h2d.Flow();
		s2d.add(ui, LAYER_UI);
		ui.verticalAlign = Top;
		ui.horizontalAlign = Middle;


		banner = new h2d.Flow(ui);
		banner.padding = 5;
		banner.visible = false;
		banner.horizontalAlign = Middle;


		infos = text("", ui);
		ui.getProperties(infos).align(Bottom, Middle);
		ui.getProperties(infos).paddingBottom = 20;
		var int = new h2d.Interactive(view.tile.width, view.tile.height, view);
		int.cursor = Default;
		int.onOut = function(_) setInfos();
		int.onMove = int.onCheck = function(e) {
			var x = Std.int(e.relX / 16);
			var y = Std.int(e.relY / 16);
			var t = tilesData.get(address(x, y));
			if( t == null || t.author == null || t.time == 0 )
				setInfos();
			else
				setInfos("Last edit " + when(t.time) + " by " + t.author);
		};

		onResize();

		try {
			prefs = hxd.Save.load(null,"prefs");
			if( prefs == null ) throw "!";
			refresh();
		} catch( e : Dynamic ) {
			prefs = { name : null };
			askName();
		}
	}


	function setInfos(?text:String) {
		infos.text = text == null ? "" : text;
	}

	function savePrefs() {
		hxd.Save.save(prefs, "prefs");
	}

	function askName() {

		var s = new h2d.Flow(ui);
		ui.getProperties(s).verticalAlign = Middle;
		s.isVertical = true;
		s.horizontalAlign = Middle;
		s.verticalSpacing = 10;
		text("Please enter your nickname:", s);

		var bg = new h2d.Flow(s);
		bg.backgroundTile = hxd.Res.textBg.toTile();
		bg.borderWidth = bg.borderHeight = 2;
		bg.padding = 3;
		bg.maxWidth = bg.minWidth = 100;

		var tf = new h2d.TextInput(getFont(), bg);
		tf.inputWidth = 100;
		tf.focus();

		new Button("OK", function() {

			var name = StringTools.trim(tf.text);
			if( name.length < 3 ) return;
			prefs.name = name;
			savePrefs();
			s.remove();
			refresh();

		}, s);
	}

	function initUI() {
		buttons = new h2d.Flow(ui);
		buttons.padding = 10;
		ui.getProperties(buttons).align(Bottom,Right);
		new Button("Edit Land", editLand, buttons);
	}

	function close() {
		cnx.close();
	}

	function connect() {
		cnx = new org.mongodb.Mongo("shirogames.com");
		var db = cnx.getDB("ld38");
		db.login("ld38",p);
		return db;
	}

	function refresh() {
		setBanner("Loading...");
		haxe.Timer.delay(function() {

			var cnx = connect();
			var tiles = cnx.getCollection("tiles");
			var ret = tiles.aggregate([
				{"$sort":{addr:1,time:1}},
				{"$group":{_id:"$addr", time:{"$last":"$time"}, data:{"$last":"$data"}, author:{"$last":"$author"}}},
			]);
			tilesData = new Map();
			for( t in ret )
				try tilesData.set(t._id, { data : haxe.zip.Uncompress.run(t.data), author : t.author, time : t.time }) catch( e : Dynamic ) {};
			close();

			if( buttons == null ) initUI();
			setBanner();
			rebuild();
		}, 1);
	}

	inline function address(x, y) {
		return x + y * WIDTH;
	}

	function timeStamp() {
		return Date.now().getTime() - 1492854000000.0;
	}

	function when(t:Float) {
		var dt = DateTools.parse(timeStamp() - t);
		var str = [];
		if( dt.days > 0 )
			str.push(dt.days + " days");
		if( dt.hours > 0 )
			str.push(dt.hours + " hours");
		if( dt.days == 0 && dt.minutes > 0 )
			str.push(dt.minutes + " minutes");
		if( dt.days == 0 && dt.hours == 0 )
			str.push(dt.seconds + " seconds");
		return str.join(" and ") + " ago";
	}

	function editLand() {
		setBanner("Please select a tile to edit");
		setCursor(hxd.Res.tileCursor, function(x, y) {
			setBanner();
			var t = tilesData.get(address(x, y));
			var tdat = t == null ? haxe.io.Bytes.alloc(16 * 16) : t.data.sub(0, t.data.length);
			var old = tdat.sub(0, tdat.length);
			new Editor(tdat).onSave = function(bytes) {

				if( bytes.compare(old) == 0 ) {
					setBanner();
					return;
				}


				var now = timeStamp();
				var cnx = connect();
				cnx.getCollection("tiles").insert({ addr : address(x, y), time : now, data : haxe.zip.Compress.run(bytes,9), author : prefs.name });
				close();

				tilesData.set(address(x, y), { author : prefs.name, data : bytes, time : now });
				rebuild();
			};
		}, function() setBanner());
	}

	function rebuild() {
		var pixels : hxd.Pixels.PixelsARGB = pixels;
		pixels.clear(0xFF202020);
		for( y in 0...HEIGHT )
			for( x in 0...WIDTH ) {
				var t = tilesData.get(address(x, y));
				if( t == null ) continue;
				var t = t.data;
				for( dy in 0...16 )
					for( dx in 0...16 ) {
						var c = palette[t.get(dx + dy * 16)];
						pixels.setPixel(x * 16 + dx, y * 16 + dy, c);
					}
			}
		texture.uploadPixels(pixels);
	}

	function setCursor( t : hxd.res.Image, onClick, onCancel ) {
		if( cursor != null ) {
			cursor.remove();
			cursor = null;
		}
		if( t == null ) return;
		buttons.visible = false;
		cursor = new h2d.Bitmap(t.toTile(), view);
		var stage = hxd.Stage.getInstance();
		var posX = 0, posY = 0;
		function syncCursor() {
			var pos = view.globalToLocal(new h2d.col.Point(stage.mouseX, stage.mouseY));
			posX = Std.int(pos.x / 16);
			posY = Std.int(pos.y / 16);
			if( posX < 0 ) posX = 0;
			if( posY < 0 ) posY = 0;
			if( posX >= WIDTH ) posX = WIDTH - 1;
			if( posY >= HEIGHT ) posY = HEIGHT - 1;
			cursor.x = posX * 16 - 1;
			cursor.y = posY * 16 - 1;
		}
		syncCursor();
		hxd.System.setCursor(Hide);
		s2d.startDrag(function(e) {
			hxd.System.setCursor(Hide);
			switch( e.kind ) {
			case EMove:
				syncCursor();
			case EPush:
				cursor.remove();
				cursor = null;
				hxd.System.setCursor(Default);
				buttons.visible = true;
				s2d.stopDrag();
				if( e.button == 0 ) {
					onClick(posX, posY);
				} else {
					onCancel();
				}
			default:
			}
		});
	}

	function setBanner( ?text, ?color = 0x008000) {

		while( banner.numChildren > 0 )
			banner.getChildAt(0).remove();

		if( text == null ) {
			banner.visible = false;
			return;
		}
		this.text(text, banner);
		banner.backgroundTile = h2d.Tile.fromColor(color);
		banner.visible = true;
	}

	override function onResize() {
		ui.minWidth = ui.maxWidth = engine.width;
		ui.minHeight = ui.maxHeight = engine.height;
		banner.minWidth = ui.minWidth;
		view.x = (engine.width - view.tile.width) >> 1;
		view.y = (engine.height - view.tile.height) >> 1;
		if( editor != null ) editor.onResize();
	}

	function getFont() {
		return hxd.res.DefaultFont.get();
	}

	public function text( text : String, ?parent ) {
		var tf = new h2d.Text(getFont(), parent);
		tf.text = text;
		return tf;
	}

	public static var inst : Game;

	static function main() {
		hxd.Res.initLocal();
		new Game();
	}

}