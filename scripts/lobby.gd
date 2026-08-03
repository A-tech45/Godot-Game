extends Control

## Lobby UI controller: Handles custom name entry, room creation, join by code, and peer slot display.

@onready var name_edit: LineEdit = %NameEdit
@onready var mode_tabs: TabContainer = %ModeTabs

# Host controls
@onready var private_check: CheckBox = %PrivateCheckBox
@onready var bot_fill_option: OptionButton = %BotFillOption
@onready var manual_bots_spin: SpinBox = %ManualBotsSpin
@onready var manual_bots_box: HBoxContainer = %ManualBotsBox
@onready var host_button: Button = %HostRoomButton

# Join controls
@onready var code_edit: LineEdit = %CodeEdit
@onready var join_button: Button = %JoinRoomButton
@onready var status_label: Label = %StatusLabel

# Room view controls
@onready var room_panel: PanelContainer = %RoomPanel
@onready var room_code_label: Label = %RoomCodeLabel
@onready var copy_code_button: Button = %CopyCodeButton
@onready var player_list_box: VBoxContainer = %PlayerListBox
@onready var start_match_button: Button = %StartMatchButton
@onready var leave_room_button: Button = %LeaveRoomButton
@onready var back_menu_button: Button = %BackMenuButton

func _ready() -> void:
	room_panel.hide()
	status_label.text = ""
	
	# Load saved player name or generate default
	name_edit.text = NetworkManager.local_player_name
	if name_edit.text == "" or name_edit.text == "Player":
		name_edit.text = "Player_" + str(randi_range(100, 999))
		
	# Signal connections
	host_button.pressed.connect(_on_host_button_pressed)
	join_button.pressed.connect(_on_join_button_pressed)
	copy_code_button.pressed.connect(_on_copy_code_pressed)
	start_match_button.pressed.connect(_on_start_match_pressed)
	leave_room_button.pressed.connect(_on_leave_room_pressed)
	back_menu_button.pressed.connect(_on_back_menu_pressed)
	
	_apply_pro_styling()
	
	NetworkManager.lobby_updated.connect(_update_lobby_ui)
	NetworkManager.connection_failed.connect(_on_connection_failed)
	NetworkManager.connection_succeeded.connect(_on_connection_succeeded)
	if NetworkManager.has_signal("connection_status_changed"):
		NetworkManager.connection_status_changed.connect(_on_connection_status_changed)


func _on_connection_status_changed(status_text: String) -> void:
	status_label.text = status_text


func _apply_pro_styling() -> void:
	# Style LineEdits
	_style_line_edit(name_edit)
	_style_line_edit(code_edit)
	
	# Style buttons
	_style_btn(host_button, Color(0.05, 0.22, 0.2, 0.95), Color(0.0, 0.5, 0.45, 0.95), Color(0.0, 0.96, 0.83))
	_style_btn(join_button, Color(0.08, 0.12, 0.22, 0.95), Color(0.12, 0.4, 0.55, 0.95), Color(0.0, 0.94, 1.0))
	_style_btn(start_match_button, Color(0.05, 0.22, 0.12, 0.95), Color(0.1, 0.55, 0.25, 0.95), Color(0.2, 1.0, 0.4))
	_style_btn(leave_room_button, Color(0.2, 0.08, 0.1, 0.85), Color(0.45, 0.12, 0.18, 0.95), Color(1.0, 0.2, 0.35))
	_style_btn(back_menu_button, Color(0.12, 0.14, 0.2, 0.85), Color(0.2, 0.24, 0.35, 0.95), Color(0.4, 0.6, 1.0))
	_style_btn(copy_code_button, Color(0.12, 0.18, 0.26, 0.9), Color(0.18, 0.3, 0.45, 0.95), Color(0.0, 0.94, 1.0))
	
	# Style Room Panel Card
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.06, 0.08, 0.14, 0.96)
	panel_style.border_color = Color(0.0, 0.94, 1.0, 0.5)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(16)
	panel_style.shadow_color = Color(0.0, 0.8, 1.0, 0.15)
	panel_style.shadow_size = 20
	room_panel.add_theme_stylebox_override("panel", panel_style)


func _make_box(bg: Color, border: Color, radius: int = 10, pad: int = 10, shadow: Color = Color.TRANSPARENT, shadow_sz: int = 0) -> StyleBoxFlat:
	var box = StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(2)
	box.set_corner_radius_all(radius)
	box.set_content_margin_all(pad)
	if shadow_sz > 0:
		box.shadow_color = shadow
		box.shadow_size = shadow_sz
	return box


func _style_line_edit(le: LineEdit) -> void:
	le.add_theme_stylebox_override("normal", _make_box(Color(0.08, 0.1, 0.16, 0.9), Color(0.0, 0.8, 1.0, 0.4), 10, 8))
	le.add_theme_stylebox_override("focus", _make_box(Color(0.1, 0.14, 0.22, 0.95), Color(0.0, 0.94, 1.0, 0.9), 10, 8, Color(0.0, 0.94, 1.0, 0.25), 10))


func _style_btn(btn: Button, bg: Color, hover_bg: Color, accent: Color) -> void:
	btn.add_theme_stylebox_override("normal", _make_box(bg, Color(accent.r, accent.g, accent.b, 0.4)))
	btn.add_theme_stylebox_override("hover", _make_box(hover_bg, accent, 10, 10, Color(accent.r, accent.g, accent.b, 0.3), 8))
	btn.add_theme_stylebox_override("pressed", _make_box(Color(accent.r * 0.4, accent.g * 0.4, accent.b * 0.4, 0.95), accent))
	btn.add_theme_stylebox_override("focus", btn.get_theme_stylebox("hover"))


func _on_host_button_pressed() -> void:
	var player_name = name_edit.text.strip_edges()
	if player_name == "":
		status_label.text = "Please enter a valid player name!"
		return
		
	var is_priv = private_check.button_pressed
	var manual_bots = int(manual_bots_spin.value)
	
	status_label.text = "Creating room..."
	var ok = NetworkManager.host_room(player_name, is_priv, manual_bots)
	if ok:
		status_label.text = ""
		_show_room_view()


func _on_join_button_pressed() -> void:
	var player_name = name_edit.text.strip_edges()
	var code = code_edit.text.strip_edges()
	
	if player_name == "":
		status_label.text = "Please enter a valid player name!"
		return
	if code.length() < 3:
		status_label.text = "Please enter a valid room code or IP address!"
		return
		
	status_label.text = "Connecting to room " + code.to_upper() + "..."
	join_button.disabled = true
	NetworkManager.join_room_by_code(code, player_name)


func _on_connection_succeeded() -> void:
	join_button.disabled = false
	status_label.text = ""
	_show_room_view()


func _on_connection_failed(reason: String) -> void:
	join_button.disabled = false
	status_label.text = "[ERROR] " + reason


func _show_room_view() -> void:
	mode_tabs.hide()
	back_menu_button.hide()
	room_panel.show()
	_update_lobby_ui()


func _update_lobby_ui() -> void:
	if not room_panel.visible:
		return
		
	if NetworkManager.is_host:
		room_code_label.text = "ROOM CODE: " + NetworkManager.room_code + "  [INTERNET RELAY]"
	else:
		room_code_label.text = "ROOM CODE: " + NetworkManager.room_code
	start_match_button.visible = NetworkManager.is_host
	
	# Clear old player list items
	for child in player_list_box.get_children():
		child.queue_free()
		
	# Populate connected players
	for pid in NetworkManager.connected_players:
		var p_info = NetworkManager.connected_players[pid]
		
		var card = PanelContainer.new()
		var card_style = StyleBoxFlat.new()
		card_style.bg_color = Color(0.1, 0.12, 0.18, 0.85)
		card_style.border_color = Color(1.0, 0.85, 0.3, 0.8) if pid == 1 else Color(0.0, 0.8, 1.0, 0.3)
		card_style.set_border_width_all(1)
		card_style.set_corner_radius_all(8)
		card_style.set_content_margin_all(8)
		card.add_theme_stylebox_override("panel", card_style)
		
		var hbox = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 12)
		
		# Color avatar box
		var avatar = ColorRect.new()
		avatar.custom_minimum_size = Vector2(22, 22)
		avatar.color = p_info.get("color", Color.CYAN)
		hbox.add_child(avatar)
		
		# Name label
		var name_lbl = Label.new()
		name_lbl.text = p_info.get("name", "Player")
		name_lbl.add_theme_font_size_override("font_size", 16)
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(name_lbl)
		
		# Host / You badges
		if pid == 1:
			var host_badge = Label.new()
			host_badge.text = "HOST"
			host_badge.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
			host_badge.add_theme_font_size_override("font_size", 12)
			hbox.add_child(host_badge)
			
		if pid == NetworkManager.get_my_id():
			var me_badge = Label.new()
			me_badge.text = "[YOU]"
			me_badge.add_theme_color_override("font_color", Color(0.2, 0.9, 1.0))
			me_badge.add_theme_font_size_override("font_size", 12)
			hbox.add_child(me_badge)
			
		card.add_child(hbox)
		player_list_box.add_child(card)


func _on_copy_code_pressed() -> void:
	DisplayServer.clipboard_set(NetworkManager.room_code)
	status_label.text = "Room code copied to clipboard!"
	var timer = get_tree().create_timer(2.0)
	timer.timeout.connect(func(): status_label.text = "")


func _on_start_match_pressed() -> void:
	if NetworkManager.is_host:
		NetworkManager.start_multiplayer_match()


func _on_leave_room_pressed() -> void:
	NetworkManager.reset_network()
	room_panel.hide()
	mode_tabs.show()
	back_menu_button.show()
	status_label.text = ""


func _on_back_menu_pressed() -> void:
	NetworkManager.reset_network()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
