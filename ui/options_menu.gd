extends Control

@onready var virtual_joystick_mode:ItemList = get_node("%virtual_joystick_mode")
@onready var click_to_move_button = get_node("%click_to_move_button")
@onready var player:Player = get_tree().get_first_node_in_group("player")

# Called when the node enters the scene tree for the first time.
func _ready():
	click_to_move_button.button_pressed = UserSettings.config.get_value("control", "click_to_move", true)
	var mode = UserSettings.config.get_value("control", "virtual_joystick", "auto")
	virtual_joystick_mode.select(0)			
	if mode == "always":
		virtual_joystick_mode.select(1)
	elif mode == "never":
		virtual_joystick_mode.select(2)

func _on_click_to_move_button_toggled(toggled_on):
	UserSettings.config.set_value("control", "click_to_move", toggled_on)
	player.disable_pathing = !toggled_on


func _on_virtual_joystick_mode_item_selected(index):	
	var mode = "auto"
	if index == 1:
		mode = "always"
	elif index == 2:
		mode = "never"
	UserSettings.config.set_value("control", "virtual_joystick", mode)
	player.configure_virtual_joystick(mode)
