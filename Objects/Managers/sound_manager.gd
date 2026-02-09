extends Node

# Dictionary of preloaded sounds
var _sounds: Dictionary = {
	"death": preload("res://Assets/Sound/SFX/death.ogg"),
	"dig": preload("res://Assets/Sound/SFX/dig.wav"),
	"drop": preload("res://Assets/Sound/SFX/drop.wav"),
	"fall_big": preload("res://Assets/Sound/SFX/fall_big.ogg"),
	"fall_small": preload("res://Assets/Sound/SFX/fall_small.ogg"),
	"refuel": preload("res://Assets/Sound/SFX/refuel.ogg"),
	"respawn": preload("res://Assets/Sound/SFX/spawned.ogg"),

	"music": preload("res://Assets/Sound/Music/mining_song.mp3"),
	
	# NEW SOUNDS
	"sold": preload("res://Assets/Sound/SFX/sold.mp3"),
	"embark": preload("res://Assets/Sound/SFX/embark.wav"),
	"switch": preload("res://Assets/Sound/SFX/ui_switch.wav"),
	"select": preload("res://Assets/Sound/SFX/ui_select.ogg"),
	"thrust": preload("res://Assets/Sound/SFX/thrust.wav"),
    "close": preload("res://Assets/Sound/SFX/close.ogg"),
	"rebuild": preload("res://Assets/Sound/SFX/rebuild.mp3"),
}

# Cache for looping players to control them (stop/start)
var _looped_players: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func play_sfx(sound_name: String, pitch_min: float = 1.0, pitch_max: float = 1.0, volume_db: float = 0.0) -> void:
	if not _sounds.has(sound_name): return

	var player = AudioStreamPlayer.new()
	player.stream = _sounds[sound_name]
	player.volume_db = volume_db
	
	if pitch_min != pitch_max:
		player.pitch_scale = randf_range(pitch_min, pitch_max)
	else:
		player.pitch_scale = pitch_min
		
	player.finished.connect(player.queue_free)
	add_child(player)
	player.play()

func play_loop(sound_name: String, speed: float = 1.0, volume_db: float = 0.0) -> void:
	if not _sounds.has(sound_name): return

	var player: AudioStreamPlayer

	if _looped_players.has(sound_name):
		player = _looped_players[sound_name]
	else:
		player = AudioStreamPlayer.new()
		player.stream = _sounds[sound_name]
		add_child(player)
		_looped_players[sound_name] = player
	
	# SAFE LOOPING: Ensure we are connected, but don't connect twice
	if not player.finished.is_connected(player.play):
		player.finished.connect(player.play)

	player.volume_db = volume_db
	player.pitch_scale = speed

	if not player.playing:
		player.play()

func stop_loop(sound_name: String) -> void:
	if _looped_players.has(sound_name):
		var player = _looped_players[sound_name]
		
		# CRITICAL FIX: Disconnect the loop signal so stopping actually works
		if player.finished.is_connected(player.play):
			player.finished.disconnect(player.play)
			
		player.stop()