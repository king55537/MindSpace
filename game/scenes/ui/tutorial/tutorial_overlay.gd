class_name TutorialOverlay
extends Control

## Mission Control onboarding guide shown at the start of a run.
##
## Four short pages teach the controls and the survival loop. While the guide is
## open the simulation clock is frozen and the astronaut input is locked, so
## reading never costs resources. The first showing is automatic; afterwards the
## guide can be reopened with H or with the HELP button in the corner.

signal help_requested()
signal closed()

const PAGE_COUNT: int = 4
const KEY_SEPARATOR: String = "|"
const HELP_BUTTON_TEXT: String = "HELP (H)"
const ACCENT_COLOR: Color = Color(0.290196, 0.658824, 0.705882, 1.0)
const DETAIL_COLOR: Color = Color(0.619608, 0.698039, 0.784314, 1.0)
const KEY_COLUMN_WIDTH: float = 178.0
const KEY_FONT_SIZE: int = 12
const BODY_FONT_SIZE: int = 14
const FADE_SECONDS: float = 0.18

const TITLES: Array[String] = [
	"WELCOME TO OUTPOST LUNAR",
	"MOVE AND INTERACT",
	"WATCH THE FOUR BARS",
	"REPAIR, SHELTER, SURVIVE",
]

const BODIES: Array[String] = [
	"I'm Aurora, your mission assistant. The outpost is yours: keep the astronaut alive and the machines running.\n\nThis guide takes one minute and pauses the clock. Press H at any time to read it again.",
	"Walk up to a machine and press E. Its panel shows its health and lets you repair it or install upgrades.\n\nThe prompt at the bottom of the screen appears when a machine is within reach.",
	"Oxygen, water, food and energy drain every hour. Keep every bar away from zero: without oxygen you suffocate, and an empty battery shuts the machines down.\n\nThe clock keeps running while a machine panel is open. Use x5 or x10 to pass quiet hours.",
	"Machines wear down and break. Repair them from their panel: it costs energy and takes time.\n\nRadiation only rises outside the shelter and never falls. Return inside, and do not linger outside during a radiation alert.",
]

const KEY_BLOCKS: Array[String] = [
	"",
	"WASD / ARROWS|Move\nE|Open a machine\n1 - 5 / WHEEL|Select a hotbar slot\nSPACE|Pause / resume\n+ / -|Time speed\nH|Reopen this guide",
	"SOLAR ARRAY|Charges the battery in daylight\nO2 SYSTEM|Produces oxygen\nWATER RECYCLER|Produces water\nHYDROPONICS|Produces food and oxygen\nBATTERY|Stores energy for the night\nHEALTH BAR|Top center. Zero ends the run",
	"REPAIR|Spend energy to restore a machine\nUPGRADES|Spend energy on a permanent boost\nSHELTER|The lit ring around the outpost\nRADIATION|Permanent. A high dose lowers max health",
]

## True once the guide has been closed, so a restart does not open it again.
static var _has_been_seen: bool = false

@onready var _modal: Control = %Modal
@onready var _page_label: Label = %PageLabel
@onready var _title_label: Label = %TitleLabel
@onready var _body_label: Label = %BodyLabel
@onready var _keys_grid: GridContainer = %KeysGrid
@onready var _skip_button: Button = %SkipButton
@onready var _back_button: Button = %BackButton
@onready var _next_button: Button = %NextButton
@onready var _help_button: Button = %HelpButton

var _page_index: int = 0
var _is_open: bool = false
## Whether the clock was already paused before the guide opened, so closing it
## never resumes a clock the player had paused on purpose.
var _resume_after_close: bool = false
var _help_available: bool = true
var _astronaut: Astronaut = null


func _ready() -> void:
	_modal.visible = false
	_help_button.text = HELP_BUTTON_TEXT
	_help_button.visible = _help_available
	_back_button.visible = false
	_skip_button.pressed.connect(close_tutorial)
	_back_button.pressed.connect(_on_back_pressed)
	_next_button.pressed.connect(_on_next_pressed)
	_help_button.pressed.connect(_on_help_pressed)
	_title_label.add_theme_font_size_override(&"font_size", 20)
	_body_label.add_theme_font_size_override(&"font_size", BODY_FONT_SIZE)
	_page_label.add_theme_color_override(&"font_color", DETAIL_COLOR)
	_show_page()


## Opens the guide over the run and freezes it. A null astronaut is allowed for
## preview scenes; the input lock is then skipped.
func open_tutorial(astronaut: Astronaut) -> void:
	if _is_open or GameSim.state.game_over:
		return
	_astronaut = astronaut
	_resume_after_close = not GameSim.is_paused()
	GameSim.set_paused(true)
	if _astronaut != null and is_instance_valid(_astronaut):
		_astronaut.set_input_locked(true)
	_is_open = true
	_page_index = 0
	_help_button.visible = false
	_modal.visible = true
	_modal.modulate.a = 0.0
	var tween: Tween = create_tween()
	tween.tween_property(_modal, "modulate:a", 1.0, FADE_SECONDS)
	_show_page()
	AudioManager.play(AudioManager.Sfx.UI_OPEN)
	_next_button.grab_focus()


## Closes the guide, restores the clock and gives the input back to the
## astronaut. Closing an already closed guide does nothing.
func close_tutorial() -> void:
	if not _is_open:
		return
	_is_open = false
	_has_been_seen = true
	_modal.visible = false
	_help_button.visible = _help_available
	_unlock_astronaut()
	if _resume_after_close:
		GameSim.set_paused(false)
	_resume_after_close = false
	AudioManager.play(AudioManager.Sfx.UI_CLOSE)
	closed.emit()


func is_open() -> bool:
	return _is_open


## Whether the automatic first showing has already happened in this session.
static func has_been_seen() -> bool:
	return _has_been_seen


## Hides the guide without resuming the clock, used when the run ends while the
## guide is open.
func handle_game_over() -> void:
	_resume_after_close = false
	_force_hide()


## Returns the guide to its idle state for a new run.
func reset_for_new_run() -> void:
	_force_hide()
	_help_available = true
	_help_button.visible = true


## Shows or hides the corner HELP button. The machine panel hides it so the
## guide can never open on top of a panel.
func set_help_available(available: bool) -> void:
	_help_available = available
	if not _is_open:
		_help_button.visible = available and not GameSim.state.game_over


func _force_hide() -> void:
	_is_open = false
	_modal.visible = false
	_help_button.visible = false
	_unlock_astronaut()


func _unlock_astronaut() -> void:
	if _astronaut != null and is_instance_valid(_astronaut):
		_astronaut.set_input_locked(false)
	_astronaut = null


func _show_page() -> void:
	_page_index = clampi(_page_index, 0, PAGE_COUNT - 1)
	_title_label.text = TITLES[_page_index]
	_body_label.text = BODIES[_page_index]
	_page_label.text = "%02d / %02d" % [_page_index + 1, PAGE_COUNT]
	_back_button.visible = _page_index > 0
	_next_button.text = "Start mission" if _page_index == PAGE_COUNT - 1 else "Next"
	_build_keys(KEY_BLOCKS[_page_index])


## Rebuilds the two-column key table of the current page. An empty block leaves
## the table hidden and the body keeps the free space.
func _build_keys(block: String) -> void:
	for child: Node in _keys_grid.get_children():
		_keys_grid.remove_child(child)
		child.queue_free()
	_keys_grid.visible = not block.is_empty()
	if block.is_empty():
		return
	var lines: PackedStringArray = block.split("\n")
	for line: String in lines:
		if line.is_empty():
			continue
		var parts: PackedStringArray = line.split(KEY_SEPARATOR)
		if parts.size() < 2:
			continue
		_keys_grid.add_child(_make_key_label(parts[0]))
		_keys_grid.add_child(_make_action_label(parts[1]))


func _make_key_label(text: String) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(KEY_COLUMN_WIDTH, 0.0)
	label.add_theme_color_override(&"font_color", ACCENT_COLOR)
	label.add_theme_font_size_override(&"font_size", KEY_FONT_SIZE)
	return label


func _make_action_label(text: String) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override(&"font_size", KEY_FONT_SIZE)
	return label


func _on_next_pressed() -> void:
	AudioManager.play(AudioManager.Sfx.UI_CLICK)
	if _page_index >= PAGE_COUNT - 1:
		close_tutorial()
		return
	_page_index += 1
	_show_page()
	_next_button.grab_focus()


func _on_back_pressed() -> void:
	if _page_index <= 0:
		return
	AudioManager.play(AudioManager.Sfx.UI_CLICK)
	_page_index -= 1
	_show_page()
	_next_button.grab_focus()


func _on_help_pressed() -> void:
	help_requested.emit()


## H reopens the guide, Escape or H closes it while it is open. The event is
## consumed so movement and interaction never see it.
func _unhandled_input(event: InputEvent) -> void:
	if _is_open:
		if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"tutorial_help"):
			close_tutorial()
			get_viewport().set_input_as_handled()
			return
		# The guide owns the clock: time keys must not resume or accelerate it
		# behind the overlay.
		if (
			event.is_action_pressed(&"pause")
			or event.is_action_pressed(&"speed_up")
			or event.is_action_pressed(&"speed_down")
		):
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"tutorial_help"):
		help_requested.emit()
		get_viewport().set_input_as_handled()
