extends CanvasLayer

@onready var objective_label: Label = $Root/ObjectivePanel/ObjectiveLabel
@onready var stamina_bar: ProgressBar = $Root/StaminaBox/StaminaBar
@onready var hint_label: Label = $Root/HintLabel
@onready var note_panel: PanelContainer = $Root/NotePanel
@onready var note_text: Label = $Root/NotePanel/Box/NoteText
@onready var fade_rect: ColorRect = $Root/FadeRect
@onready var game_over_label: Label = $Root/GameOverLabel
@onready var interact_prompt: VBoxContainer = $Root/InteractPrompt
@onready var interact_bar: ProgressBar = $Root/InteractPrompt/HoldBar

var player: Node
var using_pad: bool = false # ¿lo último que tocó fue el mando?
const KEYS_TEXT := "WASD moverse · Shift correr · Ctrl agacharse\nF linterna · Mantén E para interactuar · Esc pausa"
const PAD_TEXT := "LS moverse · RS mirar · L3 correr · B agacharse\nY linterna · Mantén A para interactuar · Start pausa"

var hint_count: int = 0

func _ready() -> void:
	GameState.objective_changed.connect(_on_objective_changed)
	GameState.stamina_changed.connect(_on_stamina_changed)
	GameState.note_opened.connect(_on_note_opened)
	GameState.hint_shown.connect(_on_hint_shown)
	GameState.player_caught.connect(_on_player_caught)
	GameState.game_over.connect(_on_game_over)
	GameState.level_won.connect(_on_level_won)
	player = get_tree().get_first_node_in_group("player")
	add_child(load("res://scenes/ui/pause_menu.tscn").instantiate())

# Icono de la E y barra de carga cuando miras algo con lo que puedes interactuar
func _process(_delta: float) -> void:
	if player == null:
		return
	var target = player.get("interact_target")
	interact_prompt.visible = is_instance_valid(target) and not note_panel.visible
	interact_bar.value = player.get("interact_progress")

func _on_objective_changed(text: String) -> void:
	objective_label.text = "OBJETIVO: " + text

func _on_stamina_changed(value: float) -> void:
	stamina_bar.value = value

func _on_note_opened(text: String) -> void:
	note_text.text = text
	note_panel.show()
	GameState.input_locked = true

# Cambia los textos según uses teclado o mando, y cierra la nota con E/X o Esc/B
func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.5):
		set_pad(true)
	elif event is InputEventKey or event is InputEventMouseButton:
		set_pad(false)
	if not note_panel.visible:
		return
	if event.is_action_pressed("interact") or event.is_action_pressed("ui_cancel"):
		note_panel.hide()
		GameState.input_locked = false
		get_viewport().set_input_as_handled()

# Muestra la pista 2.5 s; si llega otra antes, la nueva no se esconde antes de tiempo
func set_pad(value: bool) -> void:
	if value == using_pad:
		return
	using_pad = value
	$Root/InteractPrompt/KeyIcon.text = "A" if using_pad else "E"
	$Root/ControlsLabel.text = PAD_TEXT if using_pad else KEYS_TEXT
	$Root/NotePanel/Box/CloseHint.text = "[A] o [B] para cerrar" if using_pad else "[E] o [Esc] para cerrar"

func _on_hint_shown(text: String) -> void:
	hint_label.text = text
	hint_label.show()
	hint_count += 1
	var my_turn := hint_count
	await get_tree().create_timer(2.5).timeout
	if my_turn == hint_count:
		hint_label.hide()

# Screamer: destello rojo, se ve la cara del guardia, fundido a negro
# (sincronizado con player.gd: teleport a 1.3 s, control a 2.3 s)
func _on_player_caught() -> void:
	fade_rect.color = Color(0.7, 0.0, 0.0, 0.55)
	var tween := create_tween()
	tween.tween_property(fade_rect, "color", Color(0.3, 0.0, 0.0, 0.0), 0.25)
	tween.tween_interval(0.45)
	tween.tween_property(fade_rect, "color", Color(0.0, 0.0, 0.0, 1.0), 0.5)
	tween.tween_interval(0.6)
	tween.tween_property(fade_rect, "color:a", 0.0, 0.5)

func _on_game_over() -> void:
	fade_rect.color = Color(0.7, 0.0, 0.0, 0.55)
	var tween := create_tween()
	tween.tween_property(fade_rect, "color", Color(0.3, 0.0, 0.0, 0.0), 0.25)
	tween.tween_interval(0.45)
	tween.tween_callback(game_over_label.show)
	tween.tween_property(fade_rect, "color", Color(0.0, 0.0, 0.0, 1.0), 0.5)

func _on_level_won() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/EndScreen.tscn")
