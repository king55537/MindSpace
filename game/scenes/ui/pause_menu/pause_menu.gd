class_name PauseMenu
extends CanvasLayer

## Pause overlay for the playable scene.
##
## It is a self-contained CanvasLayer: add it as a child of any playable scene
## and press ESC to open it. Opening freezes the scene tree and the GameSim
## clock; closing restores the clock state the run had before the pause, so a
## run that was already frozen is never resumed by accident.

const SETTINGS_SCENE: String = "res://scenes/settings/settings.tscn"
const TOAST_HOLD_SECONDS: float = 2.0
const TOAST_FADE_SECONDS: float = 0.4

@onready var _root: Control = %Root
@onready var _resume_button: Button = %ResumeButton
@onready var _toast: Label = %Toast

var _is_open: bool = false
var _clock_was_paused: bool = true
var _toast_tween: Tween = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root.hide()
	_toast.modulate.a = 0.0


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if _is_open:
		close()
	else:
		open()
	get_viewport().set_input_as_handled()


## True while the overlay is on screen and the tree is frozen.
func is_open() -> bool:
	return _is_open


## Freezes the tree and the clock and gives the focus to the first action.
func open() -> void:
	if _is_open:
		return
	_is_open = true
	_clock_was_paused = GameSim.is_paused()
	GameSim.set_paused(true)
	get_tree().paused = true
	_root.show()
	_resume_button.grab_focus()


## Hides the overlay and restores the tree and the clock state from before the
## pause. The simulation accumulator is never touched, so time does not jump.
func close() -> void:
	if not _is_open:
		return
	_is_open = false
	_root.hide()
	get_tree().paused = false
	GameSim.set_paused(_clock_was_paused)


func _on_resume_pressed() -> void:
	close()


func _on_settings_pressed() -> void:
	if ResourceLoader.exists(SETTINGS_SCENE):
		_leave_to(SETTINGS_SCENE)
		return
	_show_toast("Settings: coming soon.")


func _on_save_exit_pressed() -> void:
	if not GameSim.run_active:
		_show_toast("There is no active game to save.")
		return
	var scene: Node = get_tree().current_scene
	var scene_path: String = ""
	var player_position: Vector2 = Vector2.ZERO
	if scene != null:
		scene_path = scene.scene_file_path
		var player_node: Node = scene.get_node_or_null("Astronaut")
		if player_node is Node2D:
			var player_2d: Node2D = player_node
			player_position = player_2d.global_position
	var saved: bool = SaveManager.save_run(
		GameSim.state,
		EventLog.get_entries(),
		scene_path,
		WorldStore.selected,
		player_position,
		int(GameSim.speed)
	)
	if not saved:
		_show_toast(SaveManager.get_last_error())
		return
	_leave_to(SaveManager.WELCOME_SCENE)


## Leaves the pause before changing scenes, so the next scene is not born with
## the tree paused.
func _leave_to(scene_path: String) -> void:
	close()
	var error: Error = get_tree().change_scene_to_file(scene_path)
	if error != OK:
		push_error("PauseMenu: could not open %s (error %d)." % [scene_path, error])
		open()
		_show_toast("Could not open the next screen (error %d)." % error)


## Shows a temporary message inside the panel. The tween keeps running while
## the tree is paused.
func _show_toast(message: String) -> void:
	var text: String = message
	if text.is_empty():
		text = "The action could not be completed."
	_toast.text = text
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast.modulate.a = 1.0
	_toast_tween = create_tween()
	_toast_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_toast_tween.tween_interval(TOAST_HOLD_SECONDS)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, TOAST_FADE_SECONDS)
