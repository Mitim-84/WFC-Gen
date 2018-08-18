package;
import openfl.Vector;

class Wave {
	
	// https://haxe.org/manual/class-field-property-rules.html
	// https://haxe.org/manual/class-field-property-common-combinations.html
	@:isVar public var entropy(get, null):Float;
	@:isVar public var collapsed(get, null):Bool;
	@:isVar public var state(get, null):Int;
	
	// public so can access all the possibilites to generate the average pattern colour
	public var possibilities:Vector<Bool>;
	
	private var patternFrequencies:Array<Int>;
	
	private var noise:Float;
	
	public function new(size:Int, inputNoise:Float, inputPatternFrequencies:Array<Int>):Void {
		possibilities = new Vector(size);
		
		patternFrequencies = inputPatternFrequencies;
		
		noise = inputNoise;
		
		for(counter in 0...size){
			possibilities[counter] = true;
		}
		updateEntropy();
		this.state = -1;
	}
	
	public function hasPossibility(input:Int):Bool {
		return possibilities[input];
	}
	
	private function get_entropy():Float {
		return this.entropy + (noise * ((this.entropy > 0) ? 1 : 0));
	}
	
	private function get_collapsed():Bool {
		return (this.entropy < 1);
	}
	
	private function get_state():Int {
		return this.state;
	}
	
	public function removePossibility(index:Int):Float {
		
		if(possibilities[index] == true){
			possibilities[index] = false;
			return updateEntropy();
			
		} else {
			trace("Warning: Wave.removePossibility() - attempted to remove a culled possibility");
			return -1;
		}
	}
	
	private function updateEntropy():Float {
		// start at -1 as if there is only 1 possibility, then it should have an entropy of 0
		// 2 possibilities would have an entropy of 1, etc
		this.entropy = -1;
		
		var possibleState:Int = -1;
		
		for(index in 0...possibilities.length){
			if(possibilities[index] == true){
				this.entropy++;
				possibleState = index;
			}
		}
		
		// auto collapse if there is only one state left...
		if(this.entropy == 0){
			this.state = possibleState;
		}
		
		if(this.entropy == -1){
			trace("entropy is -1");
		}
		
		return this.entropy;
	}
	
	// choose a random possibility
	public function collapse():Int {
		if(this.state != -1){
			trace("Error: Wave is already collapsed");
			return -1;
			
		} else {
			
			var weightSum:Int = 0;
			// 1.) go through all valid choices and add up the sum
			// 2.) generate random number from 0 to sum
			// 3.) go through each valid choice and subtract its weight from that random number
			// 4.) check if the random number is equal to or less then 0
			// 4a.) if so, than this is the resulting choice
			// 4b.) else repeat from step 3
			for(counter in 0...possibilities.length){
				if(possibilities[counter] == true){
					weightSum += patternFrequencies[counter];
				}
			}
			
			if(weightSum == 0){
				trace("No possibilities for this wave left");
				return -1;
			}
			
			var selection:Int = Math.floor(Math.random() * weightSum);
			
			for(counter in 0...possibilities.length){
				if(possibilities[counter] == true){
					selection -= patternFrequencies[counter];
					if(selection <= 0){
						selection = counter;
						break;
					}
				}
			}
			
			this.state = selection;
			this.entropy = 0;
			
			// also set all the possibilities to false as this wave is being collapsed
			// need to do this in its own loop due to all the if statements
			for(counter in 0...possibilities.length){
				possibilities[counter] = false;
			}
			possibilities[this.state] = true; // set this one back to true as it is the current final state of this wave
				
			return this.state;
		}
	}
	
	// for debugging
	public function toString():String {
		return "entropy: "+ this.entropy +" - {"+ possibilities.join(", ") +"}";
	}
	
} // end of Wave{} class