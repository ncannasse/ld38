class Button extends h2d.Flow {

	var game : Game;

	public function new(text, onClick, ?parent) {
		super(parent);
		game = Game.inst;
		padding = 5;
		paddingTop = 3;
		borderWidth = borderHeight = 2;
		backgroundTile = hxd.Res.button.toTile();
		game.text(text, this);
		enableInteractive = true;
		horizontalAlign = Middle;
		this.interactive.onOver = function(_) {
			backgroundTile = hxd.Res.buttonOver.toTile();
		};
		this.interactive.onOut = function(_) {
			backgroundTile = hxd.Res.button.toTile();
		};
		this.interactive.onClick = function(_) onClick();
		this.interactive.cursor = Button;
	}

}