package
{
	import starling.display.Sprite;
	import starling.display.DisplayObject;
	import starling.extensions.neolit123.display.DisplayListDictionary;

	public class Screen extends Sprite
	{
		private var dict:DisplayListDictionary;

		public function Screen():void
		{
			super();

			dict = new DisplayListDictionary(LibExample);
			trace("elapsedTime:", dict.elapsedTime, "ms");
			var stars:DisplayObject = dict.get("starContainer");
			var textInput:DisplayObject = dict.get("textInput");
			var anim:DisplayObject = dict.get("animation");
			addChild(dict);
		}
		
		override public function dispose():void
		{
			dict.dispose();
			dict = null;
			super.dispose();
		}
	}
}
