package
{
	import flash.display.Sprite;
	import flash.events.Event;
	import starling.core.Starling;
		import flash.system.Capabilities;

	[SWF(width="640", height="480", frameRate="60", backgroundColor="#666666")]

	public class Main extends Sprite
	{
		private var starling:Starling;

		public function Main():void
		{
			super();
			addEventListener(Event.ADDED_TO_STAGE, init);
		}
		private function init(e:Event = null):void
		{
			removeEventListener(Event.ADDED_TO_STAGE, init);
			starling = new Starling(Screen, stage);
			starling.start();
		}
	}
}
