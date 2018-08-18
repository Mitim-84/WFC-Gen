package;
import haxe.ds.Vector;
import openfl.display.Bitmap;
import openfl.display.BitmapData;
import openfl.display.Sprite;
import openfl.geom.Matrix;
import openfl.geom.Point;
import openfl.geom.Rectangle;



// this class will make the patterns out of the input as well as create the overlap mapping
class PatternGenerator {
	
	// overlap rules
	// index goes: <input pattern><offset index><other pattern index>
	// example: <4><1><8> means pattern 4, offset at -1, 0 (collapsed down to a single index following a formula), with pattern 8
	// returns a boolean saying if it is allowed or not
	private var overlapRules:Vector<Vector<Vector<Bool>>>;
	
	// patterns, an array as it's unknown how many unique patterns there will be
	private var patterns:Array<BitmapData>;
	
	private var patternFrequencies:Array<Int>;
	
	// generating options
	public var rotationsAndReflections:Bool;
	public var wrappingInput:Bool;
	public var usePatternWeighting:Bool;
	
	private var patternSize:Int;
	private var minOffset:Int;
	private var maxOffset:Int;
	private var offsetRange:Int;
	
	
	public function new():Void {
		rotationsAndReflections = true;
		wrappingInput = true;
		usePatternWeighting = true;
	}
	
	public function getPatterns():Array<BitmapData> {					return this.patterns;				}
	public function getPatternFrequencies():Array<Int> {				return this.patternFrequencies;		}
	public function getOverlapRules():Vector<Vector<Vector<Bool>>> {	return this.overlapRules;			}
	public function getPatternAmount():Int {							return this.patterns.length;		}
	public function getPatternSize():Int {								return this.patternSize;			}
	
	public function gen(size:Int, inputBitmap:BitmapData):Void {
		patternSize = size;
		minOffset = (patternSize - 1) * -1;
		maxOffset = (patternSize - 1);
		offsetRange = ((patternSize - 1) * 2) + 1;
		
		createPatterns(patternSize, inputBitmap);
		buildOverlapRules();
	}
	
	
	// assumes the output patterns are square, though the inputBitmap may not be a square
	private function createPatterns(inputSize:Int, inputBitmap:BitmapData):Void {
		
		patterns = new Array<BitmapData>();
		patternFrequencies = new Array<Int>();
		
		var zeroPoint:Point = new Point();
		var copyRect:Rectangle = new Rectangle(0, 0, inputSize, inputSize);
		
		
		var source:BitmapData = inputBitmap;
		
		// if the input is wrapping, tile the source input 2x so it'll wrap
		if(wrappingInput == true){
			copyRect = new Rectangle(0, 0, inputBitmap.width, inputBitmap.height);
			
			source = new BitmapData(inputBitmap.width * 2, inputBitmap.height * 2, false, 0x75E9EC);
			source.copyPixels(inputBitmap, copyRect, zeroPoint);
			
			zeroPoint.x = inputBitmap.width;
			source.copyPixels(inputBitmap, copyRect, zeroPoint);
			
			zeroPoint.y = inputBitmap.height;
			source.copyPixels(inputBitmap, copyRect, zeroPoint);
			
			zeroPoint.x = 0;
			source.copyPixels(inputBitmap, copyRect, zeroPoint);
			
			copyRect = new Rectangle(0, 0, inputSize, inputSize);
			zeroPoint = new Point();
		}
	
	var patternSize:Int = wrappingInput ? 1 : inputSize;
	var xLimit:Int = (inputBitmap.width - patternSize + 1);
	var yLimit:Int = (inputBitmap.height - patternSize + 1);
	
		var temp:BitmapData;
		// create new patterns by copying pixels out of the original input bitmap
		for(offsetY in 0...yLimit){
			for(offsetX in 0...xLimit){
				temp = new BitmapData(inputSize, inputSize);
				copyRect.x = offsetX;
				copyRect.y = offsetY;
				temp.copyPixels(inputBitmap, copyRect, zeroPoint);
				
				addPattern(temp);
				
				if(rotationsAndReflections == true){
					
					var rotate:Matrix = new Matrix();
					var reflect:Matrix = new Matrix();
					
					reflect.scale(-1, 1);
					reflect.translate(inputSize, 0);
					
					// need to figure this out, need to generate a reflection from all the rotations And the orignal
					var patternReflected:BitmapData = new BitmapData(inputSize, inputSize);
					patternReflected.draw(temp, reflect);
					addPattern(patternReflected);
					
					for(counter in 0...3){
						rotate.rotate(Math.PI / 2);
						rotate.translate(inputSize, 0);
						
						var inputPatternRotated:BitmapData = new BitmapData(inputSize, inputSize);
						inputPatternRotated.draw(temp, rotate);
						addPattern(inputPatternRotated);
						
						var patternReflected:BitmapData = new BitmapData(inputSize, inputSize);
						patternReflected.draw(inputPatternRotated, reflect);
						addPattern(patternReflected);
						
					} // end of for loop (counter in 0...3)
				} // end of if statement (rotations == true)
				
			} // end of for loop offsetX
		} // end of for loop offsetY
	} // end of createPatterns()
	
	// helper method for createPatterns(), will either add the pattern for update its frequency
	private function addPattern(inputPattern:BitmapData):Void {
		var temp:Int = containsPattern(inputPattern, patterns);
		if(temp == -1){
			patterns.push(inputPattern);
			patternFrequencies.push(1);
		} else {
			patternFrequencies[temp] += usePatternWeighting ? 1 : 0;
		}
	}
	
	// helper method for seeing if a BitmapData is contained in an array of BitmapData's
	private function containsPattern(inputPattern:BitmapData, patterns:Array<BitmapData>):Int {
		for(pattern in 0...patterns.length){
			// note that compare() can also return a BitmapData object if the results don't match...which != 0 so it still works
			// but could be a source of type errors
			if(patterns[pattern].compare(inputPattern) == 0){
				return pattern;
			}
		}
		return -1;
	}
	
	// mirrored in OutputGenerator for now
	// helper method for getting a flat index out of a pair of coords (unique based on the total offset range of x and y)
	private function getOffsetIndex(inputX:Int, inputY:Int):Int {
		return (inputX + maxOffset) + ((inputY + maxOffset) * offsetRange);
	}
	
	
	// should go through each offset coord and at each one, check if a pattern matches
	private function buildOverlapRules():Void {
		
		// index goes: <input pattern><offset index><other pattern index>
		overlapRules = new Vector<Vector<Vector<Bool>>>(patterns.length);
		
		for(patternIndex in 0...patterns.length){
			overlapRules[patternIndex] = new Vector<Vector<Bool>>(offsetRange * offsetRange);
			
			for(yOffset in minOffset...(maxOffset + 1)){
				for(xOffset in minOffset...(maxOffset + 1)){
					// a bit inefficent here as checkOverlaps() runs "patterns.length" times with the same numbers, though it should only be a very small loss
					overlapRules[patternIndex][getOffsetIndex(xOffset, yOffset)] = checkOverlaps(patternIndex, xOffset, yOffset);
				}
			}
		}
	} // end of buildOverlapRules()
	
	// can make a more efficent method that handles multiple offset patterns and returns an array instead...
	// checks the overlap for a pattern with another pattern with an offset on the second pattern
	private function checkOverlaps(mainPatternIndex:Int, offsetX:Int, offsetY:Int):Vector<Bool> {
		
		// slice size x/y
		var sliceWidth:Int = Std.int(-Math.abs(offsetX) + patternSize);
		var sliceHeight:Int = Std.int(-Math.abs(offsetY) + patternSize);
		
		// overlapping slice start x/y (main pattern)
		var mainSliceStartX:Int = Std.int(Math.max(offsetX, 0));
		var mainSliceStartY:Int = Std.int(Math.max(offsetY, 0));
	
		// overlapping slice start x/y (offset/other pattern)
		var otherSliceStartX:Int = Std.int(Math.abs(Math.min(offsetX, 0)));
		var otherSliceStartY:Int = Std.int(Math.abs(Math.min(offsetY, 0)));
		
		var zeroPoint:Point = new Point();
		
		var mainPatternSlice:BitmapData = new BitmapData(sliceWidth, sliceHeight);
		var offsetPatternSlice:BitmapData = new BitmapData(sliceWidth, sliceHeight);
		
		var rect:Rectangle = new Rectangle(mainSliceStartX, mainSliceStartY, sliceWidth, sliceHeight);
		mainPatternSlice.copyPixels(patterns[mainPatternIndex], rect, zeroPoint);
		
		rect.x = otherSliceStartX;
		rect.y = otherSliceStartY;
		
		// changed from the above to figure out all the patterns for an offset (so don't have to constantly recalculate it)
		var result:Vector<Bool> = new Vector<Bool>(patterns.length);
		for(counter in 0...patterns.length){
			offsetPatternSlice.copyPixels(patterns[counter], rect, zeroPoint);
			result[counter] = ((mainPatternSlice.compare(offsetPatternSlice)) == 0);
		}
		return result;
		
	} // end of checkOverlaps()
	
	
} // end of PatternGenerator{} class




