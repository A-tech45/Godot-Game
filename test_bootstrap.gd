extends SceneTree

func _init() -> void:
	print("--- TERRITORY BREAK BOOTSTRAP VERIFICATION ---")
	
	# Verify Weapon Factory
	print("[1/4] Verifying Weapon Factory...")
	var rifle = Weapon.create_rifle()
	var shotgun = Weapon.create_shotgun()
	var railgun = Weapon.create_railgun()
	var launcher = Weapon.create_launcher()
	print("✓ Weapons created: ", rifle.weapon_name, ", ", shotgun.weapon_name, ", ", railgun.weapon_name, ", ", launcher.weapon_name)

	# Verify Scenes Load
	print("[2/4] Loading Scenes...")
	var scenes_to_test = [
		"res://scenes/bullet.tscn",
		"res://scenes/player.tscn",
		"res://scenes/bot.tscn",
		"res://scenes/hud.tscn",
		"res://scenes/main_menu.tscn",
		"res://scenes/lobby.tscn",
		"res://scenes/arena.tscn"
	]
	
	for path in scenes_to_test:
		var res = load(path)
		if res == null:
			push_error("Failed to load scene: " + path)
			quit(1)
			return
		print("  - PackedScene OK: ", path)
	print("✓ All 6 scenes loaded successfully!")

	# Instantiate Main Menu & Arena
	print("[3/4] Instantiating Main Menu & Arena nodes...")
	var menu_inst = load("res://scenes/main_menu.tscn").instantiate()
	if menu_inst == null:
		push_error("Failed to instantiate Main Menu!")
		quit(1)
		return
	print("  - MainMenu instance created")

	var arena_inst = load("res://scenes/arena.tscn").instantiate()
	if arena_inst == null:
		push_error("Failed to instantiate Arena!")
		quit(1)
		return
	print("  - Arena instance created")

	print("[4/4] All verification tests passed cleanly!")
	print("--- VERIFICATION SUCCESSFUL ---")
	quit(0)
