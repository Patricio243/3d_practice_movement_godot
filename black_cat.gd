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

# Acceso a la máquina de estados que está DENTRO del BlendTree
@onready var locomotion_sm = animation_tree.get("parameters/Locomotion/playback")
# Variables para controlar las mezclas
var hands_tied_weight = 0.0
var sit_weight = 0.0

# --- ESTADOS DEL PERSONAJE ---
enum State { NORMAL, HANDS_TIED,ANKLE_TIED, LEGS_TIED, KNEE_TIED, SIT_TIED, LEGS_TIED_WALK, STRUGGLE }
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
	if event.is_action_pressed("ui_e"): # Espacio o Botón A
		struggle.perform_struggle()


func get_movement_modifiers() -> Dictionary:
	var speed_multiplier = 1.0
	var can_jump = true
	var rotation_control = 1.0
	
	# --- PIERNAS ---
	if restrains.active_restraints.has(Accessories.ROPEANKLE):
		speed_multiplier *= 0.3 # Reduce al 30%
		can_jump = false
	
	if restrains.active_restraints.has(Accessories.ROPEKNEE):
		speed_multiplier *= 0.5 # Se acumula multiplicativamente
		can_jump = false
		
	# --- ACCESORIOS ---
	if restrains.active_restraints.has(Accessories.BLINDFOLD):
		# Si está ciega, se mueve con cautela
		speed_multiplier *= 0.8 
		rotation_control = 0.5 # Gira más lento
		
	if restrains.active_restraints.has(Accessories.VIBRATOR):
		# Efecto aleatorio de temblor o parada repentina
		if randf() < 0.01: # 1% de chance cada frame
			speed_multiplier = 0.0 # Se detiene por el estímulo
	
	return { "speed": speed_multiplier, "jump": can_jump, "rot": rotation_control }

func refresh_state():
	# 1. Comprobamos si quedan ataduras críticas
	var has_wrists = restrains.active_restraints.has(Accessories.ROPEWRISTS)
	var has_ankles = restrains.active_restraints.has(Accessories.ROPEANKLE)
	var has_knees = restrains.active_restraints.has(Accessories.ROPEKNEE)
	
	# 2. Decidimos el estado según prioridad
	# (Aquí puedes ajustar la lógica si quieres que SIT_TIED sea especial)
	
	if has_ankles or has_knees:
		# Si tiene ataduras en las piernas, pasamos a estado de piernas atadas
		# (Nota: Si estaba sentado, quizás quieras mantenerlo sentado hasta que se libere todo, 
		#  pero por ahora simplifiquemos a que intente pararse si puede).
		if current_state != State.SIT_TIED: 
			current_state = State.LEGS_TIED
	elif has_wrists:
		# Si solo tiene manos atadas
		current_state = State.HANDS_TIED
	else:
		# Si no hay ataduras mayores, es libre
		current_state = State.NORMAL

	# 3. Forzar actualización visual inmediata si es necesario
	armature.update_visuals()

func _physics_process(delta):
	var mods = get_movement_modifiers()
	
	# 1. Aplicar Gravedad
	if not is_on_floor():
		velocity.y -= gravity * delta
	
	# 2. Determinar velocidad BASE según estado
	var base_speed: float = speed_normal
	var can_jump = false
	
	match current_state:
		State.NORMAL:
			base_speed = speed_normal
			can_jump = true
		State.HANDS_TIED:
			base_speed = speed_normal 
			can_jump = true
		State.LEGS_TIED:
			base_speed = speed_tied_legs
			can_jump = false 
		State.SIT_TIED:
			base_speed = 0.0 
			can_jump = false

	# 3. Aplicar modificadores de restricciones a la velocidad base
	var current_speed = base_speed * mods["speed"]
	
	# Si los modificadores prohíben saltar (ej. ataduras en piernas), anulamos el salto
	if mods["jump"] == false:
		can_jump = false

	# 4. Salto (resto del código igual...)
	if Input.is_action_just_pressed("ui_accept") and is_on_floor() and can_jump:
		velocity.y = jump_velocity

	# 4. Movimiento (WASD)
	# Obtenemos la dirección relativa a hacia donde mira la CÁMARA (Pivot)
	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction = (camera_pivot.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	if direction and current_speed > 0 and not struggle.is_struggling:
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
	# 1. PIERNAS (State Machine)
	# Mantenemos tu lógica actual, funciona perfecto para cambios de física.
	if restrains.active_restraints.has(Accessories.ROPEKNEE):
		locomotion_sm.travel(AnimResource.KNEE) # Asumiendo que creaste KNEE en AnimResource
	elif restrains.active_restraints.has(Accessories.ROPEANKLE):
		locomotion_sm.travel(AnimResource.ANKLE)
	elif current_state == State.SIT_TIED:
		locomotion_sm.travel(AnimResource.IDLE)
	else:
		if input_dir.length() > 0:
			locomotion_sm.travel(AnimResource.WALK)
		else:
			locomotion_sm.travel(AnimResource.IDLE)

	# 2. BRAZOS (Selector + Blend)
	var target_hands_weight = 0.0
	var arm_style = 0 # 0: Nada, 1: Wrists, 2: Elbows
	
	if restrains.active_restraints.has(Accessories.ROPEELBOW):
		target_hands_weight = 1.0
		arm_style = 2 # Índice para Codos en el Transition
	elif restrains.active_restraints.has(Accessories.ROPEWRISTS):
		target_hands_weight = 1.0
		arm_style = 1 # Índice para Muñecas en el Transition
	
	# 3. VIBRADOR (Additive)
	var vibe_amount = 0.0
	if restrains.active_restraints.has(Accessories.VIBRATOR):
		# Puedes usar un seno para que la intensidad suba y baje
		vibe_amount = 0.5 + sin(Time.get_ticks_msec() * 0.01) * 0.2
	
	# 4. APLICAR VALORES
	hands_tied_weight = lerp(hands_tied_weight, target_hands_weight, 0.1)
	
	# Parámetros del Tree
	animation_tree.set("parameters/ArmBlend/blend_amount", hands_tied_weight)
	
	# ¡OJO! Los nodos Transition usan "current" (int) para cambiar
	animation_tree.set("parameters/ArmSelector/current", arm_style)
	
	# Vibración
	animation_tree.set("parameters/VibeAdd/add_amount", vibe_amount)
	
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
	struggle.add_restraint(Accessories.ROPEWRISTS)
	armature.update_visuals()

func set_state_tied_legs():
	current_state = State.LEGS_TIED
	struggle.add_restraint(Accessories.ROPEANKLE)
	armature.update_visuals()

func set_state_sit_tied():
	current_state = State.SIT_TIED
	struggle.add_restraint(Accessories.ROPEWRISTS)
	struggle.add_restraint(Accessories.ROPEANKLE)
	armature.update_visuals()

func set_state_free():
	current_state = State.NORMAL
	restrains.active_restraints.clear()
	armature.update_visuals()
