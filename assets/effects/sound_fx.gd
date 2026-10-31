class_name TCGSoundFX
extends Node

const SAMPLE_RATE := 22050

func play_cue(kind: String) -> void:
	if DisplayServer.get_name() == "headless": return
	var recipe := _recipe(kind)
	if recipe.is_empty(): return
	var player := AudioStreamPlayer.new()
	player.stream = _make_tone(float(recipe.frequency), float(recipe.duration), str(recipe.wave), float(recipe.slide), float(recipe.noise))
	player.volume_db = float(recipe.get("volume", -11.0))
	add_child(player)
	player.play()
	get_tree().create_timer(float(recipe.duration) + 0.18).timeout.connect(player.queue_free)

func _recipe(kind: String) -> Dictionary:
	match kind:
		"turn_start": return {"frequency": 520.0, "duration": 0.22, "wave": "sine", "slide": 280.0, "noise": 0.0, "volume": -13.0}
		"chain": return {"frequency": 420.0, "duration": 0.2, "wave": "triangle", "slide": 520.0, "noise": 0.0, "volume": -10.0}
		"unit_arrival", "summon", "arrival": return {"frequency": 260.0, "duration": 0.28, "wave": "triangle", "slide": 360.0, "noise": 0.03, "volume": -11.0}
		"attack": return {"frequency": 175.0, "duration": 0.14, "wave": "square", "slide": -80.0, "noise": 0.08, "volume": -12.0}
		"damage": return {"frequency": 120.0, "duration": 0.16, "wave": "square", "slide": -55.0, "noise": 0.24, "volume": -9.0}
		"heal": return {"frequency": 460.0, "duration": 0.3, "wave": "sine", "slide": 260.0, "noise": 0.0, "volume": -13.0}
		"shield": return {"frequency": 330.0, "duration": 0.2, "wave": "triangle", "slide": 90.0, "noise": 0.02, "volume": -12.0}
		"mana": return {"frequency": 610.0, "duration": 0.16, "wave": "sine", "slide": 130.0, "noise": 0.0, "volume": -15.0}
		"roulette": return {"frequency": 280.0, "duration": 0.34, "wave": "triangle", "slide": 460.0, "noise": 0.05, "volume": -12.0}
		"field_destroy", "slot_break": return {"frequency": 90.0, "duration": 0.42, "wave": "square", "slide": -40.0, "noise": 0.35, "volume": -8.0}
	return {}

func _make_tone(frequency: float, duration: float, wave: String, slide: float, noise_amount: float) -> AudioStreamWAV:
	var frame_count := maxi(1, int(duration * SAMPLE_RATE))
	var bytes := PackedByteArray()
	bytes.resize(frame_count * 2)
	var phase := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = int(frequency * 1000.0) + frame_count
	for frame in range(frame_count):
		var progress := float(frame) / float(frame_count)
		var current_frequency := maxf(35.0, frequency + slide * progress)
		phase += TAU * current_frequency / float(SAMPLE_RATE)
		var oscillator := sin(phase)
		if wave == "triangle": oscillator = asin(sin(phase)) * 2.0 / PI
		elif wave == "square": oscillator = 1.0 if sin(phase) >= 0.0 else -1.0
		var attack := minf(1.0, progress / 0.06)
		var release := pow(1.0 - progress, 1.8)
		var sample := (oscillator * (1.0 - noise_amount) + rng.randf_range(-1.0, 1.0) * noise_amount) * attack * release * 0.72
		var encoded := clampi(int(sample * 32767.0), -32768, 32767)
		bytes[frame * 2] = encoded & 0xff
		bytes[frame * 2 + 1] = (encoded >> 8) & 0xff
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = bytes
	return stream
