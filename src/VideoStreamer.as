package 
{
	import flash.events.AsyncErrorEvent;
	import flash.events.EventDispatcher;
	import flash.events.NetStatusEvent;
	import flash.media.SoundTransform;
	import flash.net.NetConnection;
	import flash.net.NetStream;

	internal class VideoStreamer extends EventDispatcher
	{
		public var nc:NetConnection;
		public var ns:NetStream;
		public static var bufferTime:Number = 3;
		
		public var streamName:String;
		public var duration:Number = -1;
		public var isStreaming:Boolean;
		private var firstTimeBufferFull:Boolean = true;;
		
		public function VideoStreamer(server:String, streamName:String, isStreaming:Boolean = true) {
			this.streamName = streamName;
			this.isStreaming = isStreaming;
			
			nc = new NetConnection();
			nc.addEventListener(NetStatusEvent.NET_STATUS, ncOnStatus);
			nc.connect(server);
		}
		
		private function ncOnStatus(event:NetStatusEvent):void
		{
			trace(streamName + " nc: "+event.info.code+" ("+event.info.description+")");
			if (event.info.code == "NetConnection.Connect.Success")
			{
				playLiveStream();
			}
			else if (event.info.code == "NetConnection.Connect.Failed") {
				dispatchEvent(new VideoStatusEvent(VideoStatusEvent.VIDEO_STATUS, "Video.Play.Failed"));
				trace(event.info.description);
			}
			else if (event.info.code == "NetConnection.Connect.Rejected") {
				dispatchEvent(new VideoStatusEvent(VideoStatusEvent.VIDEO_STATUS, "Video.Play.Failed"));
				trace(event.info.description);
			}
			else if (event.info.code == "NetConnection.Connect.Closed") {
				dispatchEvent(new VideoStatusEvent(VideoStatusEvent.VIDEO_STATUS, "Video.Play.Failed"));
				trace("closed");
				trace(event.info.description);
			}
		}
		
		private function nsOnStatus(event:NetStatusEvent):void
		{
			//trace(streamName + " nsPlay: "+event.info.code+" ("+event.info.description+")");
			if (event.info.code == "NetStream.Play.StreamNotFound" || event.info.code == "NetStream.Play.Failed") {
				trace("description " + event.info.description);
				dispatchEvent(new VideoStatusEvent(VideoStatusEvent.VIDEO_STATUS, "Video.Play.Failed"));
			}
			else if (event.info.code == "NetStream.Buffer.Full" && firstTimeBufferFull) {
				firstTimeBufferFull = false;
				dispatchEvent(new VideoStatusEvent(VideoStatusEvent.VIDEO_STATUS, "Video.Play.Ready"));
			}
			else if (event.info.code == "NetStream.Buffer.Empty" && !isStreaming) {
				// seamlessly loop local files
			
				ns.seek(0.0); 
			} 
			else if (event.info.code == "NetStream.Play.Stop") {
				// seamlessly loop local files
				//trace("stopped " + isStreaming);
				//trace(streamName);
				dispatchEvent(new VideoStatusEvent(VideoStatusEvent.VIDEO_STATUS, "Video.Play.Stopped"));
				//ns.seek(0); 
			} 
		}
		
		private function playLiveStream():void
		{
			ns = new NetStream(nc);
			
			// trace the NetStream status information
			ns.addEventListener(NetStatusEvent.NET_STATUS, nsOnStatus);
			ns.addEventListener(AsyncErrorEvent.ASYNC_ERROR, function():void {
				trace("async error");
				dispatchEvent(new VideoStatusEvent(VideoStatusEvent.VIDEO_STATUS, "Video.Play.Failed"));
			});

			
			var nsPlayClientObj:Object = new Object();
			ns.client = nsPlayClientObj;
			
			nsPlayClientObj.onMetaData = function(infoObject:Object):void
			{
//				trace("onMetaData");
				
				// print debug information about the metaData
				for (var propName:String in infoObject)
				{
//					trace("  "+propName + " = " + infoObject[propName]);
					if (propName == "duration") {
						duration = infoObject[propName];
					}
				}
				
			};		
			
			// set a short buffer time
			ns.bufferTime = bufferTime;
			
			// subscribe to the named stream
			ns.play(streamName);
			ns.soundTransform = new SoundTransform(0);
		}
		
		public function close():void
		{
			if (isStreaming) {
				ns.dispose();
				ns.close();
				nc.close();
				trace("close from streamer");
				
			} else {
				ns.pause();
				ns.seek(0);
				trace("closed loop from streamer");
			}
		}
	}
}