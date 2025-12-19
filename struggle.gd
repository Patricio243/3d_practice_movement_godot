extends Node
class_name Struggle

@onready var restrains: Restrains = $"../Restrains"
@onready var animation_tree: AnimationTree = $"../AnimationTree"
@onready var armature: Visuals = $"../Armature"
@onready var player = $".."

# Configuración
@export var struggle_power: float = 2.0
var is_struggling = false


func perform_struggle():
	if restrains.active_restraints.is_empty():
		return

	# Animación de forcejeo
	animation_tree.set("parameters/OneShotStruggle/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	
	# Lógica: Liberarse del ÚLTIMO item agregado (LIFO) o elegir uno al azar
	var target_item = restrains.active_restraints.keys().back() 
	
	# Restar vida a la atadura
	restrains.active_restraints[target_item] -= struggle_power
	
	# Feedback visual (Shake de cámara, sonido de cuerda tensándose)
	#camera_shake()
	
	# Si llega a 0, se rompe
	if restrains.active_restraints[target_item] <= 0:
		break_restraint(target_item)

func break_restraint(item_name):
	restrains.active_restraints.erase(item_name)
	armature.update_visuals()
	
	print("Se ha liberado de: " + item_name)
	
	# AGREGAR ESTO: Avisar al jugador que recalcule su estado
	if player.has_method("refresh_state"):
		player.refresh_state()

# Función para añadir restricciones desde el exterior (enemigos/trampas)
func add_restraint(item_name):
	if item_name in restrains.RESTRAINT_DATA:
		var max_hp = restrains.RESTRAINT_DATA[item_name]["difficulty"]
		restrains.active_restraints[item_name] = max_hp
		armature.update_visuals()
