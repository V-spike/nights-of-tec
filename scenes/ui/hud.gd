extends CanvasLayer

@onready var objective_label: Label = $Root/ObjectivePanel/ObjectiveLabel
@onready var stamina_bar: ProgressBar = $Root/StaminaBox/StaminaBar
@onready var hint_label: Label = $Root/HintLabel
@onready var note_panel: PanelContainer = $Root/NotePanel
@onready var note_text: Label = $Root/NotePanel/Box/NoteText
@onready var fade_rect: ColorRect = $Root/FadeRect
@onready var game_over_label: Label = $Root/GameOverLabel

var hint_count: int = 0

func _ready() -> void:
	GameState.objective_changed.connect(_on_objective_changed)
	GameState.stamina_changed.connect(_on_stamina_changed)
	GameState.note_opened.connect(_on_note_opened)
	GameState.hint_shown.connect(_on_hint_shown)
	GameState.player_caught.connect(_on_player_caught)
	GameState.game_over.connect(_on_game_over)
	GameState.level_won.connect(_on_level_won)

func _on_objective_changed(text: String) -> void:
	objective_label.text = "OBJETIVO: " + text

func _on_stamina_changed(value: float) -> void:
	stamina_bar.value = value

func _on_note_opened(text: String) -> void:
	note_text.text = text
	note_panel.show()
	GameState.input_locked = true

# Cierra la nota con E o Esc
func _input(event: InputEvent) -> void:
	if not note_panel.visible:
		return
	if event.is_action_pressed("interact") or event.is_action_pressed("ui_cancel"):
		note_panel.hide()
		GameState.input_locked = false
		get_viewport().set_input_as_handled()

# Muestra la pista 2.5 s; si llega otra antes, la nueva no se esconde antes de tiempo
func _on_hint_shown(text: String) -> void:
	hint_label.text = text
	hint_label.show()
	hint_count += 1
	var my_turn := hint_count
	await get_tree().create_timer(2.5).timeout
	if my_turn == hint_count:
		hint_label.hide()

# Fundido a negro sincronizado con player.gd (teleport a 0.6 s, control a 2.0 s)
func _on_player_caught() -> void:
	var tween := create_tween()
	tween.tween_property(fade_rect, "color:a", 1.0, 0.5)
	tween.tween_interval(0.9)
	tween.tween_property(fade_rect, "color:a", 0.0, 0.5)

func _on_game_over() -> void:
	game_over_label.show()
	var tween := create_tween()
	tween.tween_property(fade_rect, "color:a", 1.0, 0.5)

func _on_level_won() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/EndScreen.tscn")
