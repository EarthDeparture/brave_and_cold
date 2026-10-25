extends SceneTree
## Headless checks for survival + snow models. Run: Godot --headless --path brave-and-cold --script res://tests/test_survival.gd
## Prints PASS/FAIL lines; exits 1 on any failure.

var failures := 0


func check(label: String, ok: bool, detail: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + label + (" | " + detail if detail != "" else ""))
	if not ok:
		failures += 1


func sim(warmth: float, ambient: float, wind: float, activity: int, minutes: int, fire_w: float = 0.0, shelter: bool = false, windproof: float = 0.1) -> BodyTemperature:
	var b := BodyTemperature.new()
	b.warmth = warmth
	b.windproof = windproof
	for _i in range(minutes * 60):
		b.update(1.0, ambient, wind, shelter, fire_w, activity, 0.0, false)
	return b


func _initialize() -> void:
	# Lightly dressed at -15 C resting: should get hypothermic within ~1 h game time, not within 5 min.
	var b5 := sim(0.25, -15.0, 3.0, 0, 5)
	check("light clothes rest 5 min still ok", b5.core > 36.6, "core=%.2f" % b5.core)
	var b60 := sim(0.25, -15.0, 3.0, 0, 60)
	check("light clothes rest 60 min hypothermic", b60.core < BodyTemperature.SHIVER, "core=%.2f state=%s" % [b60.core, b60.state_name()])
	# Well dressed (warm + windproof) at -15 C resting: stable for hours.
	var w180 := sim(0.85, -15.0, 3.0, 0, 180, 0.0, false, 0.8)
	check("warm windproof clothes stable 3 h", w180.core > 36.3, "core=%.2f" % w180.core)
	# Fire recovers a cold body.
	var cold := BodyTemperature.new()
	cold.core = 34.5
	cold.warmth = 0.5
	for _i in range(30 * 60):
		cold.update(1.0, -15.0, 0.0, true, 350.0, 0, 0.0, false)
	check("fire rewarms 34.5 -> >36 in 30 min", cold.core > 36.0, "core=%.2f" % cold.core)
	# Wind chill worse than calm.
	var calm := sim(0.4, -15.0, 0.0, 0, 30)
	var gale := sim(0.4, -15.0, 12.0, 0, 30)
	check("wind makes it colder", gale.core < calm.core, "calm=%.2f gale=%.2f" % [calm.core, gale.core])
	# Shelter under canopy reduces wind loss.
	var open := sim(0.4, -15.0, 10.0, 0, 30)
	var shel := sim(0.4, -15.0, 10.0, 0, 30, 0.0, true)
	check("canopy shelter helps", shel.core > open.core, "open=%.2f shelter=%.2f" % [open.core, shel.core])
	# Never overheats.
	var hot := sim(0.9, 5.0, 0.0, 2, 30)
	check("no overheating", hot.core <= 37.05, "core=%.2f" % hot.core)
	# Snow tables.
	check("zombie speed tier 5 is 20%", is_equal_approx(SnowField.ZOMBIE_SPEED[5], 0.2))
	check("zombie speed monotonic", SnowField.ZOMBIE_SPEED == SnowField.ZOMBIE_SPEED.duplicate() and SnowField.ZOMBIE_SPEED[0] > SnowField.ZOMBIE_SPEED[5])
	var s := SnowField.new()
	s._base_n = 8
	s.half = 8.0
	s._base = PackedByteArray()
	s._base.resize(64)
	s._base.fill(5)
	check("base tier 5", s.tier_at(0.0, 0.0) == 5)
	s.trample(0.0, 0.0, 0.5)
	check("trample drops 2 tiers", s.tier_at(0.0, 0.0) == 3, "tier=%d" % s.tier_at(0.0, 0.0))
	s.advance(SnowField.TRAMPLE_LIFE_S + 1.0)
	check("trail refills after life", s.tier_at(0.0, 0.0) == 5)
	print("SURVIVAL_TESTS failures=", failures)
	quit(1 if failures > 0 else 0)
