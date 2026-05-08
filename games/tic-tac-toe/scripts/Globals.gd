extends Node

const GAME_SLUG := "tic-tac-toe"

signal auth_ready

var supabase: SupabaseClient

var current_user: Dictionary = {}
# When signed in: { id: String, username: String, points: int }
# Empty when signed out.

var current_game_id: String = ""
var current_game_mode: String = "classic"
var current_streak: Dictionary = {}
# Keys = game_mode strings, values = int current streak count.
var use_timer: bool = false
var timer_seconds: int = 10

var jwt: String = "":
	set(value):
		jwt = value
		supabase.set_jwt(value)

func _ready() -> void:
	supabase = SupabaseClient.new()
	supabase.init(
		ProjectSettings.get_setting("supabase/url"),
		ProjectSettings.get_setting("supabase/anon_key")
	)
	add_child(supabase)

func is_signed_in() -> bool:
	return not current_user.is_empty()
