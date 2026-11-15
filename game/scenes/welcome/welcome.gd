extends Control
## Game's entry menu.
##
## Title screen with the main actions. It is part of item 20 of the formal
## design (`docs/designs/junior-astronauta-outpost-lunar.md`), which still plans
## to add the mission selector here: 1 playable mission and 2 grey "coming soon"
## rows (see `docs/future/selector-mision.md`).

## Scene the "Start game" button goes to: the worlds screen.
const START_SCENE: String = "res://scenes/worlds/worlds.tscn"

## Scene the "Settings" button goes to once it exists.
const SETTINGS_SCENE: String = "res://scenes/settings/settings.tscn"

## Seconds the toast stays visible before fading out.
const TOAST_HOLD_SECONDS: float = 2.0

## Seconds the toast takes to fade out.
const TOAST_FADE_SECONDS: float = 0.4

@onready var _continue_button: Button = %ContinueButton
@onready var _play_button: Button = %PlayButton
@onready var _toast: Label = %Toast

var _toast_tween: Tween = null


func _ready() -> void:
	_toast.modulate.a = 0.0
	_continue_button.visible = SaveManager.has_save()
	if _continue_button.visible:
		_continue_button.grab_focus()
	else:
		_play_button.grab_focus()


## Resumes the saved run without replaying the worlds screen or the intro.
func _on_continue_pressed() -> void:
	_continue_button.disabled = true
	if not SaveManager.request_load(GameSim.get_events()):
		_continue_button.disabled = false
		_show_toast(SaveManager.get_last_error())
		return

	var scene_path: String = SaveManager.get_pending_scene_path()
	if scene_path.is_empty() or not ResourceLoader.exists(scene_path):
		SaveManager.clear_pending()
		_continue_button.disabled = false
		_show_toast("The saved game points to a missing scene.")
		return

	var world: World = SaveManager.get_pending_world()
	if world != null:
		WorldStore.select(world)

	var error: Error = get_tree().change_scene_to_file(scene_path)
	if error != OK:
		SaveManager.clear_pending()
		_continue_button.disabled = false
		_show_toast("Could not open the saved game (error %d)." % error)


func _on_play_pressed() -> void:
	SaveManager.clear_pending()
	if not ResourceLoader.exists(START_SCENE):
		_show_toast("Cannot find the worlds screen (%s)." % START_SCENE)
		return
	var error: Error = get_tree().change_scene_to_file(START_SCENE)
	if error != OK:
		_show_toast("Could not open the worlds screen (error %d)." % error)


func _on_options_pressed() -> void:
	if ResourceLoader.exists(SETTINGS_SCENE):
		get_tree().change_scene_to_file(SETTINGS_SCENE)
		return
	_show_toast("Settings: coming soon.")


## Shows a temporary toast at the bottom of the menu.
func _show_toast(message: String) -> void:
	_toast.text = message
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast.modulate.a = 1.0
	_toast_tween = create_tween()
	_toast_tween.tween_interval(TOAST_HOLD_SECONDS)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, TOAST_FADE_SECONDS)
