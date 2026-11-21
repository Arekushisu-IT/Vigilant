extends RefCounted
## A deterministic, drawn-only QR-style code (Chapter 6). It looks like a QR code (three finder squares, timing
## lines, an alignment square, data modules) but encodes nothing and cannot be scanned: the pattern comes from
## a hash of the text, so the same email always shows the same code. No camera, no network, nothing opened.
## Hosts: const QRCode := preload("res://scripts/ui/qr_code.gd")

const MODULES := 25          ## a version-2 sized grid
const QUIET := 2             ## white border, in modules
const DARK := Color("111418")
const LIGHT := Color("f7f7f2")


## The module grid as rows of bools (true = dark), deterministic for `seed_text`.
static func grid(seed_text: String) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(seed_text)
	var g: Array = []
	var fixed: Array = []
	for y: int in MODULES:
		var row: Array[bool] = []
		var frow: Array[bool] = []
		for x: int in MODULES:
			row.append(rng.randf() < 0.5)
			frow.append(false)
		g.append(row)
		fixed.append(frow)
	# Finder squares in three corners, each with a light separator ring.
	for corner: Vector2i in [Vector2i(0, 0), Vector2i(MODULES - 7, 0), Vector2i(0, MODULES - 7)]:
		for dy: int in range(-1, 8):
			for dx: int in range(-1, 8):
				var x := corner.x + dx
				var y := corner.y + dy
				if x < 0 or y < 0 or x >= MODULES or y >= MODULES:
					continue
				var ring := maxi(absi(dx - 3), absi(dy - 3))
				g[y][x] = ring != 2 and ring <= 3
				fixed[y][x] = true
	# Timing lines between the finders.
	for i: int in range(8, MODULES - 8):
		g[6][i] = i % 2 == 0
		g[i][6] = i % 2 == 0
		fixed[6][i] = true
		fixed[i][6] = true
	# One alignment square near the bottom-right corner.
	var c := MODULES - 7
	for dy: int in range(-2, 3):
		for dx: int in range(-2, 3):
			g[c + dy][c + dx] = maxi(absi(dx), absi(dy)) != 1
	return g


## The code as a texture: `scale` pixels per module, with a quiet border. Draw it with TEXTURE_FILTER_NEAREST.
static func texture(seed_text: String, scale: int = 6) -> ImageTexture:
	var g := grid(seed_text)
	var side := (MODULES + QUIET * 2) * scale
	var img := Image.create_empty(side, side, false, Image.FORMAT_RGBA8)
	img.fill(LIGHT)
	for y: int in MODULES:
		for x: int in MODULES:
			if g[y][x]:
				img.fill_rect(Rect2i((x + QUIET) * scale, (y + QUIET) * scale, scale, scale), DARK)
	return ImageTexture.create_from_image(img)
