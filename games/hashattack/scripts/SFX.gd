extends Node

const _RATE := 22050

func _make_tone(freq: float, dur: float, vol: float) -> AudioStreamWAV:
	var n := int(_RATE * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / _RATE
		var fade := minf(1.0, float(n - i) / maxf(1.0, _RATE * 0.04))
		var s := clampi(int(sin(TAU * freq * t) * fade * vol * 32767.0), -32768, 32767)
		data[i * 2] = s & 0xFF
		data[i * 2 + 1] = (s >> 8) & 0xFF
	var wav := AudioStreamWAV.new()
	wav.data = data
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = _RATE
	wav.stereo = false
	return wav

func _make_sequence(freqs: Array, note_dur: float, vol: float) -> AudioStreamWAV:
	var spn := int(_RATE * note_dur)
	var data := PackedByteArray()
	data.resize(spn * freqs.size() * 2)
	for ni in freqs.size():
		var freq: float = freqs[ni]
		for i in spn:
			var gi := ni * spn + i
			var t := float(i) / _RATE
			var attack := minf(1.0, float(i) / maxf(1.0, _RATE * 0.005))
			var decay := minf(1.0, float(spn - i) / maxf(1.0, _RATE * 0.04))
			var env := attack * decay
			var s := clampi(int(sin(TAU * freq * t) * env * vol * 32767.0), -32768, 32767)
			data[gi * 2] = s & 0xFF
			data[gi * 2 + 1] = (s >> 8) & 0xFF
	var wav := AudioStreamWAV.new()
	wav.data = data
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = _RATE
	wav.stereo = false
	return wav

func _play(stream: AudioStreamWAV) -> void:
	var p := AudioStreamPlayer.new()
	p.stream = stream
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)

func click() -> void:
	_play(_make_tone(880.0, 0.05, 0.22))

func win() -> void:
	_play(_make_sequence([523.25, 659.25, 783.99, 1046.5], 0.11, 0.38))

func lose() -> void:
	_play(_make_sequence([392.0, 349.23, 293.66, 261.63], 0.13, 0.32))
