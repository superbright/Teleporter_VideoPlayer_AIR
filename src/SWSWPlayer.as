package
{
	import com.greensock.TimelineMax;
	import com.greensock.TweenMax;
	import com.greensock.plugins.ShortRotationPlugin;
	import com.greensock.plugins.TransformAroundCenterPlugin;
	import com.greensock.plugins.TransformAroundPointPlugin;
	import com.greensock.plugins.TweenPlugin;
	
	import flash.system.System;
	TweenPlugin.activate([ShortRotationPlugin, TransformAroundCenterPlugin, TransformAroundPointPlugin]);
	

	import flash.display.Sprite;
	import flash.display.StageAlign;
	import flash.display.StageDisplayState;
	import flash.display.StageScaleMode;
	import flash.events.Event;
	import flash.events.IOErrorEvent;
	import flash.events.KeyboardEvent;
	import flash.events.ProgressEvent;
	import flash.events.SecurityErrorEvent;
	import flash.events.ServerSocketConnectEvent;
	import flash.media.SoundTransform;
	import flash.media.Video;
	import flash.net.ServerSocket;
	import flash.net.Socket;
	import flash.ui.Keyboard;
	import flash.utils.ByteArray;
	import flash.system.System;
	
	[SWF(backgroundColor="0x000000")];
	
	public class SWSWPlayer extends Sprite
	{
	
		private var screensaverStreamFile:String = "screensaver.mp4";
		private var frontVideo:Video;
		private var backVideo:Video;
		//private var front:int = 0;
		//private var back:int = 1;
		
		private var transition:Sprite;
		private var frontSprite:Sprite;
		private var backSprite:Sprite;
		
		// static videos
		private var transitionStream:VideoStreamer;
		private var screensaverStream:VideoStreamer;
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
			frontVideo = new Video(1920,1200);
			backVideo = new Video(1920,1200);
			
			
			
			currentStream = screensaverStream = new VideoStreamer(null, screensaverStreamFile,false);
			screensaverStream.addEventListener(VideoStatusEvent.VIDEO_STATUS, function(event:VideoStatusEvent):void {
				if (event.status == "Video.Play.Ready") {
					frontVideo.attachNetStream(currentStream.ns);
					screensaverStream.ns.soundTransform = new SoundTransform(1);
				}
			});
	
			// setup stage
			stage.frameRate = 30;
			frontSprite.addChild(frontVideo);
			backSprite.addChild(backVideo);
			stage.addChild(frontSprite);
			
			//frontSprite.width = 1728;
			//frontSprite.height = 1080;
			//frontSprite.x = 96;
			frontSprite.scaleX = frontSprite.scaleY;
			
			// trick to move the registration point so scaling and rotation for videos happens from center
			//sprites[0].x = sprites[1].x = stage.width/2;
			//sprites[0].y = sprites[1].y = stage.height/2;
		
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
			//trace("bytes available " + clientSocket.bytesAvailable);
			var str:String = buffer.toString(); //clientSocket.readUTF();
			trace("Received: " + str);
			
			var commands:Array = str.split("&");
			
			var command_type = commands[0];
			var command_call = commands[1];
			
			trace(command_call);
			switch (command_call) {
				case "START":
					if( transitionToScreensaver()) {
						if(clientSocket && clientSocket.connected) {
							clientSocket.writeUTFBytes("OK\r\n");
							clientSocket.flush();
						}
					} else {
						if(clientSocket && clientSocket.connected) {
							clientSocket.writeUTFBytes("ERROR\r\n");
							clientSocket.flush();
						}
					}
					break;
				
				case "EJECT":
				
					if (transitionToScreensaver()) {
						if(clientSocket && clientSocket.connected) {
							clientSocket.writeUTFBytes("OK\r\n");
							clientSocket.flush();
						}
						//trace("eject ok");
						
					} else {
						if(clientSocket && clientSocket.connected) {
							clientSocket.writeUTF("ERROR\r\n");
							clientSocket.flush();
						}
					}
					break;
				
				default:
					//file[1]
					var file:Array = command_call.split(":");
					if(transitionToStream(new VideoStreamer(null,file[1]))) {
						//clientSocket.writeUTFBytes("OK\r\n");
						//clientSocket.flush();
					} else {
						if(clientSocket && clientSocket.connected) {
							clientSocket.writeUTFBytes("ERROR\r\n");
							clientSocket.flush();
						}
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
			
			inTransition = true;
			screensaverStream.ns.seek(0);
			_transitionToScreenSaver(screensaverStream);
			return true;
		}
		

		private function transitionToStream(nextStream:VideoStreamer):Boolean
		{
			//trace("debug");
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
					inTransition = true;
					playVideo(nextStream);
					
				} else if (event.status == "Video.Play.Failed") {
					trace("failed");
					//added
					nextStream.removeEventListener(VideoStatusEvent.VIDEO_STATUS,listFunc);
					nextStream.removeEventListener(VideoStatusEvent.VIDEO_STATUS,listFunc);
					//if (transitionToScreensaver()) {
						
						trace("eject ok");
					//}
				}  else if (event.status == "Video.Play.Stopped") {
					trace("stopped video");
					//transitionToHomescreen();
					nextStream.removeEventListener(VideoStatusEvent.VIDEO_STATUS,listFunc);
					nextStream.removeEventListener(VideoStatusEvent.VIDEO_STATUS,listFunc);
				
					if (transitionToScreensaver()) {
						//clientSocket.writeUTFBytes("EJECT\r\n");
						//clientSocket.flush();
						trace("eject ok");
					}
					//added
					
				}
			});
			
			return true;
		}
		

		private function _transitionToScreenSaver(nextStream:VideoStreamer):void
		{
			trace("transition to screen saver");
			frontSprite.alpha = 0.0;
			//currentStream.ns.soundTransform = new SoundTransform(0);
			tl = new TimelineMax({paused:false});
			//frontVideo.attachNetStream(nextStream.ns);
			screensaverStream.ns.soundTransform = new SoundTransform(1);
			stage.addChild(frontSprite);
			
			nextStream.ns.resume();
			
			if(clientSocket && clientSocket.connected) {
				clientSocket.writeUTFBytes("EJECT\r\n");
				clientSocket.flush();
			}
			
			//tl.append(new TweenMax(nextStream.ns, 0.5, { volume: 1.0 }));
			
			
			tl.append(new TweenMax(frontSprite, 0.2, { alpha:1.0,
				onComplete:function():void {
					trace("on complete");
					stage.removeChild(backSprite);
					//currentStream.close();
					currentStream.ns.close();
					currentStream = null;
					currentStream = screensaverStream;
					//nextStream.ns.soundTransform = new SoundTransform(1);
					inTransition = false;
					
				} }));
			

			
		}
		private function playVideo(nextStream:VideoStreamer):void {
			
			tl = new TimelineMax({paused:false});
			backVideo.attachNetStream(nextStream.ns);
			backSprite.alpha = 0;
			stage.addChild(backSprite);	// bring to front
			currentStream.ns.soundTransform = new SoundTransform(0);
			nextStream.ns.soundTransform = new SoundTransform(1);
			tl.append(new TweenMax(backSprite, 3, { alpha:1.0,
				onComplete:function():void {
					trace("on complete");
					stage.removeChild(frontSprite);
					currentStream.ns.close();
					currentStream = null;
					currentStream = nextStream;
					inTransition = false;
					
				} }));
//			tl.append(new TweenMax(frontSprite, 0.1, { delay:0,  //(frontSprite, 0.2, { delay:5,
//				onComplete:function():void {
//					trace("on complete");
//				
//					//nextStream.close();
//				} }));
			
			
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
					if(!inTransition) {
						//inTransition = true;
						  transitionToStream(new VideoStreamer(null,"Tour.mp4",false))
					}
					//var newStreamName:String = (currentStream.streamName == streamName1) ? streamName2 : streamName1;
					//trace("switching to " + newStreamName);
					//null - server
					//transitionToStream(new VideoStreamer(server+ "live", newStreamName));
					break;
			}
		}
	}
}
