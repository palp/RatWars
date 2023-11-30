class_name Player
extends CharacterBody2D

@export var autopilot = true
var disable_pathing_input = false

@export var movement_speed = 40.0
@export var maxhp = 80
var hp = maxhp
var last_movement = Vector2.UP
var time = 0

var experience = 0
var experience_level = 1
var collected_experience = 0
var score = 0

#Attacks
var javelin = preload("res://Player/Attack/javelin.tscn")

#AttackNodes
@onready var javelinBase = get_node("%JavelinBase")
@onready var attackManager = get_node("%AttackManager") as attack_manager

#UPGRADES
var collected_upgrades = []
var upgrade_options = []
var armor = 0
var speed = 0
var spell_cooldown = 0
var spell_size = 0
var additional_attacks = 0

#Javelin
var javelin_ammo = 0
var javelin_level = 0

#Enemy Related
var enemy_close = []

@onready var sprite = $Sprite2D
@onready var walkTimer = get_node("%walkTimer")

#GUI
@onready var expBar = get_node("%ExperienceBar")
@onready var lblLevel = get_node("%lbl_level")
@onready var levelPanel = get_node("%LevelUp")
@onready var upgradeOptions = get_node("%UpgradeOptions")
@onready var itemOptions = preload("res://Utility/item_option.tscn")
@onready var sndLevelUp = get_node("%snd_levelup")
@onready var healthBar = get_node("%HealthBar")
@onready var lblTimer = get_node("%lblTimer")
@onready var collectedWeapons = get_node("%CollectedWeapons")
@onready var collectedUpgrades = get_node("%CollectedUpgrades")
@onready var itemContainer = preload("res://Player/GUI/item_container.tscn")

@onready var deathPanel = get_node("%DeathPanel")
@onready var lblResult = get_node("%lbl_Result")
@onready var sndVictory = get_node("%snd_victory")
@onready var sndLose = get_node("%snd_lose")

#Game session
@onready var sessionUpdateTimer = get_node("%SessionUpdateTimer") as Timer
var game_session = {}

#Signal
signal playerdeath


# These could be abstracted to an input manager
func check_movement_input():
	return (
		Input.is_action_just_pressed("ui_up")
		or Input.is_action_just_pressed("ui_down")
		or Input.is_action_just_pressed("ui_right")
		or Input.is_action_just_pressed("ui_left")
	)


const FACING_EPSILON = 0.1


func set_facing():
	# Setting scale doesn't work so we do this slightly
	# more complicsted logic.
	var new_flip = false
	if velocity.x < -FACING_EPSILON:
		new_flip = true
	elif velocity.x > FACING_EPSILON:
		new_flip = false
	else:
		# Just keep previous flip value
		return

	# Also flip offset if needed
	if new_flip != sprite.is_flipped_h():
		sprite.set_flip_h(new_flip)
		sprite.offset.x = -sprite.offset.x


func check_pathing_input():
	return not disable_pathing_input and Input.is_action_pressed("click")


func get_movement_vector():
	return Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")


func get_pathing_target():
	return get_global_mouse_position()


func _ready():
	upgrade_character("vinyl1")
	attack()
	set_expbar(experience, calculate_experiencecap())
	_on_hurt_box_hurt(0, 0, 0)
	for content in Unlocks.unlocked_content:
		_on_content_unlocked(content)
	Unlocks.content_unlocked.connect(_on_content_unlocked)

	# TODO Disable when autopilot is enabled, also make autopilot state cancel session
	game_session = await Server.create_game_session()
	sessionUpdateTimer.start(45)


func _on_content_unlocked(content):
	if content == "plugsuit":
		get_node(NodePath("Sprite2D")).texture = load(
			"res://assets/player/character/john/john_plugsuit.png"
		)


func _physics_process(delta):
	pass


func attack():
	if javelin_level > 0:
		spawn_javelin()


func _on_hurt_box_hurt(damage, _angle, _knockback):
	hp -= clamp(damage - armor, 1.0, 999.0)
	healthBar.max_value = maxhp
	healthBar.value = hp
	if hp <= 0:
		death()

func spawn_javelin():
	var get_javelin_total = javelinBase.get_child_count()
	var calc_spawns = (javelin_ammo + additional_attacks) - get_javelin_total
	while calc_spawns > 0:
		var javelin_spawn = javelin.instantiate()
		javelin_spawn.global_position = global_position
		javelinBase.add_child(javelin_spawn)
		calc_spawns -= 1
	#Upgrade Javelin
	var get_javelins = javelinBase.get_children()
	for i in get_javelins:
		if i.has_method("update_javelin"):
			i.update_javelin()


func get_random_target():
	if enemy_close.size() > 0:
		return enemy_close.pick_random().global_position
	else:
		return Vector2.UP


func _on_enemy_detection_area_body_entered(body):
	if not enemy_close.has(body):
		enemy_close.append(body)


func _on_enemy_detection_area_body_exited(body):
	if enemy_close.has(body):
		enemy_close.erase(body)


func _on_grab_area_area_entered(area):
	if area.is_in_group("loot"):
		area.target = self


func _on_collect_area_area_entered(area):
	if area.is_in_group("loot"):
		var gem_exp = area.collect()
		calculate_experience(gem_exp)


func calculate_experience(gem_exp):
	var exp_required = calculate_experiencecap()
	collected_experience += gem_exp
	score += collected_experience
	if experience + collected_experience >= exp_required:  #level up
		collected_experience -= exp_required - experience
		experience_level += 1
		experience = 0
		exp_required = calculate_experiencecap()
		levelup()
	else:
		experience += collected_experience
		collected_experience = 0

	set_expbar(experience, exp_required)


func calculate_experiencecap():
	var exp_cap = experience_level
	if experience_level < 20:
		exp_cap = experience_level * 5
	elif experience_level < 40:
		exp_cap + 95 * (experience_level - 19) * 8
	else:
		exp_cap = 255 + (experience_level - 39) * 12

	return exp_cap


func set_expbar(set_value = 1, set_max_value = 100):
	expBar.value = set_value
	expBar.max_value = set_max_value


func levelup():
	sndLevelUp.play()
	lblLevel.text = str("Level: ", experience_level)
	if autopilot:
		upgrade_character(get_random_item())
		return
	var tween = levelPanel.create_tween()
	(
		tween
		. tween_property(levelPanel, "position", Vector2(220, 50), 0.2)
		. set_trans(Tween.TRANS_QUINT)
		. set_ease(Tween.EASE_IN)
	)
	tween.play()
	levelPanel.visible = true
	var options = 0
	var optionsmax = 3
	while options < optionsmax:
		var option_choice = itemOptions.instantiate()
		option_choice.item = get_random_item()
		upgradeOptions.add_child(option_choice)
		options += 1
	get_tree().paused = true


func upgrade_character(upgrade):
	match upgrade:
		"icespear1":
			attackManager.attacks['icespear'].level = 1
			attackManager.attacks['icespear'].base_ammo += 1
		"icespear2":
			attackManager.attacks['icespear'].level = 2
			attackManager.attacks['icespear'].base_ammo += 1
		"icespear3":
			attackManager.attacks['icespear'].level = 3
		"icespear4":
			attackManager.attacks['icespear'].level = 4
			attackManager.attacks['icespear'].baseammo += 2
		"tornado1":
			attackManager.attacks['tornado'].level = 1
			attackManager.attacks['tornado'].base_ammo += 1
		"tornado2":
			attackManager.attacks['tornado'].level = 2
			attackManager.attacks['tornado'].base_ammo += 1
		"tornado3":
			attackManager.attacks['tornado'].level = 3
			attackManager.attacks['tornado'].attack_speed -= 0.5
		"tornado4":
			attackManager.attacks['tornado'].level = 4
			attackManager.attacks['tornado'].base_ammo += 1
		"vinyl1":
			attackManager.attacks['vinyl'].level = 1
			attackManager.attacks['vinyl'].base_ammo += 1
		"vinyl2":
			attackManager.attacks['vinyl'].level = 2
			attackManager.attacks['vinyl'].base_ammo += 1
		"vinyl3":
			attackManager.attacks['vinyl'].level = 3
			attackManager.attacks['vinyl'].attack_speed -= 0.5
		"vinyl4":
			attackManager.attacks['vinyl'].level = 4
			attackManager.attacks['vinyl'].base_ammo += 1
		"javelin1":
			javelin_level = 1
			javelin_ammo = 1
		"javelin2":
			javelin_level = 2
		"javelin3":
			javelin_level = 3
		"javelin4":
			javelin_level = 4
		"armor1", "armor2", "armor3", "armor4":
			armor += 1
		"speed1", "speed2", "speed3", "speed4":
			movement_speed += 20.0
		"tome1", "tome2", "tome3", "tome4":
			spell_size += 0.10			
		"scroll1", "scroll2", "scroll3", "scroll4":			
			spell_cooldown += 0.05
		"ring1", "ring2":			
			additional_attacks += 1
		"food":
			hp += 20
			hp = clamp(hp, 0, maxhp)
	adjust_gui_collection(upgrade)
	attack()
	var option_children = upgradeOptions.get_children()
	for i in option_children:
		i.queue_free()
	upgrade_options.clear()
	collected_upgrades.append(upgrade)
	levelPanel.visible = false
	levelPanel.position = Vector2(800, 50)
	get_tree().paused = false
	calculate_experience(0)


func get_random_item():
	var dblist = []
	for i in UpgradeDb.UPGRADES:
		if i in collected_upgrades:  #Find already collected upgrades
			pass
		elif i in upgrade_options:  #If the upgrade is already an option
			pass
		elif UpgradeDb.UPGRADES[i]["type"] == "item":  #Don't pick food
			pass
		elif UpgradeDb.UPGRADES[i]["prerequisite"].size() > 0:  #Check for PreRequisites
			var to_add = true
			for n in UpgradeDb.UPGRADES[i]["prerequisite"]:
				if not n in collected_upgrades:
					to_add = false
			if to_add:
				dblist.append(i)
		else:
			dblist.append(i)
	if dblist.size() > 0:
		var randomitem = dblist.pick_random()
		upgrade_options.append(randomitem)
		return randomitem
	else:
		return null


func change_time(argtime = 0):
	time = argtime
	var get_m = int(time / 60.0)
	var get_s = time % 60
	if get_m < 10:
		get_m = str(0, get_m)
	if get_s < 10:
		get_s = str(0, get_s)
	lblTimer.text = str(get_m, ":", get_s)


func adjust_gui_collection(upgrade):
	var get_upgraded_displayname = UpgradeDb.UPGRADES[upgrade]["displayname"]
	var get_type = UpgradeDb.UPGRADES[upgrade]["type"]
	if get_type != "item":
		var get_collected_displaynames = []
		for i in collected_upgrades:
			get_collected_displaynames.append(UpgradeDb.UPGRADES[i]["displayname"])
		if not get_upgraded_displayname in get_collected_displaynames:
			var new_item = itemContainer.instantiate()
			new_item.upgrade = upgrade
			match get_type:
				"weapon":
					collectedWeapons.add_child(new_item)
				"upgrade":
					collectedUpgrades.add_child(new_item)


func death():
	if autopilot:
		# TODO Remove this
		await submit_score()
		emit_signal("playerdeath")
		get_tree().reload_current_scene()
		return
	deathPanel.visible = true
	emit_signal("playerdeath")
	get_tree().paused = true
	var tween = deathPanel.create_tween()
	(
		tween
		. tween_property(deathPanel, "position", Vector2(220, 50), 3.0)
		. set_trans(Tween.TRANS_QUINT)
		. set_ease(Tween.EASE_OUT)
	)
	tween.play()
	if time >= 300:
		lblResult.text = "You Win"
		sndVictory.play()
	else:
		lblResult.text = "You Lose"
		sndLose.play()

	# TODO Only submit scores on win, prompt for name
	await submit_score()

func submit_score():
	if game_session.has("id"):
		# Random names for now
		var names = ["Johnny", "Jake", "Beej"]
		var leaderboard = await Server.submit_game_session(score, names.pick_random())	

func _on_btn_menu_click_end():
	get_tree().paused = false
	var _level = get_tree().change_scene_to_file("res://TitleScreen/menu.tscn")


func _on_session_update_timer_timeout():
	if game_session.has("id"):
		game_session = await Server.update_game_session(score)
