class Macro {

	public macro static function getPassword() {
		var pass = sys.io.File.getContent("password.txt");
		return macro haxe.crypto.Sha1.encode($v{pass});
	}

}