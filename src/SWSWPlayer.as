package
{
	import flash.system.System;
	
	import com.greensock.TimelineMax;
	import com.greensock.TweenMax;
	import com.greensock.easing.Circ;
	import com.greensock.easing.Cubic;
	import com.greensock.plugins.ShortRotationPlugin;
	import com.greensock.plugins.TransformAroundCenterPlugin;
	import com.greensock.plugins.TransformAroundPointPlugin;
	import com.greensock.plugins.TweenPlugin;
	TweenPlugin.activate([ShortRotationPlugin, TransformAroundCenterPlugin, TransformAroundPointPlugin]);
	
	import flash.display.BitmapData;
	import flash.display.BlendMode;
	import flash.display.Sprite;
	import flash.display.StageAlign;
	import flash.display.StageDisplayState;
	import flash.display.StageScaleMode;
	import flash.events.Event;
	import flash.events.IOErrorEvent;
	import flash.events.KeyboardEvent;
	import flash.events.NetStatusEvent;
	import flash.events.ProgressEvent;
	import flash.events.SecurityErrorEvent;
	import flash.events.ServerSocketConnectEvent;
	import flash.filters.DisplacementMapFilter;
	import flash.filters.DisplacementMapFilterMode;
	import flash.geom.Matrix;
	import flash.geom.Point;
	import flash.media.SoundTransform;
	import flash.media.Video;
	import flash.net.NetConnection;
	import flash.net.NetStream;
	import flash.net.ServerSocket;
	import flash.net.Socket;
	import flash.ui.Keyboard;
	import flash.utils.ByteArray;
	import flash.utils.setTimeout;
	import flash.system.System;
	
	public class SWSWPlayer extends Sprite
	{
		
		
		private var server:String = "rtmp://ec2-54-227-184-166.compute-1.amazonaws.com/";
		private var streamName1:String = "livestream";
		private var streamName2:String = "mp4:Austin_2_Alamo_Ritz.mp4";
		
		// videos must be contained in sprites to fix registration point
		private var videos:Vector.<Video> = Vector.<Video>([new Video(1920,1080), new Video(1920,1080)]);
		private var sprites:Vector.<Sprite> = Vector.<Sprite>([new Sprite(), new Sprite()]);
		
		private var frontVideo:Video;
		private var front:int = 0;
		private var back:int = 1;
		
		private var transition:Sprite;
		private var frontSprite:Sprite;
		private var backSprite:Sprite;
		
		// static videos
		private var transitionStream:VideoStreamer;
		private var screensaverStream:VideoStreamer;
		private var homeScreenStream:VideoStreamer;
		
		private var transitiontoVideoStream:VideoStreamer;
		
		private var currentStream:VideoStreamer;
		
		private var serverSocket:ServerSocket = new ServerSocket();
		private var clientSocket:Socket;
		
		private var tl:TimelineMax = new TimelineMax();
		
		private var inTransition:Boolean;
		
		public function SWSWPlayer()
		{
		
			if (stage) init();
				
			else addEventListener(Event.ADDED_TO_STAGE, init);
		}
		
		
		private function init(e:Event = null):void
		{
			removeEventListener(Event.ADDED_TO_STAGE, init);
			inTransition = false;
			
			frontSprite = new Sprite();
			backSprite = new Sprite();
			frontVideo = new Video(1920,1080);
			
			currentStream = screensaverStream = new VideoStreamer(null, "gkffscreensaver.flv",false);
			screensaverStream.addEventListener(VideoStatusEvent.VIDEO_STATUS, function(event:VideoStatusEvent):void {
				if (event.status == "Video.Play.Ready") {
					frontVideo.attachNetStream(currentStream.ns);
					screensaverStream.ns.soundTransform = new SoundTransform(1);
				}
			});
			//Comp_W_Earth_7.flv
			transitionStream = new VideoStreamer(null, "Trans_V_to_V_ver4.flv", false);
			transitionStream.addEventListener(VideoStatusEvent.VIDEO_STATUS, function(event:VideoStatusEvent):void {
				if (event.status == "Video.Play.Ready") {
					transitionStream.ns.pause();
					transitionStream.ns.soundTransform = new SoundTransform(1);
				}
			});
			
			transitiontoVideoStream = new VideoStreamer(null, "Trans_SS_to_V_ver4.flv", false);
			transitiontoVideoStream.addEventListener(VideoStatusEvent.VIDEO_STATUS, function(event:VideoStatusEvent):void {
				if (event.status == "Video.Play.Ready") {
					transitiontoVideoStream.ns.pause();
					transitiontoVideoStream.ns.soundTransform = new SoundTransform(1);
				}
			});
			

			// setup stage
			stage.frameRate = 30;
			frontSprite.addChild(frontVideo);
			backSprite.addChild(videos[back]);
			
			stage.addChild(backSprite);
			stage.addChild(frontSprite);
			
			
			
			//stage.addChild(new FPSCounter());
			
			///////////////////// TEST
			// new VideoStreamer(server, streamName1);
//			currentStream = new VideoStreamer(server, streamName1, false);
//			currentStream.addEventListener(VideoStatusEvent.VIDEO_STATUS, function(event:VideoStatusEvent):void {
//				if (event.status == "Video.Play.Ready") {
//					trace("attach test to front");
//					frontVideo.attachNetStream(currentStream.ns);
//				}
//			});
			////////////////////
			
			// trick to move the registration point so scaling and rotation for videos happens from center
		
			sprites[0].x = sprites[1].x = stage.width/2;
			sprites[0].y = sprites[1].y = stage.height/2;
		
			
			stage.scaleMode = StageScaleMode.NO_SCALE;
			stage.align = StageAlign.TOP_LEFT;
			stage.addEventListener(KeyboardEvent.KEY_DOWN, keyDown);
			
			// setup tcp server
			serverSocket.bind(88);
			serverSocket.addEventListener(ServerSocketConnectEvent.CONNECT, onConnect);
			serverSocket.listen();
			
			//Event.EXITING
			
			addEventListener(Event.EXITING, onQuit);
		}
		
		private function onQuit(event):void {
			trace("quit");
			serverSocket.close();
		}
		
		private function onConnect( event:ServerSocketConnectEvent ):void
		{
			clientSocket = event.socket;
			clientSocket.addEventListener( ProgressEvent.SOCKET_DATA, onClientSocketData );
			clientSocket.addEventListener( Event.CONNECT, trace );
			clientSocket.addEventListener( Event.CLOSE, trace );
			clientSocket.addEventListener( IOErrorEvent.IO_ERROR, trace );
			clientSocket.addEventListener( SecurityErrorEvent.SECURITY_ERROR, trace );
			trace("Connection from " + clientSocket.remoteAddress + ":" + clientSocket.remotePort);
		}
		
		private function onClientSocketData( event:ProgressEvent ):void
		{
			
			var buffer:ByteArray = new ByteArray();
			clientSocket.readBytes( buffer, 0, clientSocket.bytesAvailable );
			trace("bytes available " + clientSocket.bytesAvailable);
			var str:String = buffer.toString(); //clientSocket.readUTF();
			trace("Received: " + str);
			
			var commands:Array = str.split("&");
			
			var command_type = commands[0];
			var command_call = commands[1];
			
			trace(command_call);
			switch (command_call) {
				case "START":
					if( transitionToScreensaver()) {
						clientSocket.writeUTFBytes("OK\r\n");
						clientSocket.flush();
					} else {
						clientSocket.writeUTFBytes("ERROR\r\n");
						clientSocket.flush();
					}
					break;
				
				case "EJECT":
				
					if (transitionToScreensaver()) {
						clientSocket.writeUTFBytes("OK\r\n");
						clientSocket.flush();
						trace("eject ok");
						
					} else {
						//clientSocket.writeUTF("ERROR\r\n");
					}
					break;
				
				default:
					//null - server
					clientSocket.writeUTFBytes("OK\r\n");
					clientSocket.flush();
					
					var file:Array = command_call.split(":");
					
					trace(file);
					//if (transitionToStream(new VideoStreamer(server + command_type, command_call))) {
					
					if (transitionToStream(new VideoStreamer(null, file[1]))) {
						// clientSocket.writeUTF("OK\r\n");
					} else {
						//clientSocket.writeUTF("ERROR\r\n");
					}
					break;
			}
		}
		
		private function transitionToScreensaver():Boolean
		{
			trace("screensaver requested");
			if (tl.isActive()) { 
				trace("screensaver requested but transition is active");
				return false;
			}
			
			if(inTransition) {
				trace("screensavers requested but transition is active");
				return false;
			}
			
			if (currentStream == screensaverStream) {
				trace("screensaver requested but its already on");
				return true;
			}
			
			// this
			//screensaverStream.ns.resume();
			inTransition = true;
			screensaverStream.ns.seek(0);
			
			_transitionToScreenSaver(screensaverStream);
		
			
			return true;
		}
		

		private function transitionToStream(nextStream:VideoStreamer):Boolean
		{
			trace("debug");
			//_transitionToReadyStream(nextStream);
			
			if(inTransition) {
				trace("requested vide but in trantision");
				return false;
			}
			var listFunc:Function;
			nextStream.addEventListener(VideoStatusEvent.VIDEO_STATUS, 
				listFunc =  function(event:VideoStatusEvent):void {
				trace(event.status + " is status");
				if (event.status == "Video.Play.Ready") {
					trace("ready to transition");
					inTransition = true;
					_transitionToReadyStream(nextStream);
				//	return true;
					
				} else if (event.status == "Video.Play.Failed") {
					trace("failed");
					//added
					nextStream.removeEventListener(VideoStatusEvent.VIDEO_STATUS,listFunc);
					nextStream.removeEventListener(VideoStatusEvent.VIDEO_STATUS,listFunc);
					//if (clientSocket != null) clientSocket.writeUTF("ERROR");
					//transitionToScreensaver()
				}  else if (event.status == "Video.Play.Stopped") {
					trace("stopped2s");
					//transitionToHomescreen();
					nextStream.removeEventListener(VideoStatusEvent.VIDEO_STATUS,listFunc);
					nextStream.removeEventListener(VideoStatusEvent.VIDEO_STATUS,listFunc);
					transitionToScreensaver();
					//added
					
				}
			});
			
			return true;
		}
		

		private function _transitionToScreenSaver(nextStream:VideoStreamer):void
		{
			trace("transition to screen saver");
			backSprite.alpha = 1.0;
			currentStream.ns.soundTransform = new SoundTransform(0);
			tl = new TimelineMax({paused:false});
			
			frontVideo.attachNetStream(nextStream.ns);
			//screensaverStream.ns.soundTransform = new SoundTransform(1);
			currentStream.close();
			
			currentStream = screensaverStream;
			nextStream.ns.soundTransform = new SoundTransform(1);
		
			tl.append(new TweenMax(nextStream.ns, 0.5, { volume: 1.0 }));
			
			nextStream.ns.resume();
			inTransition = false;
		}
		
		private function _transitionToReadyStream(nextStream:VideoStreamer):void
		{
			trace("transition ready stream");
			backSprite.alpha = 1.0;
			tl = new TimelineMax({paused:false});
		
			//var streamtoTransition:VideoStreamer;
			var vdelay:Number = 0;
				// if screenssaver  use a different transitions
			if (currentStream == screensaverStream) {
				trace("transition");
				
			//	streamtoTransition = transitiontoVideoStream;
				vdelay = 3.5
					
					
				videos[back].attachNetStream(transitiontoVideoStream.ns);
				
				videos[back].width = 1920;
				videos[back].height = 1080;
				
				currentStream.ns.soundTransform = new SoundTransform(0);
				nextStream.ns.soundTransform = new SoundTransform(1);
				
				
				stage.addChild(backSprite);	// bring to front
				backSprite.width = 1920;
				backSprite.height = 1080;
				
				//nextStream.ns.seek(0);
				
				tl.append(new TweenMax(transitiontoVideoStream.ns, 0.5, { volume: 1.0 }));
				
				tl.append(new TweenMax(frontSprite, 0.2, { delay:vdelay,
					onStart:function():void {
						trace("on init");
						//frontVideo.alpha = 0;
						frontVideo.attachNetStream(nextStream.ns);
						stage.addChild(frontSprite);
						currentStream.close();
						currentStream = nextStream;
					} }));
				tl.append(new TweenMax(transitiontoVideoStream.ns, 0.5, { volume: 0 }));
				// tween to front
				//[new TweenMax(nextStream.ns, 0.1, { volume: 1, overwrite: false }),
				tl.insertMultiple([new TweenMax(backSprite, 0.5, {  delay:0,alpha: 0.0, overwrite: false }),
					new TweenMax(frontSprite, 0.5, {  delay:0,alpha: 1.0, overwrite: false, onComplete:
						function():void { 
							trace("close transition stream");
							transitiontoVideoStream.close(); 
							inTransition = false;
							nextStream = null;
						}
					})],
					transitiontoVideoStream.duration);
				
				
				
				transitiontoVideoStream.ns.resume();
				
				
			} else {
				
			//	streamtoTransition = transitionStream;
				vdelay = 3.0
					
				videos[back].attachNetStream(transitionStream.ns);
				
				videos[back].width = 1920;
				videos[back].height = 1080;
				
				currentStream.ns.soundTransform = new SoundTransform(0);
				nextStream.ns.soundTransform = new SoundTransform(1);
				
				
				stage.addChild(backSprite);	// bring to front
				backSprite.width = 1920;
				backSprite.height = 1080;
				
				//nextStream.ns.seek(0);
				
				tl.append(new TweenMax(transitionStream.ns, 0.5, { volume: 1.0 }));
				
				tl.append(new TweenMax(frontSprite, 0.6, { delay:vdelay,
					onStart:function():void {
						trace("on init");
						//frontVideo.alpha = 0;
						frontVideo.attachNetStream(nextStream.ns);
						stage.addChild(frontSprite);
						currentStream.close();
						currentStream = nextStream;
					} }));
				tl.append(new TweenMax(transitionStream.ns, 0.5, { volume: 0 }));
				// tween to front
				//[new TweenMax(nextStream.ns, 0.1, { volume: 1, overwrite: false }),
				tl.insertMultiple([new TweenMax(backSprite, 0.5, {  delay:0,alpha: 0.0, overwrite: false }),
					new TweenMax(frontSprite, 0.5, {  delay:0,alpha: 1.0, overwrite: false, onComplete:
						function():void { 
							trace("close transition stream");
							transitionStream.close(); 
							inTransition = false;
							nextStream = null;
						}
					})],
					transitionStream.duration);
				
			
				
				transitionStream.ns.resume();
			}
			
	
			
		}
		
		private function keyDown(event:KeyboardEvent):void {
			switch (event.keyCode) {
				case Keyboard.F:
					if (stage.displayState == StageDisplayState.NORMAL)
						stage.displayState = StageDisplayState.FULL_SCREEN_INTERACTIVE;
					else
						stage.displayState = StageDisplayState.NORMAL
					break;
				case Keyboard.C:
					trace("clear");
					
					System.gc();
					System.gc();
					break
				case Keyboard.T:
					trace("memory free ", System.freeMemory/1048576);
					trace("memory private ", System.privateMemory/1048576);
					trace("memory total ", System.totalMemory/1048576);
					break
				
				case Keyboard.S:
					transitionToScreensaver();
					break
				case Keyboard.K:
					clientSocket.writeUTF("HELLO\r\n");
					break
				
				case Keyboard.SPACE:
					var newStreamName:String = (currentStream.streamName == streamName1) ? streamName2 : streamName1;
					trace("switching to " + newStreamName);
					//null - server
					transitionToStream(new VideoStreamer(server+ "live", newStreamName));
					break;
			}
		}
	}
}