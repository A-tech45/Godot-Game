extends Node

# Procedural Sound Manager generating arcade/retro sound effects on the fly

var audio_players: Array[AudioStreamPlayer] = []
var max_players: int = 12

# Cached sound streams
var sfx_rifle: AudioStreamWAV
var sfx_shotgun: AudioStreamWAV
var sfx_railgun: AudioStreamWAV
var sfx_plasma: AudioStreamWAV
var sfx_hit: AudioStreamWAV
var sfx_kill: AudioStreamWAV
var sfx_crack: AudioStreamWAV
var sfx_collapse: AudioStreamWAV
var sfx_dash: AudioStreamWAV
var sfx_victory: AudioStreamWAV
var sfx_defeat: AudioStreamWAV

func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	# Initialize audio player pool
	for i in range(max_players):
		var player := AudioStreamPlayer.new()
		player.bus = "Master"
		add_child(player)
		audio_players.append(player)
	
	_generate_all_sounds()

func _generate_all_sounds() -> void:
	sfx_rifle = _create_noise_burst(0.08, 0.9, 0.4)
	sfx_shotgun = _create_noise_burst(0.18, 0.7, 0.9)
	sfx_railgun = _create_laser_zap(0.22, 1200.0, 150.0)
	sfx_plasma = _create_laser_zap(0.15, 400.0, 800.0)
	sfx_hit = _create_click(0.04, 800.0)
	sfx_kill = _create_laser_zap(0.25, 600.0, 100.0)
	sfx_crack = _create_noise_burst(0.15, 0.5, 0.3)
	sfx_collapse = _create_noise_burst(0.35, 0.3, 0.8)
	sfx_dash = _create_swoosh(0.12)
	sfx_victory = _create_jingle(true)
	sfx_defeat = _create_jingle(false)

func play_sfx(stream: AudioStreamWAV, volume_db: float = 0.0, pitch_range: float = 0.05) -> void:
	if stream == null:
		return
		
	# Find available player
	for player in audio_players:
		if not player.playing:
			player.stream = stream
			player.volume_db = volume_db
			player.pitch_scale = randf_range(1.0 - pitch_range, 1.0 + pitch_range)
			player.play()
			return
			
	# If all busy, reuse first player
	var player = audio_players[0]
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = randf_range(1.0 - pitch_range, 1.0 + pitch_range)
	player.play()

# Convenience triggers
func play_shoot(weapon_type: int) -> void:
	match weapon_type:
		0: play_sfx(sfx_rifle, -2.0, 0.08)
		1: play_sfx(sfx_shotgun, 1.0, 0.06)
		2: play_sfx(sfx_railgun, 0.0, 0.02)
		3: play_sfx(sfx_plasma, 0.0, 0.05)

func play_hit() -> void:
	play_sfx(sfx_hit, -3.0, 0.1)

func play_kill() -> void:
	play_sfx(sfx_kill, 2.0, 0.05)

func play_tile_crack() -> void:
	play_sfx(sfx_crack, -4.0, 0.12)

func play_tile_collapse() -> void:
	play_sfx(sfx_collapse, 0.0, 0.08)

func play_dash() -> void:
	play_sfx(sfx_dash, -2.0, 0.1)

func play_victory() -> void:
	play_sfx(sfx_victory, 3.0, 0.0)

func play_defeat() -> void:
	play_sfx(sfx_defeat, 2.0, 0.0)

# Helper PCM Synthesizers producing 22050Hz 8-bit Unsigned WAV streams
func _create_noise_burst(duration: float, decay_rate: float, bass_mix: float) -> AudioStreamWAV:
	var sample_rate: int = 22050
	var num_samples: int = int(sample_rate * duration)
	var buffer := PackedByteArray()
	buffer.resize(num_samples)
	
	var env: float = 1.0
	for i in range(num_samples):
		var t: float = float(i) / float(num_samples)
		env = pow(1.0 - t, decay_rate * 3.0)
		var noise: float = randf_range(-1.0, 1.0)
		var bass: float = sin(t * 100.0 * PI)
		var val: float = lerp(noise, bass, bass_mix) * env
		buffer[i] = clamp(int((val * 0.4 + 0.5) * 255.0), 0, 255)
		
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_8_BITS
	wav.mix_rate = sample_rate
	wav.data = buffer
	return wav

func _create_laser_zap(duration: float, start_freq: float, end_freq: float) -> AudioStreamWAV:
	var sample_rate: int = 22050
	var num_samples: int = int(sample_rate * duration)
	var buffer := PackedByteArray()
	buffer.resize(num_samples)
	
	var phase: float = 0.0
	for i in range(num_samples):
		var t: float = float(i) / float(num_samples)
		var freq: float = lerp(start_freq, end_freq, pow(t, 0.5))
		phase += (freq / float(sample_rate)) * 2.0 * PI
		var env: float = 1.0 - t
		var val: float = sin(phase) * env
		buffer[i] = clamp(int((val * 0.4 + 0.5) * 255.0), 0, 255)
		
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_8_BITS
	wav.mix_rate = sample_rate
	wav.data = buffer
	return wav

func _create_click(duration: float, freq: float) -> AudioStreamWAV:
	var sample_rate: int = 22050
	var num_samples: int = int(sample_rate * duration)
	var buffer := PackedByteArray()
	buffer.resize(num_samples)
	
	var phase: float = 0.0
	for i in range(num_samples):
		var t: float = float(i) / float(num_samples)
		phase += (freq / float(sample_rate)) * 2.0 * PI
		var env: float = pow(1.0 - t, 4.0)
		var val: float = sin(phase) * env
		buffer[i] = clamp(int((val * 0.4 + 0.5) * 255.0), 0, 255)
		
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_8_BITS
	wav.mix_rate = sample_rate
	wav.data = buffer
	return wav

func _create_swoosh(duration: float) -> AudioStreamWAV:
	var sample_rate: int = 22050
	var num_samples: int = int(sample_rate * duration)
	var buffer := PackedByteArray()
	buffer.resize(num_samples)
	
	for i in range(num_samples):
		var t: float = float(i) / float(num_samples)
		var env: float = sin(t * PI) # Bell curve envelope
		var noise: float = randf_range(-1.0, 1.0)
		var val: float = noise * env
		buffer[i] = clamp(int((val * 0.35 + 0.5) * 255.0), 0, 255)
		
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_8_BITS
	wav.mix_rate = sample_rate
	wav.data = buffer
	return wav

func _create_jingle(is_victory: bool) -> AudioStreamWAV:
	var sample_rate: int = 22050
	var duration: float = 0.6
	var num_samples: int = int(sample_rate * duration)
	var buffer := PackedByteArray()
	buffer.resize(num_samples)
	
	var freqs: Array[float] = []
	if is_victory:
		freqs.append(440.0)
		freqs.append(554.37)
		freqs.append(659.25)
		freqs.append(880.0)
	else:
		freqs.append(440.0)
		freqs.append(370.0)
		freqs.append(311.0)
		freqs.append(220.0)
	
	var phase: float = 0.0
	for i in range(num_samples):
		var t: float = float(i) / float(num_samples)
		var note_idx: int = min(int(t * 4.0), 3)
		var freq: float = freqs[note_idx]
		phase += (freq / float(sample_rate)) * 2.0 * PI
		var env: float = 1.0 - fmod(t * 4.0, 1.0) * 0.5
		var val: float = (sin(phase) + (0.5 if sin(phase) > 0 else -0.5)) * 0.5 * env
		buffer[i] = clamp(int((val * 0.35 + 0.5) * 255.0), 0, 255)
		
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_8_BITS
	wav.mix_rate = sample_rate
	wav.data = buffer
	return wav
