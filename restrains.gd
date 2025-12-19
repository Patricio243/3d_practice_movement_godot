extends Node
class_name Restrains

# Configuración de dificultad de escape (HP de la atadura)
const RESTRAINT_DATA = {
	Accessories.BLINDFORLD: { "difficulty": 10.0, "type": "accessory" },
	Accessories.BALLGAG:   { "difficulty": 15.0, "type": "accessory" },
	
	Accessories.COLLAR:    { "difficulty": 50.0, "type": "hard" },     # Difícil de quitar
	Accessories.CLAMPS:    { "difficulty": 5.0,  "type": "pain" },
	Accessories.VIBRATOR:  { "difficulty": 0.0,  "type": "stimulation" }, # No se quita struggling, quizás necesita llave
	
	Accessories.ROPEWRISTS: { "difficulty": 30.0, "group": "arms" },
	Accessories.ROPEELBOW: { "difficulty": 25.0, "group": "arms" },
	Accessories.ROPEANKLE: {"difficulty": 30.0, "group": "legs" },
	Accessories.ROPEKNEE:  { "difficulty": 25.0, "group": "legs" }
}

# Estado actual: { "nombre_item": vida_actual }
var active_restraints:Dictionary = {"Vibrator":7}
