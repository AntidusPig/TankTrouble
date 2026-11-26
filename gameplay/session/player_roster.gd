class_name PlayerRoster extends RefCounted

const OFF := -2
const HUMAN := -1
const PRACTICE := 0
const SUDOKU_AI := 6
const MAX_PLAYERS := 8
const MAX_HUMANS := 3
const LABELS := ["PRACTICE", "STATE", "TREE", "GOAP", "UTILITY", "NEURAL", "SUDOKU_AI"]
const COLORS := [
	Color("#db644f"), Color("#5c9ec5"), Color("#e9ad47"), Color("#62a780"),
	Color("#ad79b3"), Color("#db884b"), Color("#5dbeb9"), Color("#dc81a1")
]


static func label_for(role: int) -> String:
	if role == HUMAN:
		return TranslationServer.translate("HUMAN")
	if role == OFF:
		return TranslationServer.translate("OFF")
	return TranslationServer.translate(LABELS[role])


static func is_valid(roster: PackedInt32Array) -> bool:
	if roster.size() < 2 or roster.size() > MAX_PLAYERS:
		return false
	var active := 0
	var humans := 0
	for role in roster:
		if role < OFF or role >= LABELS.size():
			return false
		active += int(role != OFF)
		humans += int(role == HUMAN)
	return active >= 2 and humans <= MAX_HUMANS


static func needs_dotnet(roster: PackedInt32Array) -> bool:
	for role in roster:
		if role > PRACTICE:
			return true
	return false


static func from_legacy(players: int, ai: int) -> PackedInt32Array:
	return PackedInt32Array([HUMAN, HUMAN if players == 2 else ai])
