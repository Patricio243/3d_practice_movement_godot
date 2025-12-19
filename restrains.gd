extends Node
class_name Restrains
# Player.gd

# Configuración de dificultad de escape (HP de la atadura)
const RESTRAINT_DATA = {
	"Blindfold": { "difficulty": 10.0, "type": "accessory" },
	"Ballgag":   { "difficulty": 15.0, "type": "accessory" },
	
	"collar":    { "difficulty": 50.0, "type": "hard" },     # Difícil de quitar
	"clamps":    { "difficulty": 5.0,  "type": "pain" },
	"vibrator":  { "difficulty": 0.0,  "type": "stimulation" }, # No se quita struggling, quizás necesita llave
	
	"RopeWrists": { "difficulty": 30.0, "group": "arms" },
	"RopeElbow": { "difficulty": 25.0, "group": "arms" },
	"RopeAnkle": { "difficulty": 30.0, "group": "legs" },
	"RopeKnee":  { "difficulty": 25.0, "group": "legs" }
}

# Estado actual: { "nombre_item": vida_actual }
var active_restraints:Dictionary = {"Blindfold":7}
