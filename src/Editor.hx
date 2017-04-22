
class Editor {

	var game : Game;
	var data : haxe.io.Bytes;
	var content : h2d.Flow;
	var texture : h3d.mat.Texture;
	var curColor = 16;

	public function new(data) {
		game = Game.inst;
		game.editor = this;
		this.data = data;
		content = new h2d.Flow();
		content.backgroundTile = h2d.Tile.fromColor(0x404040, 0.2);
		content.verticalAlign = Middle;
		content.horizontalAlign = Middle;
		content.enableInteractive = true;
		content.horizontalSpacing = 20;
		game.s2d.add(content, Game.LAYER_EDITOR);

		texture = new h3d.mat.Texture(16, 16);
		texture.clear(0);

		var zoom = 16;

		var editZone = new h2d.Sprite(content);


		var bg = new h2d.Bitmap(hxd.Res.transparent.toTile(), editZone);
		bg.tile.setSize(16 * zoom, 16 * zoom);
		bg.tileWrap = true;

		var view = new h2d.Bitmap(h2d.Tile.fromTexture(texture), editZone);
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
				data.set(posX + posY * 16, mouseDown == 0 ? curColor : 0);
				sync();
			}
		};
		int.onPush = function(e) {
			mouseDown = e.button;
			if( e.button == 0 ) {
				data.set(posX + posY * 16, curColor);
				sync();
			} else {
				data.set(posX + posY * 16, 0);
				sync();
			}
		};
		int.onRelease = function(_) {
			mouseDown = null;
		};
		int.enableRightButton = true;

		var right = new h2d.Flow(content);
		right.verticalAlign = Top;
		right.isVertical = true;
		right.horizontalAlign = Middle;
		right.verticalSpacing = 10;
		right.minHeight = zoom * 16;

		var preview = new h2d.Bitmap(view.tile, right);
		preview.blendMode = None;

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

		new Button("Save", function() {
			remove();
			onSave(data);
		}, right);

		new Button("Cancel", function() {
			remove();
			onCancel();
		}, right);

		sync();
		onResize();
	}

	public function remove() {
		texture.dispose();
		content.remove();
		if( game.editor == this ) game.editor = null;
	}

	public function sync() {
		var pixels = hxd.Pixels.alloc(16, 16, ARGB);
		for( y in 0...16 )
			for( x in 0...16 )
				pixels.setPixel(x, y, game.palette[data.get(x + y * 16)]);
		texture.uploadPixels(pixels);
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