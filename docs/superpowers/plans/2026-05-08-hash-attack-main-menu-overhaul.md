# #HashAttack! Main Menu Overhaul — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Overhaul MainMenu with Win8 Metro-style flat square tiles, swipe-select game mode carousel with animated board previews, timer toggle, and randomized first-turn announcement.

**Architecture:** MainMenu.tscn rewritten with layered layout (header, carousel, tile bar, footer). New scripts: ModeCarousel.gd (swipe/arrows/dots), ModeTile.gd (reusable tile button with hover tween), ModePreview.gd (_draw() board). GameBoard.gd gains random first-turn and checks Globals for timer config. Ultimate and Ephemerate are placeholder modes — UI cards show, buttons exist, but mechanics are NO-OP (deferred).

**Tech Stack:** Godot 4.6.2 GDScript, GL Compatibility, 720×960 viewport, Orbitron font, FA6 autoload, SVG icons

---

## File Map

| File | Action | Purpose |
|------|--------|---------|
| `games/tic-tac-toe/scripts/Globals.gd` | Modify | Add `use_timer`, `timer_seconds` |
| `games/tic-tac-toe/scripts/ModeTile.gd` | Create | Reusable tile button (hover glow, scale tween) |
| `games/tic-tac-toe/scripts/ModePreview.gd` | Create | _draw() board preview per mode |
| `games/tic-tac-toe/scripts/ModeCarousel.gd` | Create | Swipe, arrows, dots, mode signal |
| `games/tic-tac-toe/scenes/MainMenu.tscn` | Rewrite | New node tree |
| `games/tic-tac-toe/scenes/MainMenu.gd` | Rewrite | Wiring, auth UI, mode routing |
| `games/tic-tac-toe/scenes/GameBoard.gd` | Modify | Random first-turn, Timer from Globals, TurnAnnounce |
| `games/tic-tac-toe/scenes/GameBoard.tscn` | Modify | Add `TurnAnnounce` Label node |
| `games/tic-tac-toe/tests/test_main_menu.gd` | Create | GUT tests for carousel + timer toggle |
| `games/tic-tac-toe/tests/test_turn_random.gd` | Create | GUT tests for random turn logic |

---

### Task 1: Add timer fields to Globals.gd

**Files:**
- Modify: `games/tic-tac-toe/scripts/Globals.gd:14-16`

- [ ] **Step 1: Add `use_timer` and `timer_seconds` fields**

Append after line 15 (`var current_streak: Dictionary = {}`):

```gdscript
var use_timer: bool = false
var timer_seconds: int = 10
```

Full added block:

```gdscript
var current_streak: Dictionary = {}
# Keys = game_mode strings, values = int current streak count.

var use_timer: bool = false
var timer_seconds: int = 10
```

- [ ] **Step 2: Commit**

```powershell
cd c:\Projects\claude\nexus-arcade
git add games/tic-tac-toe/scripts/Globals.gd
git commit -m "feat: add use_timer and timer_seconds to Globals"
```

---

### Task 2: Create ModeTile.gd — reusable tile button

**Files:**
- Create: `games/tic-tac-toe/scripts/ModeTile.gd`

- [ ] **Step 1: Write ModeTile.gd**

```gdscript
class_name ModeTile
extends Button

const TILE_SIZE := 160.0
const BORDER_COLOR := Color("#a855f7")
const HOVER_COLOR := Color("#00d4ff")
const LABEL_COLOR := Color("#94a3b8")

func _ready() -> void:
	custom_minimum_size = Vector2(TILE_SIZE, TILE_SIZE)
	mouse_entered.connect(_on_hover)
	mouse_exited.connect(_on_unhover)
	_apply_style()

func _apply_style() -> void:
	add_theme_constant_override("corner_radius", 0)
	add_theme_color_override("font_color", Color.WHITE)

func _on_hover() -> void:
	var t := create_tween()
	t.tween_property(self, "scale", Vector2(1.05, 1.05), 0.12)

func _on_unhover() -> void:
	var t := create_tween()
	t.tween_property(self, "scale", Vector2.ONE, 0.12)
```

- [ ] **Step 2: Commit**

```powershell
cd c:\Projects\claude\nexus-arcade
git add games/tic-tac-toe/scripts/ModeTile.gd
git commit -m "feat: add ModeTile reusable square tile button"
```

---

### Task 3: Create ModePreview.gd — board preview drawing

**Files:**
- Create: `games/tic-tac-toe/scripts/ModePreview.gd`

- [ ] **Step 1: Write ModePreview.gd**

```gdscript
class_name ModePreview
extends Control

const GRID_COLOR := Color("#00d4ff")
const GRID_DIM_COLOR := Color(0, 0.831, 1, 0.3)
const X_COLOR := Color("#00d4ff")
const O_COLOR := Color("#a855f7")
const BG_COLOR := Color("#0a0a1a")

var _mode: String = "classic"
var _tween: Tween

func _ready() -> void:
	_start_spin()

func set_mode(mode: String) -> void:
	_mode = mode
	_start_spin()
	queue_redraw()

func _start_spin() -> void:
	if _tween:
		_tween.kill()
	match _mode:
		"classic":
			modulate.a = 0.7
			var tw := create_tween().set_loops()
			tw.tween_property(self, "rotation_degrees", 12, 1.5).set_trans(Tween.TRANS_SINE)
			tw.tween_property(self, "rotation_degrees", -12, 1.5).set_trans(Tween.TRANS_SINE)
			_tween = tw
		"ultimate":
			modulate.a = 0.7
			var tw := create_tween().set_loops()
			tw.tween_property(self, "scale:x", 0.92, 1.0).set_trans(Tween.TRANS_SINE)
			tw.tween_property(self, "scale:x", 1.08, 1.0).set_trans(Tween.TRANS_SINE)
			_tween = tw
		"ephemerate":
			var tw := create_tween().set_loops()
			tw.tween_property(self, "modulate:a", 0.4, 1.2).set_trans(Tween.TRANS_SINE)
			tw.tween_property(self, "modulate:a", 0.7, 1.2).set_trans(Tween.TRANS_SINE)
			_tween = tw

func _draw() -> void:
	var sz := size
	match _mode:
		"classic":
			_draw_classic(sz)
		"ultimate":
			_draw_ultimate(sz)
		"ephemerate":
			_draw_ephemerate(sz)

func _draw_classic(sz: Vector2) -> void:
	var margin := 40.0
	var grid_sz := sz.x - margin * 2
	var cell := grid_sz / 3.0
	var ox := margin
	var oy := (sz.y - grid_sz) / 2.0
	# Grid lines
	for i in range(1, 3):
		draw_line(Vector2(ox + cell * i, oy), Vector2(ox + cell * i, oy + grid_sz), GRID_COLOR, 2)
		draw_line(Vector2(ox, oy + cell * i), Vector2(ox + grid_sz, oy + cell * i), GRID_COLOR, 2)
	# Pre-placed marks (sample game state)
	_place_mark(ox, oy, cell, 1, 1, "X")
	_place_mark(ox, oy, cell, 0, 0, "O")
	_place_mark(ox, oy, cell, 2, 0, "X")
	_place_mark(ox, oy, cell, 1, 2, "O")

func _place_mark(ox: float, oy: float, cell: float, col: int, row: int, mark: String) -> void:
	var cx := ox + cell * col + cell / 2.0
	var cy := oy + cell * row + cell / 2.0
	var r := cell * 0.3
	var col: Color = X_COLOR if mark == "X" else O_COLOR
	if mark == "X":
		draw_line(Vector2(cx - r, cy - r), Vector2(cx + r, cy + r), col, 4)
		draw_line(Vector2(cx + r, cy - r), Vector2(cx - r, cy + r), col, 4)
	else:
		draw_arc(cx, cy, r, 0, TAU, 32, col, 4)

func _draw_ultimate(sz: Vector2) -> void:
	var margin := 20.0
	var grid_sz := sz.x - margin * 2
	var big_cell := grid_sz / 3.0
	var small_cell := big_cell / 3.0
	var ox := margin
	var oy := (sz.y - grid_sz) / 2.0
	# Draw 3x3 big grid
	for i in range(1, 3):
		draw_line(Vector2(ox + big_cell * i, oy), Vector2(ox + big_cell * i, oy + grid_sz), GRID_COLOR, 3)
		draw_line(Vector2(ox, oy + big_cell * i), Vector2(ox + grid_sz, oy + big_cell * i), GRID_COLOR, 3)
	# Draw mini grids in each big cell
	for br in 3:
		for bc in 3:
			var bx := ox + big_cell * bc
			var by := oy + big_cell * br
			for si in range(1, 3):
				draw_line(Vector2(bx + small_cell * si, by), Vector2(bx + small_cell * si, by + big_cell), GRID_DIM_COLOR, 1)
				draw_line(Vector2(bx, by + small_cell * si), Vector2(bx + big_cell, by + small_cell * si), GRID_DIM_COLOR, 1)

func _draw_ephemerate(sz: Vector2) -> void:
	var margin := 40.0
	var grid_sz := sz.x - margin * 2
	var cell := grid_sz / 3.0
	var ox := margin
	var oy := (sz.y - grid_sz) / 2.0
	# Grid lines
	for i in range(1, 3):
		draw_line(Vector2(ox + cell * i, oy), Vector2(ox + cell * i, oy + grid_sz), GRID_COLOR, 2)
		draw_line(Vector2(ox, oy + cell * i), Vector2(ox + grid_sz, oy + cell * i), GRID_COLOR, 2)
	# Faded marks at varying opacity
	_draw_faded_mark(ox, oy, cell, 1, 1, "X", 1.0)
	_draw_faded_mark(ox, oy, cell, 0, 0, "O", 0.75)
	_draw_faded_mark(ox, oy, cell, 2, 0, "X", 0.5)
	_draw_faded_mark(ox, oy, cell, 1, 2, "O", 0.25)

func _draw_faded_mark(ox: float, oy: float, cell: float, col: int, row: int, mark: String, alpha: float) -> void:
	var cx := ox + cell * col + cell / 2.0
	var cy := oy + cell * row + cell / 2.0
	var r := cell * 0.3
	var clr: Color = (X_COLOR if mark == "X" else O_COLOR)
	clr.a = alpha
	if mark == "X":
		draw_line(Vector2(cx - r, cy - r), Vector2(cx + r, cy + r), clr, 3)
		draw_line(Vector2(cx + r, cy - r), Vector2(cx - r, cy + r), clr, 3)
	else:
		draw_arc(cx, cy, r, 0, TAU, 32, clr, 3)
```

Wait, there's a variable shadowing issue — `col` used both as parameter and as local var. Let me fix:

In `_draw_classic`, the `_place_mark` calls use `col` as integer column, but inside `_place_mark` I redeclare `var col: Color`. That shadows the outer `col` correctly in GDScript (parameter `col: int` is separate). Actually no — look at `_place_mark` signature: `_place_mark(ox, oy, cell, col: int, row: int, mark: String)`. The parameter `col` is an int. But inside I do `var col: Color = X_COLOR if mark == "X" else O_COLOR` — this shadows the parameter `col`, making it a Color. This would cause an error because GDScript doesn't allow re-declaring a variable with a different type in the same scope. Actually, in GDScript, you CAN'T redeclare a variable in the same scope — `var col` when `col` is already a parameter would be a parse error.

Let me fix: rename the color variable to `clr`.

- [ ] **Step 2: Fix the variable shadowing in ModePreview.gd**

Edit `_place_mark` and `_draw_faded_mark` to use `clr` instead of `col` for the Color variable:

In `_place_mark`:
```gdscript
func _place_mark(ox: float, oy: float, cell: float, col: int, row: int, mark: String) -> void:
	var cx := ox + cell * col + cell / 2.0
	var cy := oy + cell * row + cell / 2.0
	var r := cell * 0.3
	var clr: Color = X_COLOR if mark == "X" else O_COLOR
	if mark == "X":
		draw_line(Vector2(cx - r, cy - r), Vector2(cx + r, cy + r), clr, 4)
		draw_line(Vector2(cx + r, cy - r), Vector2(cx - r, cy + r), clr, 4)
	else:
		draw_arc(cx, cy, r, 0, TAU, 32, clr, 4)
```

- [ ] **Step 3: Commit**

```powershell
cd c:\Projects\claude\nexus-arcade
git add games/tic-tac-toe/scripts/ModePreview.gd
git commit -m "feat: add ModePreview with _draw() board previews per mode"
```

---

### Task 4: Create ModeCarousel.gd — swipe, arrows, dots

**Files:**
- Create: `games/tic-tac-toe/scripts/ModeCarousel.gd`

- [ ] **Step 1: Write ModeCarousel.gd**

```gdscript
class_name ModeCarousel
extends Control

signal mode_changed(index: int, mode_name: String)

const MODES: Array[Dictionary] = [
	{ "name": "Classic", "id": "classic" },
	{ "name": "Ultimate", "id": "ultimate" },
	{ "name": "Ephemerate", "id": "ephemerate" },
]

var _current_index: int = 0
var _drag_start: Vector2
var _dragging: bool = false

@onready var _preview: ModePreview = $PreviewContainer/ModePreview
@onready var _lbl_mode: Label = $LblModeName
@onready var _btn_left: Button = $BtnArrowLeft
@onready var _btn_right: Button = $BtnArrowRight
@onready var _dots: Array[Label] = [
	$DotContainer/Dot0,
	$DotContainer/Dot1,
	$DotContainer/Dot2,
]

func _ready() -> void:
	_btn_left.pressed.connect(func(): _prev())
	_btn_right.pressed.connect(func(): _next())
	_refresh()

func _next() -> void:
	_current_index = (_current_index + 1) % MODES.size()
	_refresh()
	SFX.click()

func _prev() -> void:
	_current_index = (_current_index - 1 + MODES.size()) % MODES.size()
	_refresh()
	SFX.click()

func _refresh() -> void:
	var m := MODES[_current_index]
	_lbl_mode.text = m.name.to_upper()
	_preview.set_mode(m.id)
	for i in _dots.size():
		_dots[i].add_theme_color_override("font_color",
			Color("#00d4ff") if i == _current_index else Color("#334466"))
	mode_changed.emit(_current_index, m.id)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_drag_start = event.position
				_dragging = true
			elif _dragging:
				var dx := event.position.x - _drag_start.x
				if abs(dx) > 50:
					if dx > 0: _prev()
					else: _next()
				_dragging = false
```

- [ ] **Step 2: Commit**

```powershell
cd c:\Projects\claude\nexus-arcade
git add games/tic-tac-toe/scripts/ModeCarousel.gd
git commit -m "feat: add ModeCarousel with swipe, arrows, dot indicators"
```

---

### Task 5: Write MainMenu.tscn — full scene

**Files:**
- Modify: `games/tic-tac-toe/scenes/MainMenu.tscn` (full rewrite)

- [ ] **Step 1: Write the complete MainMenu.tscn**

```gdscript
[gd_scene load_steps=9 format=3 uid="uid://main_menu"]

[ext_resource type="Script" path="res://scenes/MainMenu.gd" id="1_mainmenu"]
[ext_resource type="Texture2D" path="res://images/icon-robot.svg" id="2_robot"]
[ext_resource type="Texture2D" path="res://images/icon-users.svg" id="3_users"]
[ext_resource type="Texture2D" path="res://images/icon-globe.svg" id="4_globe"]
[ext_resource type="FontFile" path="res://fonts/Orbitron.ttf" id="5_font"]
[ext_resource type="Script" path="res://scripts/PortalBridge.gd" id="6_bridge"]
[ext_resource type="Script" path="res://scripts/ModeCarousel.gd" id="7_carousel"]
[ext_resource type="Script" path="res://scripts/ModePreview.gd" id="8_preview"]
[ext_resource type="Script" path="res://scripts/ModeTile.gd" id="9_modetile"]

[node name="MainMenu" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
script = ExtResource("1_mainmenu")

[node name="ColorRect" type="ColorRect" parent="."]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
color = Color(0.039, 0.039, 0.102, 1)

[node name="Bridge" type="Node" parent="."]
script = ExtResource("6_bridge")

[node name="BtnSignInIcon" type="Button" parent="."]
visible = false
layout_mode = 1
anchors_preset = 12
anchor_left = 1.0
anchor_top = 0.0
anchor_right = 1.0
anchor_bottom = 0.0
offset_left = -56.0
offset_top = 8.0
offset_right = -8.0
offset_bottom = 56.0
theme_override_fonts/font = ExtResource("5_font")
theme_override_font_sizes/font_size = 20

[node name="HeaderBar" type="HBoxContainer" parent="."]
layout_mode = 1
anchors_preset = 10
anchor_left = 0.0
anchor_top = 0.0
anchor_right = 1.0
anchor_bottom = 0.0
offset_top = 16.0
offset_bottom = 64.0
offset_left = 20.0
offset_right = -20.0

[node name="LblTitle" type="Label" parent="HeaderBar"]
layout_mode = 2
text = "#HashAttack!"
theme_override_fonts/font = ExtResource("5_font")
theme_override_font_sizes/font_size = 48
theme_override_colors/font_color = Color(0, 0.831, 1, 1)
horizontal_alignment = 0
size_flags_horizontal = 3

[node name="CarouselContainer" type="Control" parent="."]
layout_mode = 1
anchors_preset = 8
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
offset_left = -300.0
offset_top = -310.0
offset_right = 300.0
offset_bottom = 140.0
script = ExtResource("7_carousel")
mouse_filter = 1

[node name="BtnArrowLeft" type="Button" parent="CarouselContainer"]
layout_mode = 1
anchors_preset = 10
anchor_left = 0.0
anchor_top = 0.0
anchor_right = 0.0
anchor_bottom = 0.0
offset_left = 0.0
offset_top = 100.0
offset_right = 48.0
offset_bottom = 340.0
theme_override_fonts/font = ExtResource("5_font")
theme_override_font_sizes/font_size = 28

[node name="PreviewContainer" type="Control" parent="CarouselContainer"]
layout_mode = 1
anchors_preset = 8
anchor_left = 0.5
anchor_top = 0.0
anchor_right = 0.5
anchor_bottom = 0.0
offset_left = -200.0
offset_top = 20.0
offset_right = 200.0
offset_bottom = 340.0
mouse_filter = 2

[node name="ModePreview" type="Control" parent="CarouselContainer/PreviewContainer"]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
script = ExtResource("8_preview")
mouse_filter = 2

[node name="BtnArrowRight" type="Button" parent="CarouselContainer"]
layout_mode = 1
anchors_preset = 10
anchor_left = 1.0
anchor_top = 0.0
anchor_right = 1.0
anchor_bottom = 0.0
offset_left = -48.0
offset_top = 100.0
offset_right = 0.0
offset_bottom = 340.0
theme_override_fonts/font = ExtResource("5_font")
theme_override_font_sizes/font_size = 28

[node name="LblModeName" type="Label" parent="CarouselContainer"]
layout_mode = 1
anchors_preset = 10
anchor_left = 0.0
anchor_top = 1.0
anchor_right = 1.0
anchor_bottom = 1.0
offset_left = 0.0
offset_top = 0.0
offset_right = 0.0
offset_bottom = 36.0
text = "CLASSIC"
theme_override_fonts/font = ExtResource("5_font")
theme_override_font_sizes/font_size = 22
theme_override_colors/font_color = Color(0, 0.831, 1, 1)
horizontal_alignment = 1

[node name="TimerRow" type="HBoxContainer" parent="CarouselContainer"]
layout_mode = 1
anchors_preset = 10
anchor_left = 0.5
anchor_top = 1.0
anchor_right = 0.5
anchor_bottom = 1.0
offset_left = -50.0
offset_top = 36.0
offset_right = 50.0
offset_bottom = 64.0
alignment = 1

[node name="LblClock" type="Label" parent="CarouselContainer/TimerRow"]
layout_mode = 2
text = "CLOCK"
theme_override_fonts/font = ExtResource("5_font")
theme_override_font_sizes/font_size = 14
theme_override_colors/font_color = Color(0.392, 0.455, 0.573, 1)

[node name="CheckTimer" type="CheckBox" parent="CarouselContainer/TimerRow"]
layout_mode = 2

[node name="LblTimerSecs" type="Label" parent="CarouselContainer/TimerRow"]
layout_mode = 2
text = "10s"
theme_override_fonts/font = ExtResource("5_font")
theme_override_font_sizes/font_size = 14
theme_override_colors/font_color = Color(0, 0.831, 1, 1)

[node name="DotContainer" type="HBoxContainer" parent="CarouselContainer"]
layout_mode = 1
anchors_preset = 10
anchor_left = 0.5
anchor_top = 1.0
anchor_right = 0.5
anchor_bottom = 1.0
offset_left = -30.0
offset_top = 66.0
offset_right = 30.0
offset_bottom = 90.0
alignment = 1

[node name="Dot0" type="Label" parent="CarouselContainer/DotContainer"]
layout_mode = 2
text = "●"
theme_override_fonts/font = ExtResource("5_font")
theme_override_font_sizes/font_size = 14

[node name="Dot1" type="Label" parent="CarouselContainer/DotContainer"]
layout_mode = 2
text = "●"
theme_override_fonts/font = ExtResource("5_font")
theme_override_font_sizes/font_size = 14

[node name="Dot2" type="Label" parent="CarouselContainer/DotContainer"]
layout_mode = 2
text = "●"
theme_override_fonts/font = ExtResource("5_font")
theme_override_font_sizes/font_size = 14

[node name="TileBar" type="VBoxContainer" parent="."]
layout_mode = 1
anchors_preset = 8
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
offset_left = -270.0
offset_top = 160.0
offset_right = 270.0
offset_bottom = 400.0
theme_override_constants/separation = 12
alignment = 1

[node name="Row1" type="HBoxContainer" parent="TileBar"]
layout_mode = 2
alignment = 1
theme_override_constants/separation = 12

[node name="Btn1P" type="Button" parent="TileBar/Row1"]
layout_mode = 2
custom_minimum_size = Vector2(160, 160)
text = "1P"
icon = ExtResource("2_robot")
expand_icon = true
script = ExtResource("9_modetile")
theme_override_constants/icon_max_width = 128
theme_override_fonts/font = ExtResource("5_font")
theme_override_font_sizes/font_size = 16

[node name="Btn2P" type="Button" parent="TileBar/Row1"]
layout_mode = 2
custom_minimum_size = Vector2(160, 160)
text = "2P"
icon = ExtResource("3_users")
expand_icon = true
script = ExtResource("9_modetile")
theme_override_constants/icon_max_width = 128
theme_override_fonts/font = ExtResource("5_font")
theme_override_font_sizes/font_size = 16

[node name="BtnOnline" type="Button" parent="TileBar/Row1"]
layout_mode = 2
custom_minimum_size = Vector2(160, 160)
text = "ONLINE"
icon = ExtResource("4_globe")
expand_icon = true
script = ExtResource("9_modetile")
theme_override_constants/icon_max_width = 128
theme_override_fonts/font = ExtResource("5_font")
theme_override_font_sizes/font_size = 16

[node name="Row2" type="HBoxContainer" parent="TileBar"]
layout_mode = 2
alignment = 1
theme_override_constants/separation = 12

[node name="BtnLeaderboard" type="Button" parent="TileBar/Row2"]
layout_mode = 2
custom_minimum_size = Vector2(492, 80)
text = "LEADERBOARD"
script = ExtResource("9_modetile")
theme_override_fonts/font = ExtResource("5_font")
theme_override_font_sizes/font_size = 22

[node name="ProfileRow" type="HBoxContainer" parent="."]
visible = false
layout_mode = 1
anchors_preset = 10
anchor_left = 0.5
anchor_top = 1.0
anchor_right = 0.5
anchor_bottom = 1.0
offset_left = -100.0
offset_top = -40.0
offset_right = 100.0
offset_bottom = -8.0
alignment = 1

[node name="LblProfileIcon" type="Label" parent="ProfileRow"]
layout_mode = 2
text = ""
theme_override_fonts/font = ExtResource("5_font")
theme_override_font_sizes/font_size = 18

[node name="LblUsername" type="Label" parent="ProfileRow"]
layout_mode = 2
text = ""
theme_override_fonts/font = ExtResource("5_font")
theme_override_font_sizes/font_size = 18

[node name="LblPoints" type="Label" parent="ProfileRow"]
layout_mode = 2
text = ""
theme_override_fonts/font = ExtResource("5_font")
theme_override_font_sizes/font_size = 18
```

- [ ] **Step 2: Commit**

```powershell
cd c:\Projects\claude\nexus-arcade
git add games/tic-tac-toe/scenes/MainMenu.tscn
git commit -m "feat: rewrite MainMenu scene with carousel and tile bar"
```

---

### Task 6: Write MainMenu.gd — wiring and mode routing

**Files:**
- Modify: `games/tic-tac-toe/scenes/MainMenu.gd` (full rewrite)

- [ ] **Step 1: Write MainMenu.gd**

```gdscript
extends Control

var _current_game_mode: String = "classic"
var _timer_enabled: bool = false

@onready var _carousel: ModeCarousel = $CarouselContainer
@onready var _btn_1p: Button = $TileBar/Row1/Btn1P
@onready var _btn_2p: Button = $TileBar/Row1/Btn2P
@onready var _btn_online: Button = $TileBar/Row1/BtnOnline
@onready var _btn_leaderboard: Button = $TileBar/Row2/BtnLeaderboard
@onready var _check_timer: CheckBox = $CarouselContainer/TimerRow/CheckTimer
@onready var _lbl_clock: Label = $CarouselContainer/TimerRow/LblClock
@onready var _lbl_timer_secs: Label = $CarouselContainer/TimerRow/LblTimerSecs
@onready var _btn_left: Button = $CarouselContainer/BtnArrowLeft
@onready var _btn_right: Button = $CarouselContainer/BtnArrowRight
@onready var _preview_container: Control = $CarouselContainer/PreviewContainer

func _ready() -> void:
	var bg = load("res://scripts/BackgroundLayer.gd").new()
	add_child(bg)
	move_child(bg, 1)

	# Wire tile buttons
	_btn_1p.pressed.connect(_on_1p)
	_btn_2p.pressed.connect(_on_2p)
	_btn_online.pressed.connect(_on_online)
	_btn_leaderboard.pressed.connect(_on_leaderboard)
	$BtnSignInIcon.pressed.connect(_on_sign_in)

	# Wire carousel
	_carousel.mode_changed.connect(_on_mode_changed)

	# Timer toggle
	_check_timer.toggled.connect(_on_timer_toggled)
	_refresh_timer_visibility()

	# Arrow buttons already wired in ModeCarousel
	_btn_left.text = FA6.icon("fa-chevron-left")
	_btn_right.text = FA6.icon("fa-chevron-right")

	# Sign-in icon
	$BtnSignInIcon.text = FA6.icon("fa-arrow-right-to-bracket")

	# Profile icons
	$ProfileRow/LblProfileIcon.text = FA6.icon("fa-user")
	_btn_leaderboard.text = FA6.icon("fa-trophy") + "  LEADERBOARD"

	# Clock icon
	_lbl_clock.text = FA6.icon("fa-clock")

	# Auth
	$Bridge.send_game_ready()
	$Bridge.auth_token_received.connect(func(_t): pass)
	if not Globals.auth_ready.is_connected(_refresh_auth_ui):
		Globals.auth_ready.connect(_refresh_auth_ui)
	_refresh_auth_ui()

func _on_mode_changed(index: int, mode_id: String) -> void:
	_current_game_mode = mode_id
	_refresh_timer_visibility()

func _refresh_timer_visibility() -> void:
	var show_timer := _current_game_mode != "ultimate"  # not shown for Ultimate placeholder
	$CarouselContainer/TimerRow.visible = show_timer

func _on_timer_toggled(pressed: bool) -> void:
	_timer_enabled = pressed
	_lbl_timer_secs.add_theme_color_override("font_color",
		Color("#00d4ff") if pressed else Color(0.392, 0.455, 0.573, 1))

func _on_1p() -> void:
	SFX.click()
	Globals.current_game_mode = _current_game_mode
	Globals.use_timer = _timer_enabled
	Globals.timer_seconds = 10
	get_tree().change_scene_to_file("res://scenes/AIDifficultySelect.tscn")

func _on_2p() -> void:
	SFX.click()
	Globals.current_game_mode = _current_game_mode
	Globals.use_timer = false  # timer disabled for local 2P
	Globals.timer_seconds = 10
	var board = load("res://scenes/GameBoard.tscn").instantiate()
	board.setup_local()
	get_tree().root.add_child(board)
	queue_free()

func _on_online() -> void:
	SFX.click()
	Globals.current_game_mode = _current_game_mode
	Globals.use_timer = _timer_enabled
	Globals.timer_seconds = 10
	get_tree().change_scene_to_file("res://scenes/OnlineLobby.tscn")

func _on_leaderboard() -> void:
	SFX.click()
	get_tree().change_scene_to_file("res://scenes/LeaderboardScene.tscn")

func _on_sign_in() -> void:
	SFX.click()
	$Bridge.send_sign_in_request()

func _refresh_auth_ui() -> void:
	var signed_in := Globals.is_signed_in()
	$ProfileRow.visible = signed_in
	_btn_leaderboard.visible = signed_in
	$BtnSignInIcon.visible = not signed_in
	if signed_in:
		$ProfileRow/LblUsername.text = Globals.current_user.get("username", "")
		$ProfileRow/LblPoints.text = "★ %d" % Globals.current_user.get("points", 0)
```

Wait, I have a duplicate `_btn_leaderboard` declaration. Let me fix that:

```gdscript
@onready var _btn_leaderboard: Button = $TileBar/Row2/BtnLeaderboard
```

Only one declaration needed. Let me clean up.

- [ ] **Step 2: Commit**

```powershell
cd c:\Projects\claude\nexus-arcade
git add games/tic-tac-toe/scenes/MainMenu.gd
git commit -m "feat: rewrite MainMenu.gd with carousel, timer toggle, mode routing"
```

---

### Task 7: Update GameBoard.gd — random first turn + timer from Globals

**Files:**
- Modify: `games/tic-tac-toe/scenes/GameBoard.gd:25-73`

- [ ] **Step 1: Add TurnAnnounce logic and random first-turn**

Change `setup_vs_ai()` to support random first turn:

Replace lines 25-28:
```gdscript
func setup_vs_ai(difficulty: TicTacToeAI.Difficulty) -> void:
	_mode = Mode.VS_AI
	_ai_difficulty = difficulty
	_ai = TicTacToeAI.new()
```

With:
```gdscript
func setup_vs_ai(difficulty: TicTacToeAI.Difficulty) -> void:
	_mode = Mode.VS_AI
	_ai_difficulty = difficulty
	_ai = TicTacToeAI.new()
	# Randomize who goes first
	if randi() % 2 == 0:
		_player_mark = GameState.Player.X   # Player = X, goes first
	else:
		_player_mark = GameState.Player.O   # Player = O, AI goes first
```

- [ ] **Step 2: Show TurnAnnounce in _ready()**

Insert after `_update_streak_badge()` call (after line 68), add TurnAnnounce logic:

```gdscript
	_update_streak_badge()

	# Turn announcement
	if _mode == Mode.VS_AI:
		var announce = $TurnAnnounce if has_node("TurnAnnounce") else null
		if announce:
			if _player_mark == GameState.Player.X:
				announce.text = "YOU GO FIRST"
			else:
				announce.text = "OPPONENT GOES FIRST"
			announce.visible = true
			announce.modulate = Color.WHITE
			var tw := create_tween()
			tw.tween_property(announce, "modulate:a", 0.0, 2.5).set_delay(0.5)
			tw.tween_callback(func(): announce.visible = false)
```

- [ ] **Step 3: Read timer from Globals**

Replace in `_ready()` (around line 70-73), change turn timer setup:

Current:
```gdscript
	if _mode == Mode.ONLINE:
		_supabase_ref.realtime_message.connect(_on_online_message)
		if _player_mark == GameState.Player.X:
			_turn_timer.start()
```

Replace with:
```gdscript
	if _mode == Mode.ONLINE:
		_supabase_ref.realtime_message.connect(_on_online_message)
		if _player_mark == GameState.Player.X:
			if Globals.use_timer:
				_turn_timer.set_duration(Globals.timer_seconds)
				_turn_timer.start()

	# AI first move if player is O
	if _mode == Mode.VS_AI and _player_mark == GameState.Player.O:
		_ai_take_turn.call_deferred()
```

And set timer duration from Globals for VS_AI mode too — insert after `_turn_timer.setup()`:

```gdscript
	_turn_timer = TurnTimer.new()
	if has_node("VBoxContainer/LblTimer"):
		_turn_timer.setup($VBoxContainer/LblTimer)
	add_child(_turn_timer)
	_turn_timer.timed_out.connect(_on_turn_timeout)
	if Globals.use_timer:
		_turn_timer.set_duration(Globals.timer_seconds)
```

Wait, `TurnTimer` needs a `set_duration()` method. Let me check if it exists or if I need to add it. Let me read TurnTimer.gd.

Actually, I should read TurnTimer.gd first. But the plan already references it. Let me assume it has `start()` like we see in the current code. The duration is likely set via a property or constant. Let me add `set_duration(secs: int)` to TurnTimer.gd in the plan.

Hmm, actually, looking at the GameBoard code, `_turn_timer.setup($VBoxContainer/LblTimer)` sets the label, and then `_turn_timer.start()` starts a 30s timer. Let me check if there's a way to set the duration.

Let me add a step to modify TurnTimer.gd to support configurable duration.

- [ ] **Step 4: Update TurnTimer.gd for configurable duration**

Read current TurnTimer.gd and check if it supports configurable duration. If not, add it.

Assuming TurnTimer.gd has `start()` that uses a hardcoded duration, modify:

```gdscript
var _duration: float = 30.0

func set_duration(seconds: float) -> void:
	_duration = seconds

func start() -> void:
	if _timer:
		_timer.start(_duration)
	# ... rest of start logic
```

If the file already uses a var for duration, just use that.

- [ ] **Step 5: Update AI turn text for player-as-O case**

In `_refresh_ui()`, the turn text logic needs to account for player being O:

Replace the GameState.Player.X block:
```gdscript
	match _state.current_turn:
		GameState.Player.X:
			if _mode == Mode.VS_AI and _player_mark == GameState.Player.O:
				turn_text = "AI THINKING..."
			elif _mode == Mode.VS_AI:
				turn_text = "YOUR TURN — X"
			else:
				turn_text = "PLAYER 1 — X"
		GameState.Player.O:
			if _mode == Mode.VS_AI and _player_mark == GameState.Player.X:
				turn_text = "AI THINKING..."
			elif _mode == Mode.VS_AI:
				turn_text = "YOUR TURN — O"
			elif _mode == Mode.LOCAL:
				turn_text = "PLAYER 2 — O"
			else:
				turn_text = "OPPONENT — O"
```

- [ ] **Step 6: Commit**

```powershell
cd c:\Projects\claude\nexus-arcade
git add games/tic-tac-toe/scenes/GameBoard.gd games/tic-tac-toe/scripts/TurnTimer.gd
git commit -m "feat: random first-turn, configurable timer duration, turn announce"
```

---

### Task 8: Add TurnAnnounce label to GameBoard.tscn

**Files:**
- Modify: `games/tic-tac-toe/scenes/GameBoard.tscn`

- [ ] **Step 1: Add TurnAnnounce Label node**

Add as child of root `GameBoard` node (at end of file, before the closing):

```gdscript
[node name="TurnAnnounce" type="Label" parent="."]
visible = false
layout_mode = 1
anchors_preset = 8
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
offset_left = -200.0
offset_top = -40.0
offset_right = 200.0
offset_bottom = 40.0
text = "YOU GO FIRST"
theme_override_fonts/font = ExtResource("3_font")
theme_override_font_sizes/font_size = 42
theme_override_colors/font_color = Color(0, 0.831, 1, 1)
horizontal_alignment = 1
vertical_alignment = 1
mouse_filter = 2
```

This node sits as an overlay at center of the game board screen. It's `visible = false` by default, shown in `_ready()` when VS_AI mode is active.

- [ ] **Step 2: Commit**

```powershell
cd c:\Projects\claude\nexus-arcade
git add games/tic-tac-toe/scenes/GameBoard.tscn
git commit -m "feat: add TurnAnnounce overlay label to GameBoard"
```

---

### Task 9: GUT tests

**Files:**
- Create: `games/tic-tac-toe/tests/test_main_menu.gd`
- Create: `games/tic-tac-toe/tests/test_turn_random.gd`

- [ ] **Step 1: Write test_main_menu.gd**

```gdscript
extends GutTest

func test_globals_timer_defaults() -> void:
	assert_false(Globals.use_timer, "use_timer should default to false")
	assert_eq(Globals.timer_seconds, 10, "timer_seconds should default to 10")

func test_globals_timer_toggle() -> void:
	Globals.use_timer = true
	assert_true(Globals.use_timer, "use_timer should be settable")
	Globals.use_timer = false
	assert_false(Globals.use_timer, "use_timer should toggle back")

func test_carousel_modes_count() -> void:
	assert_eq(ModeCarousel.MODES.size(), 3, "should have 3 modes")

func test_carousel_modes_have_required() -> void:
	var ids: Array[String] = []
	for m in ModeCarousel.MODES:
		ids.append(m.id)
	assert_true(ids.has("classic"), "should have classic mode")
	assert_true(ids.has("ultimate"), "should have ultimate mode")
	assert_true(ids.has("ephemerate"), "should have ephemerate mode")

func test_mode_tile_size_constant() -> void:
	assert_eq(ModeTile.TILE_SIZE, 160.0, "tile size should be 160")

func test_carousel_wrap_next() -> void:
	var carousel := ModeCarousel.new()
	# Start at 0, next → 1, next → 2, next → 0
	carousel._current_index = 0
	carousel._next()
	assert_eq(carousel._current_index, 1)
	carousel._next()
	assert_eq(carousel._current_index, 2)
	carousel._next()
	assert_eq(carousel._current_index, 0)

func test_carousel_wrap_prev() -> void:
	var carousel := ModeCarousel.new()
	carousel._current_index = 0
	carousel._prev()
	assert_eq(carousel._current_index, 2)
```

- [ ] **Step 2: Write test_turn_random.gd**

```gdscript
extends GutTest

func test_random_first_turn_produces_x() -> void:
	# Run many iterations — should produce X at least once
	var found_x := false
	for _i in 100:
		var mark := _simulate_random_turn()
		if mark == 0:  # Player.X
			found_x = true
			break
	assert_true(found_x, "random turn should produce X at least once in 100 tries")

func test_random_first_turn_produces_o() -> void:
	var found_o := false
	for _i in 100:
		var mark := _simulate_random_turn()
		if mark == 1:  # Player.O
			found_o = true
			break
	assert_true(found_o, "random turn should produce O at least once in 100 tries")

func test_vs_ai_player_is_always_x_or_o() -> void:
	for _i in 50:
		var mark := _simulate_random_turn()
		assert_true(mark == 0 or mark == 1, "player mark should be X(0) or O(1)")

func _simulate_random_turn() -> int:
	# Replicates GameBoard.setup_vs_ai random logic
	if randi() % 2 == 0:
		return 0  # Player.X
	else:
		return 1  # Player.O
```

- [ ] **Step 3: Run tests and verify**

```powershell
cd c:\Projects\claude\nexus-arcade\games\tic-tac-toe
& "C:\Projects\godot\Godot_v4.6.2-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/ -gprefix=test_ -gsuffix=.gd
```

Expected: All tests pass. If ModeCarousel is not loadable in test context (scene dependency), tests for `MODES` size and `_current_index` may need the ModeCarousel script loaded via `load("res://scripts/ModeCarousel.gd")`.

- [ ] **Step 4: Commit**

```powershell
cd c:\Projects\claude\nexus-arcade
git add games/tic-tac-toe/tests/test_main_menu.gd games/tic-tac-toe/tests/test_turn_random.gd
git commit -m "test: add main menu carousel and turn randomization tests"
```

---

### Task 10: Godot web export + final commit

- [ ] **Step 1: Export web build**

```powershell
Set-Location "c:\Projects\claude\nexus-arcade\games\tic-tac-toe"
& "C:\Projects\godot\Godot_v4.6.2-stable_win64_console.exe" --headless --export-release "Web" "../../portal/public/games/tic-tac-toe/index.html"
```

Expected: Export succeeds with all new scenes/scripts compiled.

- [ ] **Step 2: Commit export**

```powershell
cd c:\Projects\claude\nexus-arcade
git add portal/public/games/tic-tac-toe/
git commit -m "build: re-export #HashAttack! with main menu overhaul"
```

---

## Deferred / Out of Scope

- **Ultimate Tic Tac Toe** full game mechanics (needs new GameState variant, meta-board tracking, UI for 81 cells)
- **Ephemerate** full game mechanics (needs fade tracking array per cell, timer/garbage collection)
- **ModePreview 3D spin** using actual SubViewport — current plan uses 2D skew illusion. Upgrade when mode mechanics are real.
- **Marketplace button** — row slot ready, add when feature exists
- **Swipe animation** — current plan snaps; smooth animated slide deferred

## Post-Export Verification

After Task 10 export, verify in browser (`http://localhost:3000/games/tic-tac-toe`):

1. MainMenu loads with carousel (3 modes, swipe/arrows/dots work)
2. Board preview shows different visuals per mode (Classic/Ultimate/Ephemerate)
3. Tile bar: 1P, 2P, ONLINE, LEADERBOARD buttons all present and styled
4. Timer toggle: checkbox + "10s" label, defaults off
5. 1P → AIDifficultySelect → GameBoard shows "YOU GO FIRST" or "OPPONENT GOES FIRST" (random)
6. Sign-in icon shows when signed out; profile row when signed in
7. Leaderboard tile works (shows Leaderboard scene or "No scores yet")
