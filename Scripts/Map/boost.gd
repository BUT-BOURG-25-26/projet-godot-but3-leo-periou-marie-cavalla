extends Node3D

var type:String = ""

func set_boost_type(type:String):
	self.type = type
	match type :
		"Health" :
			pass
		"Attack" : 
			pass
		"Speed" :
			pass
