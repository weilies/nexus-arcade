class_name GameState
extends RefCounted

enum Player { NONE, X, O }
enum GameResult { ONGOING, X_WINS, O_WINS, DRAW }

const WIN_LINES: Array = [
	[0, 1, 2], [3, 4, 5], [6, 7, 8],
	[0, 3, 6], [1, 4, 7], [2, 5, 8],
	[0, 4, 8], [2, 4, 6]
]

var board: Array = []
var current_turn: Player = Player.X
var result: GameResult = GameResult.ONGOING

func _init() -> void:
	board.resize(9)
	board.fill(Player.NONE)

func place(cell: int) -> bool:
	if cell < 0 or cell > 8:
		return false
	if board[cell] != Player.NONE:
		return false
	if result != GameResult.ONGOING:
		return false
	board[cell] = current_turn
	result = _check_result()
	if result == GameResult.ONGOING:
		current_turn = Player.O if current_turn == Player.X else Player.X
	return true

func get_empty_cells() -> Array:
	var empty: Array = []
	for i in 9:
		if board[i] == Player.NONE:
			empty.append(i)
	return empty

func get_winning_line() -> Array:
	for line in WIN_LINES:
		var p = board[line[0]]
		if p != Player.NONE and board[line[1]] == p and board[line[2]] == p:
			return line
	return []

func to_dict() -> Dictionary:
	return {
		"board": board.map(func(p): return GameState.player_to_str(p)),
		"turn": GameState.player_to_str(current_turn),
		"winner": _result_to_str(result)
	}

func from_dict(d: Dictionary) -> bool:
	if not d.has("board") or not d["board"] is Array or d["board"].size() != 9:
		return false
	if not d.has("turn"):
		return false
	for i in 9:
		board[i] = _str_to_player(d["board"][i])
	current_turn = _str_to_player(d["turn"])
	result = _check_result()
	return true

static func player_to_str(p: Player) -> String:
	match p:
		Player.X: return "X"
		Player.O: return "O"
		_: return ""

func is_over() -> bool:
	return result != GameResult.ONGOING

func _check_result() -> GameResult:
	for line in WIN_LINES:
		var p = board[line[0]]
		if p != Player.NONE and board[line[1]] == p and board[line[2]] == p:
			return GameResult.X_WINS if p == Player.X else GameResult.O_WINS
	if get_empty_cells().is_empty():
		return GameResult.DRAW
	return GameResult.ONGOING

func _str_to_player(s: String) -> Player:
	match s:
		"X": return Player.X
		"O": return Player.O
		_: return Player.NONE

func _result_to_str(r: GameResult) -> String:
	match r:
		GameResult.X_WINS: return "X"
		GameResult.O_WINS: return "O"
		GameResult.DRAW: return "draw"
		_: return ""
