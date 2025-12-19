extends CanvasLayer

@onready var control: Control = $Control

@onready var button: Button = $Control/Button
@onready var button_2: Button = $Control/Button2
@onready var button_3: Button = $Control/Button3

@onready var player: Player = $"../Player"

func _ready() -> void:
	for child in control.get_children():
		if child is Button:
			child.pressed.connect(button_pressed.bind(child))
	pass

func button_pressed(btn:Button):
	match btn.text:
		"tied hands":
			player.set_state_tied_hands()
			pass
		"tied legs":
			player.set_state_tied_legs()
			pass
		"tied sit":
			player.set_state_sit_tied()
			pass
		"free":
			player.set_state_free()
		_:
			pass
	pass
