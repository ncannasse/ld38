
class Editor {

	var game : Game;
	var data : haxe.io.Bytes;
	var content : h2d.Flow;
	var textures : Array<h3d.mat.Texture>;
	var texture2 : h3d.mat.Texture;
	var curColor = 16;
	var curFrame = 0;
	var frames : Int;

	var options : h2d.Flow;

	public var preview : h2d.Anim;

	public function new(frames = 1) {
		this.frames = frames;
		game = Game.inst;
		game.editor = this;
		content = new h2d.Flow();
		content.backgroundTile = h2d.Tile.fromColor(0x404040, 0.2);
		content.verticalAlign = Middle;
		content.horizontalAlign = Middle;
		content.enableInteractive = true;
		content.horizontalSpacing = 20;
		game.s2d.add(content, Game.LAYER_EDITOR);

		textures = [for( i in 0...frames ) new h3d.mat.Texture(16, 16)];
		for( t in textures ) t.clear(0);

		var zoom = 16;
		var editZone = new h2d.Sprite(content);

		var bg = new h2d.Bitmap(hxd.Res.transparent.toTile(), editZone);
		bg.tile.setSize(16 * zoom, 16 * zoom);
		bg.tileWrap = true;

		var view = new h2d.Bitmap(h2d.Tile.fromTexture(textures[0]), editZone);
		view.scale(zoom);

		var cursor = new h2d.Bitmap(hxd.Res.editCursor.toTile(), editZone);
		var int = new h2d.Interactive(16, 16, view);
		var posX = 0, posY = 0, mouseDown : Null<Int>;
		cursor.visible = false;
		int.onOver = function(_) cursor.visible = true;
		int.onOut = function(_) cursor.visible = false;
		int.onMove = function(e) {
			posX = Std.int(e.relX);
			posY = Std.int(e.relY);
			cursor.x = posX * zoom - 1;
			cursor.y = posY * zoom - 1;
			if( mouseDown != null ) {
				data.set(posX + posY * 16 + curFrame * 256, mouseDown == 0 ? curColor : 0);
				sync();
			}
		};
		int.onPush = function(e) {
			mouseDown = e.button;
			if( e.button == 0 ) {
				data.set(posX + posY * 16 + curFrame * 256, curColor);
				sync();
			} else {
				data.set(posX + posY * 16 + curFrame * 256, 0);
				sync();
			}
		};
		int.onRelease = function(_) {
			mouseDown = null;
		};
		int.enableRightButton = true;

		var right = new h2d.Flow(content);
		right.padding = 10;
		right.backgroundTile = h2d.Tile.fromColor(0x404040, 0.9);
		right.verticalAlign = Top;
		right.isVertical = true;
		right.horizontalAlign = Middle;
		right.verticalSpacing = 10;
		right.minHeight = zoom * 16;

		preview = new h2d.Anim([for( t in textures ) h2d.Tile.fromTexture(t)], right);
		preview.blendMode = None;
		preview.speed = 6;

		var pal = new h2d.Bitmap(hxd.Res.palette.toTile(), right);
		pal.scale(zoom);
		right.addSpacing(50);


		var cpal = new h2d.Bitmap(hxd.Res.tileCursor.toTile(), pal);
		cpal.scale(1 / zoom);
		var pint = new h2d.Interactive(pal.tile.width, pal.tile.height, pal);
		pint.onClick = function(e:hxd.Event) {
			if( e != null )
				curColor = Std.int(e.relX) + Std.int(e.relY) * pal.tile.width;
			cpal.x = curColor % pal.tile.width - 1 / zoom;
			cpal.y = Std.int(curColor / pal.tile.width) - 1 / zoom;
		}
		pint.onClick(null);

		options = new h2d.Flow(right);
		options.isVertical = true;
		options.verticalSpacing = 10;

		if( frames > 1 ) {
			new Button("Change Frame", function() {
				curFrame = 1 - curFrame;
				sync();
				view.tile = h2d.Tile.fromTexture(textures[curFrame]);
			}, right);
			right.addSpacing(10);
		}

		var bt = new h2d.Flow(right);
		bt.horizontalSpacing = 10;

		new Button("Save", function() {
			remove();
			onSave(data);
		}, bt);

		new Button("Cancel", function() {
			remove();
			onCancel();
		}, bt);

		onResize();
	}

	public function addInput(label, callb) {

		var s = new h2d.Flow(options);
		s.verticalAlign = Middle;
		s.horizontalSpacing = 10;
		game.text(label, s);

		var bg = new h2d.Flow(s);
		bg.backgroundTile = hxd.Res.textBg.toTile();
		bg.borderWidth = bg.borderHeight = 2;
		bg.padding = 3;
		bg.maxWidth = bg.minWidth = 100;

		var tf = new h2d.TextInput(game.getFont(), bg);
		tf.inputWidth = 100;
		tf.onChange = function() callb(tf.text);
		return tf;
	}


	public function addSlider(label, callb) {

		var s = new h2d.Flow(options);
		s.verticalAlign = Middle;
		s.horizontalSpacing = 10;
		game.text(label, s);

		var s = new h2d.Slider(100, 10, s);
		s.onChange = function() callb(s.value);
		return s;
	}

	public function load(data) {
		this.data = data;
		var old = curFrame;
		for( i in 0...frames ) {
			this.curFrame = i;
			sync();
		}
		curFrame = old;
		sync();
	}

	public function remove() {
		for( t in textures )
			t.dispose();
		content.remove();
		if( game.editor == this ) game.editor = null;
	}

	public function sync() {
		textures[curFrame].uploadPixels(game.loadFrame(data,curFrame,frames > 1));
	}

	public function onResize() {
		content.minWidth = game.engine.width;
		content.minHeight = game.engine.height;
	}

	public dynamic function onSave( bytes : haxe.io.Bytes ) {
	}

	public dynamic function onCancel() {
	}
}