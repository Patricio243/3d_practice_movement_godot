extends Node3D
class_name Visuals

@onready var skeleton_3d: Skeleton3D = $Skeleton3D
@onready var restrains: Restrains = $"../Restrains"

var children:Dictionary = {
	Accessories.BLINDFORLD:null,
	Accessories.BALLGAG:null,
	Accessories.ROPEELBOW:null,
	Accessories.ROPEWRISTS:null,
	Accessories.ROPEKNEE:null,
	Accessories.ROPEANKLE:null,
	Accessories.COLLAR:null,
	Accessories.VIBRATOR:null
}

func _ready() -> void:
	var child:Array = skeleton_3d.get_children()
	for c in child:
		if c is BoneAttachment3D and children.has(c.name):
			children[c.name] = c
	update_visuals()

func update_visuals():
	for child in children.values():
		if restrains.active_restraints.has(child.name):
			child.visible = true
		else:
			child.visible = false
