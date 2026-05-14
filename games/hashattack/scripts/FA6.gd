extends Node

const _CHEATSHEET = preload("res://addons/font-awesome-6/cheatsheet.gd")
const _FONT_SOLID: FontFile = preload("res://addons/font-awesome-6/fa-solid-900.ttf")
const _FONT_REGULAR: FontFile = preload("res://addons/font-awesome-6/fa-regular-400.ttf")
const _FONT_BRANDS: FontFile = preload("res://addons/font-awesome-6/fa-brands-400.ttf")

func icon(name: String, type: String = "solid") -> String:
	var lut: Dictionary = _CHEATSHEET.cheatsheet_lut
	if type in lut and name in lut[type]:
		return lut[type][name]
	push_warning("FA6: icon '%s' not found in '%s'" % [name, type])
	return "?"

func font(type: String = "solid") -> FontFile:
	match type:
		"regular": return _FONT_REGULAR
		"brands": return _FONT_BRANDS
		_: return _FONT_SOLID

func make_label(icon_name: String, size: int = 32, color: Color = Color.WHITE, type: String = "solid") -> Label:
	var lbl := Label.new()
	lbl.text = icon(icon_name, type)
	lbl.add_theme_font_override("font", font(type))
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", color)
	return lbl
