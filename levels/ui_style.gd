class_name UiStyle
extends RefCounted
## The look shared by the title screen and the level HUD: dark sea-blue
## panels with rounded corners, sand and teal for what matters, white text
## with a soft outline so it reads over the beach.

const PANEL := Color(0.05, 0.13, 0.19, 0.86)
const PANEL_LIGHT := Color(0.1, 0.22, 0.3, 0.9)
const SAND := Color(0.97, 0.82, 0.52)
const TEAL := Color(0.38, 0.88, 0.76)
const CORAL := Color(1.0, 0.52, 0.42)
const TEXT := Color(0.95, 0.97, 0.98)
const MUTED := Color(0.66, 0.76, 0.8)


static func panel_style(color := PANEL, radius := 14, padding := 18) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(radius)
	box.set_content_margin_all(padding)
	return box


static func panel(color := PANEL, radius := 14, padding := 18) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", panel_style(color, radius, padding))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


static func label(text: String, size := 18, color := TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.5))
	l.add_theme_constant_override("outline_size", 3)
	return l


## A label that wraps to `width` (px).
static func paragraph(text: String, width: float, size := 17, color := MUTED) -> Label:
	var l := label(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = width
	return l


static func button(text: String, main := true) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(160, 44)
	b.add_theme_font_size_override("font_size", 18)
	var fill := TEAL if main else PANEL_LIGHT
	var ink := Color(0.04, 0.12, 0.16) if main else TEXT
	for state in ["normal", "hover", "pressed", "disabled"]:
		var box := panel_style(fill, 10, 10)
		match state:
			"hover":
				box.bg_color = fill.lightened(0.15)
			"pressed":
				box.bg_color = fill.darkened(0.15)
			"disabled":
				box.bg_color = Color(0.3, 0.35, 0.38, 0.7)
		b.add_theme_stylebox_override(state, box)
	for state in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(state, ink)
	b.add_theme_color_override("font_disabled_color", MUTED)
	return b


## A bar showing `value` (0 to 1), for the ocean's health.
static func health_bar(width := 260.0) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.step = 0.001
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(width, 14)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var back := panel_style(Color(0, 0, 0, 0.35), 7, 0)
	var fill := panel_style(TEAL, 7, 0)
	bar.add_theme_stylebox_override("background", back)
	bar.add_theme_stylebox_override("fill", fill)
	return bar


## Fills the screen with a dim backdrop and centres `content` on it.
static func overlay(content: Control, dim := 0.45) -> Control:
	var root := ColorRect.new()
	root.color = Color(0.01, 0.04, 0.07, dim)
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)
	center.add_child(content)
	return root
