extends Node

const GAME_SLUG := "hashattack"

signal auth_ready

enum AIDifficulty { EASY, HARD, UNBEATABLE }

var supabase: SupabaseClient

var current_user: Dictionary = {}
var current_game_id: String = ""
var current_game_mode: String = "classic"
var current_streak: Dictionary = {}

var ai_difficulty: AIDifficulty = AIDifficulty.EASY
var timer_seconds: int = 0   # 0 = off, 3/6/9 for blitz/casual/chill

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
