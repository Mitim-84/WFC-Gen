package;
import haxe.ds.Vector;
import openfl.display.BitmapData;


class OutputGenerator {
	
	public var wrapping:Bool;
	
	private var output:Vector<Vector<Wave>>;
	private var bounds:PointInt;
	
	private var patternSize:Int;
	private var minOffset:Int;
	private var maxOffset:Int;
	private var offsetRange:Int;
	
	private var overlapRules:Vector<Vector<Vector<Bool>>>;
	private var patternAmount:Int;
	
	
	private var cellIterator:CellIterator;
	private var neighbourIterator:NeighbourIterator;
	
	private var iCount:Int;
	private var genInProgress:Bool;
	
	private var cellsThatNeedUpdating:Array<PointInt>;
	private var pos:PointInt;
	
	public function new():Void {
		wrapping = true;
	}
	
	
	// 1.) create an output of waves based on an input size
	// 2.) collapse a random point and do step 4 with that point
	// 3.) find lowest non-zero entropy, in case of a tie, randomly choose 1 (noise is added to each wave's entropy to easily break ties)
	// 4.) collapse it from a set of possibilities down to 1 and add to an update list for the propagation step
	// 5.) propagate this wave's change through it's neighbours:
	//	   For each neighbour, check the neighbour patterns to see if it still matches with any of the current cell's patterns
	//	   If none of the neighbour's patterns match with any of the current cell's patterns, remove it and add to an update list
	//	   Once the current wave of propagations are done, process the update list, repeating propagation on the update list until 
	//	   no more updates need to be made
	// 6.) repeat steps 2 to 5:
	//     - until lowest entropy is zero as it would mean there are no more uncollapsed waves
	//     - or if entropy less then zero has been found as that would mean a paradox/contradiction
	//
	// Note that the algorithm's execution has been split up in to multiple methods to be called externally to do work (as opposed to being in a loop)
	// This is to allow the execution to return to the main thread to avoid locking up/hitting the execution limit in flash.
	// Needed this algorithm can be very slow and there can be many things needed to be done during propagation.
	//
	// startGen() starts the process, then repeated calls of processStep() need to be done until it returns false
	public function startGen(inputSizeX:Int, inputSizeY:Int, patternGenerator:PatternGenerator, inputSeed:Int = -1):Void {
		
		genInProgress = true;
		
		patternSize = patternGenerator.getPatternSize();
		maxOffset = (patternSize - 1); // used to calculate the offset index
		offsetRange = ((patternSize - 1) * 2) + 1; // used to calculate the offset index
		
		patternAmount = patternGenerator.getPatternAmount();
		overlapRules = patternGenerator.getOverlapRules();
		
		var noise:BitmapData = new BitmapData(inputSizeX, inputSizeY);
		var seed:Int = inputSeed == -1 ? Math.floor(Math.random() * 999999999) : inputSeed;
		trace("startGen() - Using seed: " + seed);
		noise.noise(seed);
		
		// looks like list comps are backwards compared to python, but are not available for Vectors....
		//var temp:Array<Array<Wave>> = [for (y in 0...5) [for(x in 0...10) new Wave(0)]];
		output = new Vector<Vector<Wave>>(inputSizeY);
		bounds = new PointInt(inputSizeX, inputSizeY);
		
		cellIterator = new CellIterator(bounds);
		neighbourIterator = new NeighbourIterator(maxOffset);
		
		for(y in 0...bounds.y){
			output[y] = new Vector<Wave>(bounds.x);
			
			for(x in 0...bounds.x){
				output[y][x] = new Wave(patternAmount, (noise.getPixel(x, y) / 0xffffff), patternGenerator.getPatternFrequencies());
			}
		}
		
		cellsThatNeedUpdating = new Array<PointInt>();
		
		iCount = 0;
		
	} // end of gen() method }
	
	// false mean it's done, true means there is still more work to do before generation is done
	// this method and processNextStep() does the main work of the algorthim bit by bit everytime it is called
	public function processStep():Bool {
		// check if the current propagation step's cells are done updating
		// if not, finish those before executing another new iteration of the algorithm
		if(cellsThatNeedUpdating.length == 0){
			return processNextStep();
		} else {
			cellsThatNeedUpdating = propagateCollapse(cellsThatNeedUpdating);
			return true;
		}
	}
	
	// false mean it's done, true means there is still more work to do before generation is done
	private function processNextStep():Bool {
		
		if(genInProgress == false){
			return false;
		}
		
		pos = findLowestEntropy();
		
		if(pos == null){
			trace("can't find lowest entropy");
			
			genInProgress = false;
			trace("gen end / gen loop ran "+ iCount +" times");
			return false;
			
		} else {
			output[pos.y][pos.x].collapse();
			cellsThatNeedUpdating.push(pos);
		}
		iCount++;
		
		return true;
	}
	
	
	public function getCell(pos:PointInt):Wave {
		return output[pos.y][pos.x];
	}
	
	
	// mirrored in PatternGenerator for now
	// helper method for getting a flat index out of a pair of coords (unique based on the total offset range of x and y)
	private function getOffsetIndex(inputX:Int, inputY:Int):Int {
		return (inputX + maxOffset) + ((inputY + maxOffset) * offsetRange);
	}
	
	
	private function propagateCollapse(inputCells:Array<PointInt>):Array<PointInt> {
		var cellsThatNeedUpdating:Array<PointInt> = new Array<PointInt>();
		
		var currentPos:PointInt;
		var pos:PointInt;
		
		while(inputCells.length > 0){
			pos = inputCells.pop();
			
			for(neighbourPos in neighbourIterator.restart(pos)){
				
				// need to calculate this first as if neighbourPos get's wrapped around, it'll screw up this value
				var offsetIndex:Int = getOffsetIndex(neighbourPos.x - pos.x, neighbourPos.y - pos.y);
				
				if(neighbourPos.isValid(bounds) == false){
					if(wrapping == true){
						neighbourPos.wrapIndexes(bounds); // no wrapping for now, need to be sure this doesn't accidentally modify the iterator
						// should be okay, since a proxy of a PointInt is returned, not the direct PointInt used internally within the iterator
					} else {
						continue;
					}
				}
				
				if(output[neighbourPos.y][neighbourPos.x].collapsed == true){
					continue;
				}
				
				for(neighbourPattern in 0...patternAmount){
					
					if(output[neighbourPos.y][neighbourPos.x].hasPossibility(neighbourPattern) == false){
						continue;
					}
					
					var valid:Bool = false;
					
					for(currentCellPattern in 0...patternAmount){
						if(output[pos.y][pos.x].hasPossibility(currentCellPattern) == true){
							var rule:Bool = overlapRules[currentCellPattern][offsetIndex][neighbourPattern];
							valid = valid || rule;
							
							// only looking for patterns that no longer match, thus if any match is found, can stop checking
							if(valid == true){
								break;
							}
						}
					}
					
					// if "valid" is still false, this means that current neighbour pattern does not match with Any of the current cell
					// this need to remove thid pattern from the neighbour
					if(valid == false){
						output[neighbourPos.y][neighbourPos.x].removePossibility(neighbourPattern);
						
						if(contains(cellsThatNeedUpdating, neighbourPos) == false){
							cellsThatNeedUpdating.push(neighbourPos.clone());
						}
					}
				} // for loop (currentCellPattern)
			}
		} // end of for loop (pos in cells)
		
		return cellsThatNeedUpdating;
	} // end of propagateCollapse() method }
	
	private function contains(inputList:Array<PointInt>, thing:PointInt):Bool {
		for(item in inputList){
			if((thing.x == item.x) && (thing.y == item.y)){
				return true;
			}
		}
		return false;
	}
	
	// not sure if this is done correctly, (logic may be different in other implementations)
	// returning null will stop the algorithm
	private function findLowestEntropy():PointInt {
		var result:PointInt = new PointInt(-1, -1);
		var currentLowest:Float = patternAmount + 1;
		
		for(pos in cellIterator.restart()){
			
			// ignore collapsed waves
			if(output[pos.y][pos.x].entropy > 0){
				
				if(output[pos.y][pos.x].entropy < currentLowest){
					currentLowest = output[pos.y][pos.x].entropy;
					result.x = pos.x;
					result.y = pos.y;
				}
			} else if(output[pos.y][pos.x].entropy < 0){
				trace("found contradiction");
				return null;
			}
		}
		
		if((result.x == -1) && (result.y == -1)){
			return null;
		} else {
			return result;
		}
	}
	
	
	// debug method here
	public function dump(inputString:String = ""):Void {
		var result:String = "Dump ("+ inputString +"):\n";
		var columnSize:Int = 5;
		var spacing:Int = 2;
		
		result += StringTools.lpad("", " ", columnSize);
		
		for(x in 0...bounds.x){
			result += StringTools.lpad(Std.string(x), " ", columnSize + spacing);
		}
		result += "\n";
		result += StringTools.lpad("", "-", (columnSize + spacing) * (bounds.x + 1));
		result += "\n";
		
		for(y in 0...bounds.y){
			
			result += StringTools.lpad(Std.string(y) + " | " , " ", columnSize);
			
			for(x in 0...bounds.x){
				
				result += StringTools.lpad("", " ", spacing);
				
				if(output[y][x].collapsed == true){
					result += "  0  ";
					
				} else {
					var temp:String = StringTools.lpad(Std.string(output[y][x].entropy), " ", columnSize);
					result += temp.substr(0, columnSize);
				}
			}
			result += "\n";
		}
		trace(result);
	} // end dump() method }
	
} // end of OutputGenerator{} class