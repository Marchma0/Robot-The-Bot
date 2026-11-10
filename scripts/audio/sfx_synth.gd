class_name SfxSynth
extends RefCounted
## Petits bruitages calculés par le code (le projet n'a pas encore de fichiers sons) : coup de poing, cloche,
## « boing », buzzer, explosion… Chaque son est calculé une seule fois puis gardé en cache.
## Purement local : à jouer depuis un RPC `authority, call_local` de l'hôte (effet d'un instant), jamais pour un état.

const RATE: int = 22050

static var _cache: Dictionary[StringName, AudioStreamWAV] = {}


## Joue le son `kind` en 3D, à `offset` dans le repère de `at` (le lecteur se libère tout seul à la fin).
static func play(at: Node3D, kind: StringName, offset: Vector3 = Vector3.ZERO, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if at == null or not at.is_inside_tree():
		return
	var player: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
	player.stream = _stream(kind)
	player.volume_db = volume_db
	player.pitch_scale = pitch
	player.unit_size = 5.0
	player.max_distance = 35.0
	player.position = offset
	at.add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


static func _stream(kind: StringName) -> AudioStreamWAV:
	if not _cache.has(kind):
		_cache[kind] = _to_wav(_samples(kind))
	return _cache[kind]


static func _samples(kind: StringName) -> PackedFloat32Array:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash(kind)
	match kind:
		&"punch":
			return _render(0.3, func(t: float, ph: Array[float]) -> float:
				ph[0] += lerpf(150.0, 45.0, minf(t / 0.12, 1.0)) / RATE
				ph[1] += (rng.randf_range(-1.0, 1.0) - ph[1]) * 0.3
				return sin(ph[0] * TAU) * exp(-t * 14.0) * 0.9 + ph[1] * exp(-t * 35.0) * 0.9)
		&"bell":
			return _render(1.6, func(t: float, _ph: Array[float]) -> float:
				var s: float = 0.0
				var partials: Array[Vector3] = [Vector3(1.0, 0.5, 2.0), Vector3(2.4, 0.3, 3.0), Vector3(3.9, 0.18, 4.5), Vector3(5.4, 0.1, 6.0)]
				for p: Vector3 in partials:
					s += sin(TAU * 988.0 * p.x * t) * p.y * exp(-t * p.z)
				return s * minf(t * 400.0, 1.0))
		&"boing":
			return _render(0.55, func(t: float, ph: Array[float]) -> float:
				ph[0] += (140.0 + 260.0 * minf(t * 3.0, 1.0) + 60.0 * sin(t * 50.0) * exp(-t * 4.0)) / RATE
				return sin(ph[0] * TAU) * exp(-t * 4.5) * 0.7)
		&"buzzer":
			return _render(0.5, func(t: float, _ph: Array[float]) -> float:
				var sq: float = signf(sin(TAU * 92.0 * t)) * 0.5 + signf(sin(TAU * 95.5 * t)) * 0.5
				return sq * 0.3 * clampf((0.5 - t) * 12.0, 0.0, 1.0))
		&"boom":
			return _render(1.3, func(t: float, ph: Array[float]) -> float:
				ph[0] += (rng.randf_range(-1.0, 1.0) - ph[0]) * 0.06
				ph[1] += lerpf(70.0, 30.0, minf(t, 1.0)) / RATE
				var crackle: float = rng.randf_range(-1.0, 1.0) * exp(-t * 18.0) * 0.4
				return clampf((ph[0] * 5.0 * exp(-t * 3.0) + sin(ph[1] * TAU) * exp(-t * 5.0) * 0.8 + crackle), -1.0, 1.0))
		&"clang":
			return _render(0.7, func(t: float, _ph: Array[float]) -> float:
				var s: float = 0.0
				for k: float in [1.0, 2.76, 5.4, 8.93]:
					s += sin(TAU * 410.0 * k * t) / k
				return s * exp(-t * 6.0) * 0.6 + rng.randf_range(-1.0, 1.0) * exp(-t * 60.0) * 0.5)
		&"bonk":
			return _render(0.22, func(t: float, ph: Array[float]) -> float:
				ph[0] += lerpf(520.0, 150.0, minf(t / 0.1, 1.0)) / RATE
				return sin(ph[0] * TAU) * exp(-t * 18.0) * 0.9)
		&"swish":
			return _render(0.35, func(t: float, ph: Array[float]) -> float:
				var x: float = rng.randf_range(-1.0, 1.0)
				ph[0] += (x - ph[0]) * 0.5
				ph[1] += (x - ph[1]) * 0.08
				return (ph[0] - ph[1]) * sin(PI * t / 0.35) * 0.8)
		&"ding":
			return _render(0.6, func(t: float, _ph: Array[float]) -> float:
				return (sin(TAU * 1318.5 * t) * 0.5 + sin(TAU * 1975.5 * t) * 0.3) * exp(-t * 6.0))
		&"fanfare":
			return _render(0.75, func(t: float, _ph: Array[float]) -> float:
				var notes: Array[float] = [523.25, 659.25, 783.99, 1046.5]
				var idx: int = mini(int(t / 0.11), notes.size() - 1)
				var local_t: float = t - idx * 0.11
				var f: float = notes[idx]
				var tone: float = sin(TAU * f * t) * 0.6 + sin(TAU * f * 2.0 * t) * 0.2 + sin(TAU * f * 3.0 * t) * 0.1
				return tone * exp(-local_t * (2.5 if idx == notes.size() - 1 else 9.0)) * 0.6)
	return PackedFloat32Array([0.0])


## Calcule `duration` secondes de son : `gen(t, état)` rend un échantillon (-1..1), `état` garde les phases et filtres.
static func _render(duration: float, gen: Callable) -> PackedFloat32Array:
	var count: int = int(duration * RATE)
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(count)
	var state: Array[float] = [0.0, 0.0, 0.0, 0.0]
	for i: int in count:
		out[i] = gen.call(float(i) / RATE, state)
	return out


static func _to_wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i: int in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = bytes
	return wav
