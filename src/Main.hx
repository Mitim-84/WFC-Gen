package;

import haxe.ds.Vector;
import openfl.display.Bitmap;
import openfl.display.JPEGEncoderOptions;
import openfl.display.PNGEncoderOptions;
import openfl.display.Sprite;
import openfl.Lib;
import openfl.display.BitmapData;
import openfl.events.Event;
import openfl.geom.Point;
import openfl.geom.Rectangle;
import openfl.net.URLLoader;
import openfl.net.URLRequest;
import openfl.net.URLRequestHeader;
import openfl.net.URLRequestMethod;
import openfl.text.TextField;
import openfl.text.TextFormat;
import openfl.utils.ByteArray;


class Main extends Sprite {
	
	private var SAMPLE_POS:Int = 1; // sample (1, 1) from the a pattern (used to draw the output)
	private var OUTPUT_DISPLAY_SCALE:Int = 10;
	
	private var scale:Int = 5;
	
	private var patternGenerator:PatternGenerator;
	private var patterns:Array<BitmapData>;
	
	private var outputGenerator:OutputGenerator;
	
	private var patternSize:Int = 2;
	private var rotationsAndReflections:Bool = true;
	private var wrappingOutput:Bool = true;
	private var wrappingInput:Bool = false;
	private var usePatternWeighting:Bool = true;
	
	private var outputSize:PointInt;
	private var displayOffset:Point;
	
	// for showing the animated result
	private var progressFrames:Array<Bitmap>;
	private var currentFrame:Int;
	
	private var currentSeed:Int;
	
	private var display:TextField;
	private var progressSteps:Int;
	
	private var currentResultDisplay:Bitmap;
	
	public function new() {
		super();
		
		// can try various sizes
		outputSize = new PointInt(20, 20);
		//outputSize = new PointInt(5, 5);
		//outputSize = new PointInt(10, 10);
		//outputSize = new PointInt(25, 25);
		//outputSize = new PointInt(30, 30);
		//outputSize = new PointInt(50, 50); // this can take a long time...
		
		// can try various inputs (images are in the assets/img directory)
		var imageURL:String = "red.png";
		//imageURL = "checker.png";
		//imageURL = "flowers.png";
		//imageURL = "Simple Maze.png";
		//imageURL = "Hogs.png";
		//imageURL = "Knot.png";
		//imageURL = "Simple Wall.png";
		//imageURL = "Scaled Maze.png";
		//imageURL = "Platformer.png";
		//imageURL  = "Village.png";
		//imageURL = "Dungeon.png";
		
		// can try various options
		wrappingOutput = true;
		wrappingInput = true;
		rotationsAndReflections = true;
		usePatternWeighting = true;
		patternSize = 2;
		//patternSize = 3;
		
		currentSeed = -1; // use -1 for random seed
		
		
		
		
		// display a running counter to show progress (or just to tell the viewer that it hasn't frozen/crashed)
		display = new TextField();
		var textFormat:TextFormat = new TextFormat("verdana", 16);
		display.setTextFormat(textFormat);
		display.x = 10;
		display.y = this.stage.stageHeight - 25;
		this.addChild(display);
		
		
		var bitmapData:BitmapData = openfl.Assets.getBitmapData("img/"+ imageURL);
		var bitmap:Bitmap = new Bitmap(bitmapData);
		bitmap.scaleX = bitmap.scaleY = scale;
		bitmap.x = bitmap.y = 10;
		this.addChild(bitmap);
		
		displayOffset = new Point(patternSize * scale, 100);
		displayOffset.y = 20 + (bitmap.y + bitmap.height);
		
		
		patternGenerator = new PatternGenerator();
		patternGenerator.wrappingInput = wrappingInput;
		patternGenerator.rotationsAndReflections = rotationsAndReflections;
		patternGenerator.usePatternWeighting = usePatternWeighting;
		
		patternGenerator.gen(patternSize, bitmapData);
		
		patterns = patternGenerator.getPatterns();
		
		trace("Found " + patterns.length +" unique patterns");
		trace("Frequencies: "+ patternGenerator.getPatternFrequencies());
		
		var currentX:Int = (bitmapData.width * scale) + 20;
		var currentY:Int = 10;
		
		// display the extracted patterns
		for(pattern in 0...patterns.length){
			bitmap = new Bitmap(patterns[pattern]);
			bitmap.x = currentX;
			bitmap.y = currentY;
			
			if(currentX >= (this.stage.stageWidth - (2 * (patternSize * scale + 10)))){
				currentX = (bitmapData.width * scale) + 20;
				currentY += (patternSize * scale + 10);
			} else {
				currentX += (patternSize * scale + 10);
			}
			
			bitmap.scaleX = bitmap.scaleY = scale;
			this.addChild(bitmap);
		}
		
		
		outputGenerator = new OutputGenerator();
		outputGenerator.wrapping = wrappingOutput;
		
		
		progressFrames = new Array<Bitmap>();
		
		outputGenerator.startGen(outputSize.x, outputSize.y, patternGenerator, currentSeed);
		progressSteps = 0;
		
		// do this just to avoid the initial "can't remove child" issue
		currentResultDisplay = new Bitmap();
		this.addChild(currentResultDisplay);
		
		this.addEventListener(Event.ENTER_FRAME, progressStep, false, 0, true);
		
	} // end of constructor }
	
	private function progressStep(inputEvent:Event):Void {
		
		// show every step
		this.removeChild(currentResultDisplay);
		currentResultDisplay = getCurrentResult();
		currentResultDisplay.x = displayOffset.x;
		currentResultDisplay.y = displayOffset.y;
		this.addChild(currentResultDisplay);
		
		progressFrames.push(new Bitmap(currentResultDisplay.bitmapData.clone()));
		
		// if false, then it means no more work is to be done / generation is finished
		if(outputGenerator.processStep() == false){
			this.removeEventListener(Event.ENTER_FRAME, progressStep, false);
			
			
			// do this in case the above step-by-step display is disabled
			this.removeChild(currentResultDisplay);
			currentResultDisplay = getCurrentResult();
			currentResultDisplay.x = displayOffset.x;
			currentResultDisplay.y = displayOffset.y;
			this.addChild(currentResultDisplay);
			
			// uncomment to export jpg files to a web script for saving
			/*for(frame in 0...progressFrames.length){
				exportFrame(progressFrames[frame], frame, "step");
			}*/
			
			if(progressFrames.length > 0){
				currentFrame = 0;
				this.addChild(progressFrames[currentFrame]);
				this.addEventListener(Event.ENTER_FRAME, animateProgressFrames, false, 0, true);
			}
			
		} else {
			progressSteps++;
			display.text = Std.string(progressSteps);
		}
	}
	
	/*
	This is used to "save" a jpg out of the flash environment by encoding the bitmap to a jpg and sending the byte data to a local web script for saving
	To get this to work, create a local webserver with a php script to save the binary data as a jpg
	example of a php script used:
	
	<?php
		$bin_str = file_get_contents("php://input");
		$fileName = "frames/frame". $_GET["name"] ."-". $_GET["i"] .".jpg";
		$file_w = fopen($fileName , "w+");
		fwrite($file_w, $bin_str);
		fclose($file_w);
	?>
	
	*/
	private function exportFrame(inputFrame:Bitmap, index:Int, name:String):Void {
		var bounds:Rectangle = inputFrame.getBounds(this);
		var exportSize:Int = outputSize.x * patternSize * scale;
		
		var temp:BitmapData = new BitmapData(exportSize, exportSize, false, 0xff00ff);
		temp.draw(inputFrame, null, null, null, bounds);
		
		var byteArray:ByteArray = temp.encode(new Rectangle(0, 0, exportSize, exportSize), new JPEGEncoderOptions()); //odd png encoder can't be found...
		
		var loader:URLLoader = new URLLoader();
		
		var header:URLRequestHeader = new URLRequestHeader("Content-type", "application/octet-stream");
		var request:URLRequest = new URLRequest("http://127.0.0.1/save.php?name="+ name +"-"+ currentSeed +"&i="+ index);
		request.requestHeaders.push(header);
		request.method = URLRequestMethod.POST;
		request.data = byteArray;
		loader.load(request);
	}
	
	
	private function animateProgressFrames(inputEvent:Event){
		this.removeChild(progressFrames[currentFrame]);
		currentFrame = (currentFrame + 1) % progressFrames.length;
		
		progressFrames[currentFrame].x = displayOffset.x + (patternSize * scale);
		progressFrames[currentFrame].x += (OUTPUT_DISPLAY_SCALE * outputSize.x) + (patternSize * scale);
		progressFrames[currentFrame].y = displayOffset.y;
		progressFrames[currentFrame].scaleX = progressFrames[currentFrame].scaleY = OUTPUT_DISPLAY_SCALE;
		this.addChild(progressFrames[currentFrame]);
	}
	
	
	private function getCurrentResult():Bitmap {
		var temp:BitmapData = new BitmapData(outputSize.x, outputSize.y);
		
		for(pos in new CellIterator(outputSize)){
			temp.setPixel(pos.x, pos.y, getAvgColour(outputGenerator.getCell(pos).possibilities));
		}
		
		var result:Bitmap = new Bitmap(temp);
		result.scaleX = result.scaleY = OUTPUT_DISPLAY_SCALE;
		return result;
	}
	
	private function getAvgColour(inputPatterns:Vector<Bool>):Int {
		var r:Int = 0;
		var g:Int = 0;
		var b:Int = 0;
		
		var amount:Int = 0;
		
		for (patternIndex in 0...inputPatterns.length){
			if(inputPatterns[patternIndex] == true){
				amount++;
				
				var colour:Int = patterns[patternIndex].getPixel(SAMPLE_POS, SAMPLE_POS);
				r += (colour & 0xff0000) >> 16 ;
				g += (colour & 0xff00) >> 8 ;
				b += (colour & 0xff);
			}
		}
		
		r = Math.floor(r / amount) << 16;
		g = Math.floor(g / amount) << 8;
		b = Math.floor(b / amount);
		
		return r | g | b;
	}
	
} // end of Main{} class
