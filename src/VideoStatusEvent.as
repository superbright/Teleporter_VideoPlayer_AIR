package 
{
	import flash.events.Event;
	
	internal class VideoStatusEvent extends Event
	{
		public static const VIDEO_STATUS:String = "onVideoStatus";
		public var status:String = "";
		
		public function VideoStatusEvent(type:String, msg:String, bubbles:Boolean=false, cancelable:Boolean=false)
		{
			super(type, bubbles, cancelable);
			status = msg;
		}
	}
}