extends CharacterBody2D

@export var speed = 200
@export var autopilot = true

func _physics_process(delta):
	if autopilot:
		var enemies = get_tree().get_nodes_in_group("enemy")
		var dir = velocity.normalized()
		velocity = get_autopilot_velocity(dir, enemies)
	else:
		velocity = get_input_velocity()

	move_and_slide()


func get_autopilot_velocity(dir:Vector2, enemies:Array):
	for enemy in enemies:
		var enemy_distance = enemy.global_position - global_position
		var enemy_distance_total = abs(enemy_distance.x) + abs(enemy_distance.y)
		if (enemy_distance_total < 100):
			var enemy_dir = enemy.global_position.direction_to(global_position)
			dir += enemy_dir * 0.2

	if randf() < 0.05:
		var random_factor = Vector2(randf_range(-0.5, 0.5), randf_range(-0.5, 0.5))
		dir += random_factor

	return dir.normalized() * speed

func get_input_velocity():
	var dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	return dir.normalized() * speed
