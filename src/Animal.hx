
class Animal {

	static inline var MOVE_SPEED = 20.;

	var data : Game.AnimalData;
	var game : Game;
	var frames : Array<h3d.mat.Texture>;
	var fullPath : Array<{ x : Int, y : Int }>;
	var bmp : h2d.Anim;
	var pos = -1;
	var progress = 0.;
	var prevTime : Float;
	var int : h2d.Interactive;

	public function new(a : Game.AnimalData) {
		this.data = a;
		game = Game.inst;
		frames = [for( i in 0...a.data.length >> 8 ) h3d.mat.Texture.fromPixels(game.loadFrame(a.data, i, true))];
		fullPath = [];
		for( p in a.path )
			fullPath.push({ x : (p % Game.WIDTH) * 16 + 8, y : Std.int(p / Game.WIDTH) * 16 + 8 });

		if( a.path[0] == a.path[a.path.length - 1] ) {
			fullPath.pop();
		} else {
			var dup = fullPath.copy();
			dup.pop();
			dup.reverse();
			dup.pop();
			for( d in dup ) fullPath.push(d);
		}

		bmp = new h2d.Anim([for( f in frames ) { var t = h2d.Tile.fromTexture(f); t.dx = -8; t.dy = -16; t; }]);
		int = new h2d.Interactive(16, 16, bmp);
		int.onOver = function(_) {
			game.setInfos(a.name+" by "+a.author+"\n(modified "+game.when(a.time)+")");
		};
		int.onOut = function(_) {
			game.setInfos();
		};
		int.x = -8;
		int.y = -16;
		bmp.speed = 6 * a.speed;
		game.view.add(bmp, 1);
		game.animals.push(this);
		update(game.time);
	}

	public function update(time:Float) {
		if( pos < 0 ) resume(time);
		var p = fullPath[pos % fullPath.length];
		var n = fullPath[(pos + 1) % fullPath.length];
		var d = hxd.Math.distance(p.x - n.x, p.y - n.y);
		if( d == 0 ) {
			bmp.x = p.x;
			bmp.y = p.y;
		} else {
			progress += (time - prevTime) * data.speed * MOVE_SPEED;
			bmp.x = p.x + ((n.x - p.x) / d) * progress;
			bmp.y = p.y + ((n.y - p.y) / d) * progress;
			if( n.x > p.x ) {
				int.x = -8;
				bmp.scaleX = int.scaleX = 1;
			} else if( n.x < p.x ) {
				int.x = 8;
				bmp.scaleX = int.scaleX = -1;
			}

			prevTime = time;
			if( progress > d ) {
				progress -= d;
				pos++;
			}
		}
	}

	function resume(time) {
		pos = 0;
		prevTime = time;
		// resume
		var dist = 0.;
		for( i in 0...fullPath.length ) {
			var p = fullPath[i];
			var n = fullPath[(i + 1) % fullPath.length];
			dist += hxd.Math.distance(p.x - n.x, p.y - n.y);
		}
		var dt = ((time - data.time) * data.speed * MOVE_SPEED) % dist;
		for( i in 0...fullPath.length ) {
			var p = fullPath[i];
			var n = fullPath[(i + 1) % fullPath.length];
			var d = hxd.Math.distance(p.x - n.x, p.y - n.y);
			if( dt > d ) {
				dt -= d;
				continue;
			}
			pos = i;
			progress = dt;
			break;
		}
	}

	public function remove() {
		game.animals.remove(this);
		for( f in frames ) f.dispose();
		bmp.remove();
	}

}