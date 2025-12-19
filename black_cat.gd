extends CharacterBody3D
class_name Player

# --- CONFIGURACIÓN ---
@export_group("Movement")
@export var speed_normal: float = 5.0
@export var speed_tied_legs: float = 1.0 # Velocidad reducida si tiene las piernas atadas
@export var jump_velocity: float = 4.5
@export var rotation_speed: float = 10.0

@export_group("Camera")
@export var mouse_sensitivity: float = 0.003
@export var min_pitch: float = -50.0 # Límite mirar abajo
@export var max_pitch: float = 75.0  # Límite mirar arriba

# --- REFERENCIAS A NODOS ---
@onready var camera_pivot = $CameraPivot
@onready var visuals = $Armature
@onready var animation_tree = $AnimationTree
@onready var canvas_layer: CanvasLayer = $"../CanvasLayer"
# Acceso directo a la máquina de estados de animaciones para 'travel'
#@onready var state_machine = animation_tree.get("parameters/playback")

# Acceso a la máquina de estados que está DENTRO del BlendTree
@onready var locomotion_sm = animation_tree.get("parameters/Locomotion/playback")
# Variables para controlar las mezclas
var hands_tied_weight = 0.0
var sit_weight = 0.0

# --- ESTADOS DEL PERSONAJE ---
enum State { NORMAL, HANDS_TIED, LEGS_TIED, SIT_TIED, LEGS_TIED_WALK }
var current_state: State = State.NORMAL

# Gravedad del proyecto
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var restrains: Restrains = $Restrains
@onready var armature: Visuals = $Armature
@onready var struggle: Struggle = $Struggle


func _ready():
	# Capturar el mouse para que no se salga de la ventana
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event):
	# Rotación de cámara con el mouse
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		camera_pivot.rotate_y(-event.relative.x * mouse_sensitivity)
		$CameraPivot/SpringArm3D.rotate_x(-event.relative.y * mouse_sensitivity)
		# Limitar la rotación vertical (clamp)
		$CameraPivot/SpringArm3D.rotation.x = clamp(
			$CameraPivot/SpringArm3D.rotation.x, 
			deg_to_rad(min_pitch), 
			deg_to_rad(max_pitch)
		)

	# Tecla ESC para liberar el mouse (útil para debug)
	if event.is_action_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			canvas_layer.visible = true
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			canvas_layer.visible = false
	
	# Liberarse
	if event.is_action_pressed("ui_accept"): # Espacio o Botón A
		struggle.perform_struggle()


func get_movement_modifiers() -> Dictionary:
	var speed_multiplier = 1.0
	var can_jump = true
	var rotation_control = 1.0
	
	# --- PIERNAS ---
	if restrains.active_restraints.has("ankle_rope"):
		speed_multiplier *= 0.3 # Reduce al 30%
		can_jump = false
	
	if restrains.active_restraints.has("knee_rope"):
		speed_multiplier *= 0.5 # Se acumula multiplicativamente
		can_jump = false
		
	# --- ACCESORIOS ---
	if restrains.active_restraints.has("blindfold"):
		# Si está ciega, se mueve con cautela
		speed_multiplier *= 0.8 
		rotation_control = 0.5 # Gira más lento
		
	if restrains.active_restraints.has("vibrator"):
		# Efecto aleatorio de temblor o parada repentina
		if randf() < 0.01: # 1% de chance cada frame
			speed_multiplier = 0.0 # Se detiene por el estímulo
	
	return { "speed": speed_multiplier, "jump": can_jump, "rot": rotation_control }

func _physics_process(delta):
	var mods = get_movement_modifiers()
	
	# 1. Aplicar Gravedad
	if not is_on_floor():
		velocity.y -= gravity * delta
	
	# 2. Determinar velocidad actual según estado
	var current_speed:float = speed_normal * mods["speed"]
	var can_jump = false
	
	match current_state:
		State.NORMAL:
			current_speed = speed_normal
			can_jump = true
		State.HANDS_TIED:
			current_speed = speed_normal # Puede correr, pero con manos atadas
			can_jump = true
		State.LEGS_TIED:
			current_speed = speed_tied_legs # Movimiento muy lento o saltitos
			can_jump = false # O quizás true si quieres que salte con pies juntos
		State.SIT_TIED:
			current_speed = 0.0 # Inmóvil
			can_jump = false

	# 3. Salto
	if Input.is_action_just_pressed("ui_accept") and is_on_floor() and can_jump:
		velocity.y = jump_velocity

	# 4. Movimiento (WASD)
	# Obtenemos la dirección relativa a hacia donde mira la CÁMARA (Pivot)
	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction = (camera_pivot.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	if direction and current_speed > 0:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
		
		# Rotar el modelo visual hacia donde nos movemos (interpolación suave)
		var target_rotation = atan2(direction.x, direction.z)
		visuals.rotation.y = lerp_angle(visuals.rotation.y, target_rotation, rotation_speed * delta)
	else:
		velocity.x = move_toward(velocity.x, 0, current_speed)
		velocity.z = move_toward(velocity.z, 0, current_speed)

	# 5. Ejecutar movimiento físico
	move_and_slide()

	# 6. Actualizar Animaciones
	update_animations(input_dir)


func update_animations(input_dir):
	# 1. CONTROL DEL MOVIMIENTO BASE (PIERNAS)
	# Si las piernas están atadas, forzamos la animación de saltitos/pasos cortos
	if current_state == State.LEGS_TIED:
		locomotion_sm.travel("LEGS_TIED_WALK") # Asegúrate de crear este nodo en la SM
	elif current_state == State.SIT_TIED:
		locomotion_sm.travel("IDLE") # No importa mucho, el SitOverride lo tapará
	else:
		# Estado NORMAL o HANDS_TIED (las piernas funcionan igual)
		if input_dir.length() > 0:
			locomotion_sm.travel("WALK")
		else:
			locomotion_sm.travel("IDLE")

	# 2. CONTROL DE LAS MEZCLAS (CAPAS)
	
	# ¿Tenemos las manos atadas? (Aplica para HANDS_TIED, LEGS_TIED y SIT_TIED si quieres)
	var target_hands = 0.0
	if current_state == State.HANDS_TIED or current_state == State.LEGS_TIED or current_state == State.SIT_TIED:
		target_hands = 1.0
	else:
		target_hands = 0.0
	
	# ¿Estamos sentados?
	var target_sit = 0.0
	if current_state == State.SIT_TIED:
		target_sit = 1.0
	else:
		target_sit = 0.0

	# 3. APLICAR VALORES CON INTERPOLACIÓN (Suavizado)
	# Usamos lerp para que los brazos no cambien de golpe
	hands_tied_weight = lerp(hands_tied_weight, target_hands, 0.1)
	sit_weight = lerp(sit_weight, target_sit, 0.1)
	
	# Asignar al árbol
	# "parameters/NOMBRE_DEL_NODO/blend_amount"
	animation_tree.set("parameters/HandsBlend/blend_amount", hands_tied_weight)
	animation_tree.set("parameters/SitOverride/blend_amount", sit_weight)


# --- FUNCIONES PÚBLICAS PARA CAMBIAR ESTADO ---
# Llama a estas funciones desde otros scripts (ej. un enemigo te captura)

func set_state_tied_hands():
	current_state = State.HANDS_TIED
	restrains.active_restraints["RopeWrists"] = 10
	armature.update_visuals()

func set_state_tied_legs():
	current_state = State.LEGS_TIED
	restrains.active_restraints["RopeAnkle"] = 10
	armature.update_visuals()

func set_state_sit_tied():
	current_state = State.SIT_TIED
	restrains.active_restraints["RopeWrists"] = 10
	restrains.active_restraints["RopeAnkle"] = 10
	armature.update_visuals()

func set_state_free():
	current_state = State.NORMAL
	restrains.active_restraints.clear()
	armature.update_visuals()
