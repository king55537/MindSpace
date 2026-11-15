extends CanvasLayer

## UI layer of a playable run: HUD, machine panel and mission evaluation.
##
## The layer only composes and wires its children: the HUD reads the simulation,
## the panel drives the machines and the evaluation presents the summary. This
## script owns the transitions around them (end of the run, restart, back to
## the menu) and the debug control that forces the run to end.

## Node that owns the astronaut the HUD follows for the interaction prompt.
@export var astronaut_path: NodePath = ^"../Astronaut"

## Mission Control guide, instanced at run time so the shared run scene keeps
## only its own nodes.
const TUTORIAL_SCENE: PackedScene = preload(
	"res://scenes/ui/tutorial/tutorial_overlay.tscn"
)

@onready var _hud: IngameHud = $Hud
@onready var _panel: MachinePanel = $MachinePanel
@onready var _debug_button: Button = $DebugEndButton
@onready var _evaluation: Evaluation = $Evaluation

var _astronaut: Astronaut = null
var _tutorial: TutorialOverlay = null


func _ready() -> void:
	_bind_hud_astronaut()
	GameSim.game_over.connect(_on_game_over)
	GameSim.game_reset.connect(_on_game_reset)
	_panel.visibility_changed.connect(_on_panel_visibility_changed)
	_evaluation.restart_requested.connect(_on_restart_requested)
	_evaluation.menu_requested.connect(_on_menu_requested)
	if not EventLog.fact_logged.is_connected(_on_fact_logged):
		EventLog.fact_logged.connect(_on_fact_logged)
	# The forced end of the run is a developer tool: it stays hidden outside
	# debug builds and never takes focus from the game.
	_debug_button.visible = OS.is_debug_build()
	_debug_button.pressed.connect(GameSim.force_end_run)
	_install_tutorial()


## Hands the astronaut to the HUD so it can show the interaction prompt. The
## scene still runs without it, but the prompt stays hidden and the miss is
## reported because it means the scene is wired wrong.
func _bind_hud_astronaut() -> void:
	_astronaut = get_node_or_null(astronaut_path) as Astronaut
	if _astronaut == null:
		push_error(
			"RunUi: astronaut not found at %s; the interaction prompt stays hidden."
			% astronaut_path
		)
		return
	_hud.bind_astronaut(_astronaut)


## Adds the Mission Control guide over the run. The first page opens after one
## frame, once Base has called GameSim.start_run() and the clock is live.
func _install_tutorial() -> void:
	var instance: Node = TUTORIAL_SCENE.instantiate()
	_tutorial = instance as TutorialOverlay
	if _tutorial == null:
		push_error("RunUi: tutorial overlay root is not a TutorialOverlay.")
		instance.queue_free()
		return
	# A CanvasLayer of its own puts the guide above the HUD (layer 10) without
	# touching the shared HUD scene.
	var layer: CanvasLayer = CanvasLayer.new()
	layer.name = "TutorialLayer"
	layer.layer = 30
	add_child(layer)
	layer.add_child(_tutorial)
	_tutorial.help_requested.connect(_on_help_requested)
	_tutorial.closed.connect(_on_tutorial_closed)
	call_deferred(&"_open_initial_tutorial")


func _open_initial_tutorial() -> void:
	if _tutorial == null or TutorialOverlay.has_been_seen():
		return
	_open_tutorial()


## Opens the guide unless a modal panel or the summary already owns the run.
func _open_tutorial() -> void:
	if _tutorial == null or _tutorial.is_open():
		return
	if _panel.visible or GameSim.state.game_over:
		return
	_debug_button.visible = false
	_tutorial.open_tutorial(_astronaut)


func _on_help_requested() -> void:
	_open_tutorial()


## Restores the developer control once the guide is out of the way.
func _on_tutorial_closed() -> void:
	_debug_button.visible = OS.is_debug_build() and not _panel.visible


## Shows the mission summary over the frozen scene.
func _on_game_over(_cause: StringName) -> void:
	if _tutorial != null:
		_tutorial.handle_game_over()
	_evaluation.present()


## The machine panel is modal: while it is open the HUD steps aside so nothing
## overlaps the panel or its buttons.
func _on_panel_visibility_changed() -> void:
	_hud.set_overlay_open(_panel.visible)
	_debug_button.visible = OS.is_debug_build() and not _panel.visible
	if _tutorial != null:
		_tutorial.set_help_available(not _panel.visible)


## Hides the summary so a fresh run starts on the playable scene.
func _on_game_reset() -> void:
	if _tutorial != null:
		_tutorial.reset_for_new_run()
	_evaluation.hide_summary()


## Starts a clean run and rebuilds the playable scene from scratch.
func _on_restart_requested() -> void:
	AudioManager.play(AudioManager.Sfx.UI_OPEN)
	GameSim.new_game()
	get_tree().reload_current_scene()


## Leaves the run and returns to the main menu.
func _on_menu_requested() -> void:
	AudioManager.play(AudioManager.Sfx.UI_CLOSE)
	get_tree().change_scene_to_file("res://scenes/welcome/welcome.tscn")


## Plays the sound owned by an important run fact.
func _on_fact_logged(entry: LogEntry) -> void:
	if entry == null:
		return
	match entry.type:
		LogEntry.Type.REPORT_SENT:
			AudioManager.play(AudioManager.Sfx.REPORT)
		LogEntry.Type.EVENT_STARTED:
			AudioManager.play(AudioManager.Sfx.EVENT)


## Ends the run with the debug action, exactly like the debug button.
func _unhandled_input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return
	if not event.is_action_pressed(&"debug_end_run"):
		return
	GameSim.force_end_run()
	get_viewport().set_input_as_handled()
