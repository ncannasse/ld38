
typedef AnimalData = { data : haxe.io.Bytes, path : Array<Int>, speed : Float, time : Float, author : String, uid : Int, name : String };

class Game extends hxd.App {

	public static inline var LAYER_VIEW = 0;
	public static inline var LAYER_CURSOR = 2;
	public static inline var LAYER_UI = 3;
	public static inline var LAYER_EDITOR = 4;

	public static inline var WIDTH = 86;
	public static inline var HEIGHT = 48;

	static var p = Macro.getPassword();

	var ui : h2d.Flow;
	var buttons : h2d.Flow;
	var banner : h2d.Flow;
	var cursor : h2d.Bitmap;
	var tilesData : Map<Int,{ data : haxe.io.Bytes, author : String, time : Float }> = new Map();
	var texture : h3d.mat.Texture;
	var pixels : hxd.Pixels;
	public var view : h2d.Layers;
	var viewTiles : h2d.Bitmap;
	var cnx : org.mongodb.Mongo;
	var infos : h2d.Text;
	var defaultMap : hxd.Pixels;
	var invPalette = new Map();

	var prefs : { name : String, uid : Int, animal : AnimalData };
	var myAnimal : Animal;

	public var time : Float;

	public var animals : Array<Animal> = [];
	public var editor : Editor;
	var palette : Array<Int>;

	override function init() {
		inst = this;
		@:privateAccess hxd.Stage.getInstance().window.title = "Your Small World";
		#if release
		engine.fullScreen = true;
		hl.UI.closeConsole();
		#end

		engine.backgroundColor = 0xFF31A2F2;

		time = (Date.now().getTime() / 1000) - 1492854000.0;

		var pal = hxd.Res.palette.getPixels();
		palette = [for( y in 0...pal.height ) for( x in 0...pal.width ) pal.getPixel(x, y)];
		for( i in 0...palette.length )
			invPalette.set(palette[i], i);

		texture = new h3d.mat.Texture(WIDTH * 16, HEIGHT * 16, [Target]);
		view = new h2d.Layers(s2d);


		var def = new h2d.CdbLevel(Data.level, 0, view);
		def.redraw();
		def.drawTo(texture);
		defaultMap = texture.capturePixels();

		viewTiles = new h2d.Bitmap(h2d.Tile.fromTexture(texture), view);
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
		var int = new h2d.Interactive(viewTiles.tile.width, viewTiles.tile.height, view);
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
			prefs = { name : null, uid : Std.random(0x1000000), animal : null };
			askName();
		}
	}


	public function setInfos(?text:String) {
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
		text("Please enter your nickname:", s).textColor = 0;

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
		buttons.isVertical = true;
		buttons.verticalSpacing = 5;
		buttons.padding = 10;
		ui.getProperties(buttons).align(Bottom,Right);
		new Button("Edit Land", editLand, buttons).minWidth = 100;
		new Button("Edit Animal", editAnimal, buttons).minWidth = 100;
		new Button("Place Animal", placeAnimal, buttons).minWidth = 100;
		new Button("Refresh", refresh, buttons).minWidth = 100;
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
			var ret = cnx.getCollection("tiles").aggregate([
				{"$sort":{addr:1,time:1}},
				{"$group":{_id:"$addr", time:{"$last":"$time"}, data:{"$last":"$data"}, author:{"$last":"$author"}}},
			]);
			tilesData = new Map();
			for( t in ret )
				try tilesData.set(t._id, { data : haxe.zip.Uncompress.run(t.data), author : t.author, time : t.time }) catch( e : Dynamic ) {};

			var ret = cnx.getCollection("animals").aggregate([
				{"$sort":{uid:1, time:1}},
				{"$group":{_id:"$uid", time:{"$last":"$time"}, data:{"$last":"$data"}, author:{"$last":"$author"}, path:{"$last":"$path"}, speed:{"$last":"$speed"}, name:{"$last":"$name"}}},
			]);
			for( a in animals.copy() ) a.remove();
			for( a in ret ) {
				try {
					var a : AnimalData = a;
					a.uid = Reflect.field(a, "_id");
					Reflect.deleteField(a, "_id");
					a.data = haxe.zip.Uncompress.run(a.data);
					var an = new Animal(a);
					if( a.uid == prefs.uid ) myAnimal = an;
				} #if release
				catch( e : Dynamic ) {
				}
				#end
			}

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
		return Math.round(time);
	}

	public function when(t:Float) {
		var dt = DateTools.parse((time - t) * 1000);
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

	public function getDefaultLand(x, y) {
		var t = haxe.io.Bytes.alloc(16 * 16);
		for( dy in 0...16 )
			for( dx in 0...16 )
				t.set(dx + dy * 16, invPalette.get(defaultMap.getPixel(x * 16 + dx, y * 16 + dy)));
		return t;
	}

	function editLand() {
		setBanner("Please select a tile to edit");
		setCursor(function(x, y) {
			setBanner();
			var t = tilesData.get(address(x, y));
			var tdat = t == null ? getDefaultLand(x,y) : t.data.sub(0, t.data.length);
			var old = tdat.sub(0, tdat.length);
			var ed = new Editor();
			ed.load(tdat);
			ed.onSave = function(bytes) {

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
		}, function() setBanner(), function(x, y) {
			var t = tilesData.get(address(x, y));
			return t == null || time - t.time > 60 * 60;
		});
	}

	function editAnimal() {
		var a = prefs.animal;
		if( a == null )
			a = {
				speed : 1.,
				time : 0,
				name : "Unknown",
				path : null,
				uid : prefs.uid,
				author : prefs.name,
				data : null,
			};
		var adata = if( prefs.animal != null ) prefs.animal.data else haxe.io.Bytes.alloc(16 * 16 * 2);
		var ed = new Editor(2);
		ed.load(adata);
		ed.addInput("Name", function(n) a.name = n).text = a.name;
		var s = ed.addSlider("Speed", function(n) {
			a.speed = n;
			ed.preview.speed = 6 * a.speed;
		});
		s.minValue = 0.1;
		s.maxValue = 3;
		s.value = a.speed;
		ed.preview.speed = 6 * a.speed;
		ed.onSave = function(data) {
			if( prefs.animal == null )
				prefs.animal = a;
			a.data = data;
			savePrefs();
			if( myAnimal != null ) saveAnimal(a);
		};
	}

	public function loadFrame( data : haxe.io.Bytes, f : Int, transparent ) {
		var pixels = hxd.Pixels.alloc(16, 16, ARGB);
		var offset = f * 256;
		palette[0] = transparent ? 0 : 0xFF000000;
		for( y in 0...16 )
			for( x in 0...16 )
				pixels.setPixel(x, y, palette[data.get(x + y * 16 + offset)]);
		return pixels;
	}

	function saveAnimal(a:AnimalData) {
		a.author = prefs.name;
		a.uid = prefs.uid;
		savePrefs();
		if( myAnimal != null )
			myAnimal.remove();
		myAnimal = new Animal(a);

		var old = a.data;
		a.data = haxe.zip.Compress.run(a.data, 9);
		var cnx = connect();
		Reflect.deleteField(a, "_id");
		cnx.getCollection("animals").insert(a);
		close();
		a.data = old;
	}

	function placeAnimal() {

		if( prefs.animal == null )
			return;

		setBanner("Choose a path for your animal, double click to validate");
		var g = new h2d.Graphics(view);
		var path : Array<{x:Int,y:Int}> = [];

		function showPath() {
			g.clear();
			g.lineStyle(1, 0xFFFFFF);
			for( p in path )
				g.lineTo(p.x * 16 + 8, p.y * 16 + 8);
		}

		function done() {
			g.remove();
			setBanner();
			var a = prefs.animal;
			a.path = [for( p in path ) address(p.x, p.y)];
			a.time = timeStamp();
			saveAnimal(a);
		}

		function input() {
			setCursor(function(x, y) {
				if( path.length > 0 ) {
					var last = path[path.length - 1];
					var first = path[0];
					// closed
					if( x == first.x && y == first.y ) {
						path.push({x:x, y:y});
						done();
						return;
					}
					if( x == last.x && y == last.y ) {
						done();
						return;
					}
				}
				path.push({x:x, y:y});
				showPath();
				input();
			}, function() {
				setBanner();
				g.remove();
			}, function(x, y) {
				var last = path[path.length - 1];
				if( last == null || (last.x == x && last.y == y) ) return true;
				path.push({x:x,y:y});
				showPath();
				path.pop();
				return true;
			});
		}
		input();
	}

	function rebuild() {
		var pixels : hxd.Pixels.PixelsARGB = pixels;
		pixels.clear(0);
		palette[0] = 0xFF000000;
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

	function setCursor( onClick, onCancel, ?onPreview ) {
		buttons.visible = false;
		cursor = new h2d.Bitmap(hxd.Res.tileCursor.toTile(), view);
		var stage = hxd.Stage.getInstance();
		var posX = 0, posY = 0, allow = true;
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
			if( onPreview != null ) {
				allow = onPreview(posX, posY);
				cursor.color.set(1, allow?1:0, allow?1:0);
			}
		}
		syncCursor();
		hxd.System.setCursor(Hide);
		s2d.startDrag(function(e) {
			hxd.System.setCursor(Hide);
			switch( e.kind ) {
			case EMove:
				syncCursor();
			case EPush if( allow ):
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
		view.x = (engine.width - viewTiles.tile.width) >> 1;
		view.y = (engine.height - viewTiles.tile.height) >> 1;
		if( editor != null ) editor.onResize();
	}

	public function getFont() {
		return hxd.res.DefaultFont.get();
	}

	public function text( text : String, ?parent ) {
		var tf = new h2d.Text(getFont(), parent);
		tf.text = text;
		return tf;
	}

	override function update(dt:Float) {
		time += hxd.Timer.deltaT;
		for( a in animals )
			a.update(time);
		view.ysort(1);
	}

	public static var inst : Game;

	static function main() {
		hxd.Res.initLocal();
		Data.load(hxd.Res.data.entry.getText());
		new Game();
	}

}