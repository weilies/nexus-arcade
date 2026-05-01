extends Node

var supabase: SupabaseClient

func _ready() -> void:
	supabase = SupabaseClient.new()
	supabase.init(
		ProjectSettings.get_setting("supabase/url"),
		ProjectSettings.get_setting("supabase/anon_key")
	)
	add_child(supabase)

var jwt: String = "":
	set(value):
		jwt = value
		supabase.set_jwt(value)
