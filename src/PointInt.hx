package;

// self rolled point to only deal with ints
class PointInt {
	public var x:Int;
	public var y:Int;
	
	public function new(inputX:Int = 0, inputY:Int = 0):Void {
		this.x = inputX;
		this.y = inputY;
	}
	
	public function wrapIndexes(bounds:PointInt):Void {
		this.x = (this.x + bounds.x) % bounds.x;
		this.y = (this.y + bounds.y) % bounds.y;
	}
	
	// maxX/Y is exclusive
	public function isValid(bounds:PointInt):Bool {
		return ((this.x > -1) && (this.y > -1) && (this.x < bounds.x) && (this.y < bounds.y));
	}
	
	public function step(input:PointInt):Void {
		this.x += input.x;
		this.y += input.y;
	}
	
	public function toString():String {
		return "("+ this.x +", " + this.y +")";
	}
	
	public function clone():PointInt {
		return new PointInt(this.x, this.y);
	}
}