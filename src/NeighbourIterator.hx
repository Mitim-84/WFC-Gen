package;

// an iterator for going over neighbouring cells instead of having to use two for loops for x and y
class NeighbourIterator {
	
	var offset:PointInt;
	var current:PointInt;
	var temp:PointInt; // needed due to the need to increment after the return, also useful to return this in case it the PointInt gets modified
	
	// distance from the "center/main cell"
	var distance:Int;
	
	public function new(inputDistance:Int = 1){
		distance = inputDistance;
		current = new PointInt(-distance, -distance);
		temp = new PointInt();
		
		offset = new PointInt();
	}

	public function hasNext():Bool {
		return (current.y <= distance);
	}

	public function next():PointInt {
		
		temp.x = current.x + offset.x;
		temp.y = current.y + offset.y;
		
		current.x++;
		
		if(current.x > distance){
			current.x = -distance;
			current.y++;
		}
		
		if((temp.x == offset.x) && (temp.y == offset.y)){
			return next();
		} else {		
			return temp;
		}
	}
	
	// added so can reuse the same Iterator instead of creating new ones over and over
	public function restart(inputOffset:PointInt = null):NeighbourIterator {
		current.x = -distance;
		current.y = -distance;
		
		if(inputOffset != null){
			offset.x = inputOffset.x;
			offset.y = inputOffset.y;
		} else {
			offset.x = 0;
			offset.y = 0;
		}
		return this;
	}
}