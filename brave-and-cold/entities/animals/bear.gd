class_name Bear
extends Wolf
## Brown bear: same brain as the wolf (alert -> chase -> maul) but slower, much tougher, far deadlier,
## and it only bothers with you inside a shorter sight range. Reuses Wolf states; different body and numbers.


func _init() -> void:
	model_path = "res://assets/models/animals/bear.glb"
	part_prefix = "bear"
	death_msg = "Mauled by a bear"
	WALK_SPEED = 1.3
	TROT_SPEED = 2.8
	RUN_SPEED = 6.4
	SIGHT_RANGE = 26.0
	ALERT_TIME = 1.6
	BITE_RANGE = 2.3
	BITE_DAMAGE = 38.0
	BITE_COOLDOWN = 1.7
	GIVE_UP_DIST = 60.0
	hp = 260.0
	body_radius = 0.9
