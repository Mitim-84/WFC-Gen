package;

// an iterator for going over the cells instead of having to use two for loops for x and y
class CellIterator {
	
	var bounds:PointInt;
	
	var current:PointInt;
	var temp:PointInt; // needed due to the need to increment after the return, also useful to return this in case it the PointInt gets modified
	
	public function new(inputBounds:PointInt){
		bounds = inputBounds;
		current = new PointInt();
		temp = new PointInt();
	}

	public function hasNext():Bool {
		return (current.y < (bounds.y));
	}

	public function next():PointInt {
		
		temp.x = current.x;
		temp.y = current.y;
		
		current.x++;
		
		if(current.x >= bounds.x){
			current.x = 0;
			current.y++;
		}
		
		return temp;
	}
	
	// added so can reuse the same Iterator instead of creating new ones over and over
	public function restart():CellIterator {
		current.x = 0;
		current.y = 0;
		return this;
	}
}