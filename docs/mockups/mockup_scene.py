# Vigilant low-poly style mockup: builds one office corner in a chosen style and renders it.
# Run: blender -b --factory-startup --python mockup_scene.py -- <style> <out.png> [time]
#   style: pastel | gensan | noir      time (optional): morning | noon | afternoon | evening
import bpy, sys, math

argv = sys.argv[sys.argv.index("--") + 1:]
STYLE = argv[0]
OUT = argv[1]
TIME = argv[2] if len(argv) > 2 else ""

def srgb(h):
    h = h.lstrip("#")
    return tuple((int(h[i:i + 2], 16) / 255.0) ** 2.2 for i in (0, 2, 4))

PALETTES = {
    "pastel": dict(floor="#e9d8c4", wall="#f6efe4", wall2="#f1e6d6", desk="#f3f3f0", leg="#9aa5b1", chair="#7cc6b4",
                   accent="#f08a7e", screen="#8fd3ff", rug="#b9e3d6", sky="#bfe6ff", plant="#6cbf84", pot="#f08a7e",
                   person="#3f6fb6", skin="#e0b48c", world="#dfeefa", world_str=0.9),
    "gensan": dict(floor="#c9a27a", wall="#efe6d6", wall2="#8b5a3c", desk="#a8744f", leg="#4a4a4a", chair="#2f5d62",
                   accent="#e3b04b", screen="#7fc8f8", rug="#d9c49a", sky="#9fd4f2", plant="#3f8f4f", pot="#b5653a",
                   person="#2b4c7e", skin="#c99a72", world="#f2e7d5", world_str=0.8),
    "noir": dict(floor="#1b2230", wall="#22293a", wall2="#151a26", desk="#2c3445", leg="#11151d", chair="#3a4258",
                 accent="#ff3ea5", screen="#36e4ff", rug="#2a2140", sky="#0b1530", plant="#2f6b55", pot="#3a4258",
                 person="#5b2a86", skin="#c99a72", world="#0a0e18", world_str=0.25),
}
P = PALETTES[STYLE]

# Clean scene
for o in list(bpy.data.objects):
    bpy.data.objects.remove(o, do_unlink=True)
scene = bpy.context.scene

_mats = {}
def mat(key, color=None, emit=0.0, rough=0.85):
    name = f"{key}_{emit}"
    if name in _mats:
        return _mats[name]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes.get("Principled BSDF")
    c = srgb(color or P[key])
    b.inputs["Base Color"].default_value = (*c, 1)
    b.inputs["Roughness"].default_value = rough
    if emit > 0:
        b.inputs["Emission Color"].default_value = (*c, 1)
        b.inputs["Emission Strength"].default_value = emit
    _mats[name] = m
    return m

def finish(o, m):
    o.data.materials.append(m)
    for p in o.data.polygons:
        p.use_smooth = False
    return o

def box(loc, size, m, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc, rotation=rot)
    o = bpy.context.active_object
    o.scale = size
    return finish(o, m)

def cyl(loc, r, h, m, verts=8, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=h, location=loc, rotation=rot)
    return finish(bpy.context.active_object, m)

def cone(loc, r1, r2, h, m, verts=6, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r1, radius2=r2, depth=h, location=loc, rotation=rot)
    return finish(bpy.context.active_object, m)

def ico(loc, r, m, sub=1):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=sub, radius=r, location=loc)
    return finish(bpy.context.active_object, m)

def text(body, loc, size, m, rot=(math.radians(90), 0, 0)):
    bpy.ops.object.text_add(location=loc, rotation=rot)
    t = bpy.context.active_object
    t.data.body = body
    t.data.size = size
    t.data.extrude = 0.005
    t.data.align_x = "CENTER"
    t.data.materials.append(m)
    return t

# Room: floor, back wall (with window), left wall
box((0, 0, -0.05), (7, 6, 0.1), mat("floor"))
box((-0.0, 2.55, 1.5), (7, 0.1, 3), mat("wall"))
box((-3.05, 0, 1.5), (0.1, 6, 3), mat("wall"))
box((-3.0, 0, 0.06), (0.02, 6, 0.12), mat("leg"))   # skirting
box((0, 2.5, 0.06), (7, 0.02, 0.12), mat("leg"))

# Window on the back wall + view
sky_color = P["sky"]
time_sky = {"morning": "#ffd9a8", "noon": "#bfe6ff", "afternoon": "#ffc56b", "evening": "#3a3f78"}
if TIME:
    sky_color = time_sky[TIME]
box((1.2, 2.49, 1.65), (2.6, 0.02, 1.3), mat("sky", sky_color, emit=1.2 if STYLE != "noir" and TIME != "evening" else 0.6))
for x in (-0.1, 1.2, 2.5):
    box((x, 2.46, 1.65), (0.06, 0.06, 1.36), mat("leg"))
for z in (1.0, 2.3):
    box((1.2, 2.46, z), (2.66, 0.06, 0.06), mat("leg"))
if STYLE == "gensan" and TIME not in ("evening",):
    box((1.2, 2.475, 1.15), (2.6, 0.01, 0.3), mat("sea", "#2f86b8", emit=0.8))       # the sea
    mtn = cone((0.5, 2.475, 1.55), 0.75, 0.05, 0.5, mat("mtn", "#4f7f6a", emit=0.5), verts=7)  # Mt. Matutum
    mtn.scale = (1.0, 0.02, 1.0)
if STYLE == "noir" or TIME == "evening":
    for i in range(14):
        x = -0.0 + (i * 0.17) % 2.4
        z = 1.1 + ((i * 37) % 9) * 0.1
        box((x, 2.47, z), (0.05, 0.005, 0.05), mat("citylight", "#ffd36e", emit=8))

# Wall accents
if STYLE == "gensan":
    box((-3.0, 0, 0.6), (0.03, 6, 1.2), mat("wall2"))      # wooden wainscot
    box((-1.6, 2.49, 0.6), (2.6, 0.03, 1.2), mat("wall2"))
if STYLE == "noir":
    box((-3.0, 0, 2.6), (0.03, 6, 0.04), mat("accent", emit=12))   # neon strip
    box((-1.6, 2.49, 2.6), (2.8, 0.03, 0.04), mat("neon2", "#36e4ff", emit=12))
if STYLE == "pastel":
    box((-3.0, 0.3, 1.5), (0.02, 1.6, 3), mat("accent"))    # coral accent wall stripe

# Whiteboard with the company name
box((-2.98, -0.4, 1.6), (0.04, 1.6, 0.9), mat("board", "#fbfbf8" if STYLE != "noir" else "#2c3445"))
text("AEGIS SOLUTIONS", (-2.95, -0.4, 1.78), 0.13, mat("ink", "#2b4c7e" if STYLE != "noir" else "#36e4ff", emit=0 if STYLE != "noir" else 4), rot=(math.radians(90), 0, math.radians(90)))
text("Vigilant Protocol", (-2.95, -0.4, 1.55), 0.09, mat("ink2", "#f08a7e" if STYLE == "pastel" else "#e3b04b" if STYLE == "gensan" else "#ff3ea5", emit=0 if STYLE != "noir" else 4), rot=(math.radians(90), 0, math.radians(90)))

# Rug + player's desk
box((0.2, 1.0, 0.005), (2.4, 1.8, 0.01), mat("rug"))
box((0.2, 1.55, 0.74), (1.6, 0.75, 0.05), mat("desk"))
for dx in (-0.72, 0.72):
    for dy in (-0.3, 0.3):
        box((0.2 + dx, 1.55 + dy, 0.36), (0.05, 0.05, 0.72), mat("leg"))
# Monitor, keyboard, PC, phone, mug
box((0.25, 1.75, 0.83), (0.18, 0.12, 0.02), mat("leg"))
box((0.25, 1.77, 0.93), (0.04, 0.04, 0.2), mat("leg"))
box((0.25, 1.76, 1.13), (0.66, 0.04, 0.4), mat("monitor", "#1a1d24"))
box((0.25, 1.735, 1.13), (0.6, 0.01, 0.34), mat("screen", emit=3.5))
box((0.25, 1.4, 0.775), (0.5, 0.16, 0.02), mat("kb", "#30343c"))
box((0.85, 1.6, 0.98), (0.2, 0.45, 0.44), mat("pc", "#2a2e36"))
box((-0.35, 1.45, 0.79), (0.2, 0.22, 0.06), mat("phone", "#2a2e36"))
box((-0.35, 1.42, 0.835), (0.06, 0.2, 0.04), mat("handset", "#1f2329"))
cyl((-0.35, 1.58, 0.83), 0.015, 0.02, mat("ring", "#ff4040", emit=6), verts=6)
cyl((0.62, 1.35, 0.8), 0.04, 0.1, mat("accent"), verts=8)
# Chair
cyl((0.25, 0.85, 0.05), 0.3, 0.04, mat("leg"), verts=5)
cyl((0.25, 0.85, 0.27), 0.03, 0.42, mat("leg"), verts=6)
box((0.25, 0.85, 0.5), (0.5, 0.48, 0.08), mat("chair"))
box((0.25, 0.62, 0.82), (0.48, 0.07, 0.56), mat("chair"), rot=(math.radians(-8), 0, 0))
# "YOUR DESK" sign
text("YOUR DESK", (0.25, 2.2, 2.25), 0.16, mat("sign", "#3fa7d6", emit=2), rot=(math.radians(90), 0, 0))

# Second desk (coworker) on the left
box((-1.8, 1.55, 0.74), (1.3, 0.7, 0.05), mat("desk"))
for dx in (-0.6, 0.6):
    for dy in (-0.28, 0.28):
        box((-1.8 + dx, 1.55 + dy, 0.36), (0.05, 0.05, 0.72), mat("leg"))
box((-1.8, 1.76, 1.1), (0.56, 0.04, 0.34), mat("monitor", "#1a1d24"))
box((-1.8, 1.735, 1.1), (0.5, 0.01, 0.28), mat("screen2", "#24324a" if STYLE != "noir" else "#ff3ea5", emit=1.5))

# Plants
for (px, py, s) in ((-2.6, 2.1, 1.0), (2.6, 2.1, 0.8)):
    cyl((px, py, 0.2 * s), 0.18 * s, 0.4 * s, mat("pot"), verts=6)
    for i, (ox, oy, oz) in enumerate(((0, 0, 0.55), (0.1, 0.05, 0.75), (-0.08, -0.04, 0.85), (0.02, 0.08, 1.0))):
        ico((px + ox * s, py + oy * s, oz * s), (0.22 - i * 0.03) * s, mat("plant"))

# ---------- People (low-poly, with arms and legs) ----------
def person(x, y, face_toward, shirt, pants, hair="#2a1d17", seated=False, clipboard=False, bun=False):
    """Builds a low-poly person in local space (facing -Y) and parents it to an empty at (x, y)."""
    root = bpy.data.objects.new("Person", None)
    scene.collection.objects.link(root)
    root.location = (x, y, 0)
    dx, dy = face_toward[0] - x, face_toward[1] - y
    root.rotation_euler = (0, 0, math.atan2(dx, -dy))
    parts = []
    S, PA, SK, HA = mat("shirt_" + shirt, shirt), mat("pants_" + pants, pants), mat("skin"), mat("hair_" + hair, hair)
    shoe = mat("shoe", "#222428")
    if seated:
        hip_z = 0.52
        for sx in (-0.09, 0.09):
            parts.append(box((sx, -0.47, 0.03), (0.1, 0.2, 0.06), shoe))                       # shoes
            parts.append(cyl((sx, -0.44, 0.27), 0.06, 0.44, PA, verts=6))                       # shins
            parts.append(cyl((sx, -0.22, hip_z), 0.07, 0.42, PA, verts=6, rot=(math.radians(90), 0, 0)))  # thighs
    else:
        hip_z = 0.86
        for sx in (-0.09, 0.09):
            parts.append(box((sx, -0.04, 0.03), (0.1, 0.22, 0.06), shoe))
            parts.append(cyl((sx, 0, 0.45), 0.065, 0.8, PA, verts=6))                          # legs
    parts.append(box((0, 0, hip_z), (0.3, 0.19, 0.14), PA))                                       # hips
    t = cone((0, 0, hip_z + 0.27), 0.16, 0.21, 0.42, S, verts=8)                                   # torso, wider at shoulders
    t.scale = (1, 0.62, 1)
    parts.append(t)
    sh_z = hip_z + 0.45
    parts.append(cyl((0, 0, sh_z + 0.06), 0.045, 0.09, SK, verts=6))                            # neck
    h = ico((0, 0, sh_z + 0.2), 0.12, SK)                                                          # head
    h.scale = (0.92, 0.95, 1.05)
    parts.append(h)
    hr = ico((0, 0.025, sh_z + 0.24), 0.125, HA)                                                  # hair
    hr.scale = (1.0, 1.0, 0.82)
    parts.append(hr)
    if bun:
        parts.append(ico((0, 0.12, sh_z + 0.25), 0.06, HA))
    for ex in (-0.04, 0.04):
        parts.append(box((ex, -0.108, sh_z + 0.2), (0.022, 0.01, 0.022), mat("eye", "#1d1d22")))   # eyes
    parts.append(box((0, -0.125, hip_z + 0.32), (0.07, 0.01, 0.09), mat("badge", "#ffffff")))     # ID badge
    parts.append(box((0, -0.12, hip_z + 0.4), (0.012, 0.01, 0.12), mat("lanyard", "#3fa7d6")))
    for side in (-1, 1):
        ax = 0.225 * side
        parts.append(ico((ax, 0, sh_z - 0.02), 0.06, S))                                          # shoulder
        bent = seated or (clipboard and side == 1)
        if bent:
            parts.append(cyl((ax, 0, sh_z - 0.16), 0.045, 0.28, S, verts=6))                      # upper arm
            parts.append(cyl((ax * 0.9, -0.15, sh_z - 0.3), 0.04, 0.3, SK, verts=6, rot=(math.radians(90), 0, 0)))  # forearm forward
            parts.append(ico((ax * 0.85, -0.31, sh_z - 0.3), 0.045, SK))                          # hand
        else:
            parts.append(cyl((ax * 1.05, 0, sh_z - 0.3), 0.045, 0.56, S, verts=6, rot=(0, math.radians(-6 * side), 0)))  # whole arm
            parts.append(ico((ax * 1.12, 0, sh_z - 0.61), 0.045, SK))
    if clipboard:
        parts.append(box((0.14, -0.33, sh_z - 0.24), (0.22, 0.02, 0.3), mat("clip", "#b07a4a"), rot=(math.radians(-35), 0, 0)))
        parts.append(box((0.14, -0.345, sh_z - 0.23), (0.18, 0.01, 0.24), mat("paper", "#fbfbf8"), rot=(math.radians(-35), 0, 0)))
    for p in parts:
        p.parent = root
    return root

# Ms. Dela Vega, security officer, holding a clipboard
person(-2.0, -0.2, (2.55, -2.35), "#2b4c7e" if STYLE != "noir" else "#5b2a86", "#2a2e36", clipboard=True, bun=True)
# A coworker working at the other desk (decoration only, not interactive)
cyl((-1.8, 0.92, 0.05), 0.26, 0.04, mat("leg"), verts=5)
cyl((-1.8, 0.92, 0.25), 0.03, 0.4, mat("leg"), verts=6)
box((-1.8, 0.92, 0.47), (0.46, 0.44, 0.07), mat("chair"))
box((-1.8, 0.7, 0.78), (0.44, 0.06, 0.52), mat("chair"))
person(-1.8, 0.95, (-1.8, 2.0), "#e3b04b" if STYLE == "gensan" else "#f08a7e" if STYLE == "pastel" else "#36a3b5", "#3b3f4a", hair="#3a2a1e", seated=True)

# ---------- More life ----------
# Ceiling with light panels
box((0, 0, 3.02), (7, 6, 0.04), mat("ceiling", "#f4f1ec" if STYLE != "noir" else "#121722"))
for lx in (-1.6, 0.4, 2.2):
    for ly in (-0.8, 1.2):
        box((lx, ly, 2.99), (0.7, 0.7, 0.02), mat("panel", "#fff7e8" if STYLE != "noir" else "#8aa0ff", emit=4 if STYLE != "noir" else 1.5))
# Wall clock (back wall, above the coworker)
clock = cyl((-1.8, 2.47, 2.3), 0.19, 0.04, mat("clockrim", "#2a2e36"), verts=12, rot=(math.radians(90), 0, 0))
cyl((-1.8, 2.445, 2.3), 0.16, 0.02, mat("clockface", "#fbfbf8"), verts=12, rot=(math.radians(90), 0, 0))
box((-1.8, 2.43, 2.35), (0.015, 0.005, 0.1), mat("hand", "#1d1d22"))
box((-1.76, 2.43, 2.3), (0.08, 0.005, 0.012), mat("hand", "#1d1d22"))
# Security awareness poster
box((-0.75, 2.48, 1.75), (0.55, 0.02, 0.75), mat("poster", "#3fa7d6" if STYLE != "gensan" else "#2f5d62"))
box((-0.75, 2.47, 1.86), (0.42, 0.01, 0.32), mat("posterimg", "#fbfbf8", emit=0.3))
cone((-0.75, 2.46, 1.86), 0.12, 0.0, 0.18, mat("shield", "#e3b04b"), verts=3, rot=(math.radians(90), math.radians(180), 0))
text("THINK BEFORE", (-0.75, 2.465, 1.58), 0.065, mat("ptext", "#ffffff", emit=0.5))
text("YOU CLICK", (-0.75, 2.465, 1.49), 0.065, mat("ptext", "#ffffff", emit=0.5))
# Bookshelf on the left wall
box((-2.8, -1.6, 0.9), (0.36, 1.0, 1.8), mat("shelf", "#a8744f" if STYLE != "noir" else "#2c3445"))
book_cols = ["#e05a47", "#3fa7d6", "#e3b04b", "#4caf6a", "#8a5cc2", "#f08a7e"]
for row, z in enumerate((0.25, 0.75, 1.25)):
    box((-2.62, -1.6, z - 0.2), (0.02, 0.96, 0.03), mat("shelfboard", "#7a5236"))
    yy = -2.0
    for i in range(7):
        w = 0.06 + ((i + row) % 3) * 0.02
        hgt = 0.26 + ((i * 7 + row) % 4) * 0.03
        box((-2.66, yy + w / 2, z - 0.18 + hgt / 2), (0.18, w, hgt), mat("book" + book_cols[(i + row) % 6], book_cols[(i + row) % 6]))
        yy += w + 0.015
# Wall-mounted aircon (left wall)
box((-2.92, 0.9, 2.55), (0.22, 0.9, 0.28), mat("ac", "#f4f4f4"))
box((-2.8, 0.9, 2.45), (0.02, 0.8, 0.03), mat("acvent", "#c9cfd6"))
# Desk lamp, papers, pen cup, trash bin, framed photo
cyl((-0.62, 1.82, 0.78), 0.07, 0.02, mat("leg"), verts=8)
box((-0.62, 1.82, 0.95), (0.025, 0.025, 0.34), mat("leg"), rot=(math.radians(-15), 0, 0))
cone((-0.62, 1.74, 1.1), 0.09, 0.03, 0.12, mat("accent"), verts=8, rot=(math.radians(150), 0, 0))
for i in range(4):
    box((-1.5, 1.45, 0.775 + i * 0.008), (0.3, 0.22, 0.006), mat("paper", "#fbfbf8"), rot=(0, 0, math.radians(i * 4 - 6)))
cyl((-2.25, 1.65, 0.82), 0.04, 0.12, mat("pencup", "#3fa7d6"), verts=8)
cyl((1.15, 1.1, 0.15), 0.14, 0.3, mat("bin", "#6b737d"), verts=8)
box((0.75, 1.82, 0.84), (0.14, 0.02, 0.12), mat("frame", "#2a2e36"), rot=(math.radians(-12), 0, 0))
# Tall snake plant on the right
cyl((2.9, 0.2, 0.18), 0.17, 0.36, mat("pot"), verts=6)
for i, (ox, oy, rz) in enumerate(((0, 0, 0), (0.06, 0.04, 20), (-0.06, 0.03, -18), (0.02, -0.06, 8), (-0.03, -0.04, -6))):
    cone((2.9 + ox, 0.2 + oy, 0.62 + (i % 2) * 0.08), 0.05, 0.0, 0.7 + (i % 3) * 0.12, mat("plant"), verts=4, rot=(math.radians(ox * 60), math.radians(oy * 60), math.radians(rz)))

# GenSan touches: stand fan + water dispenser
if STYLE == "gensan":
    cyl((2.3, 0.9, 0.03), 0.18, 0.04, mat("leg"), verts=8)
    cyl((2.3, 0.9, 0.6), 0.025, 1.15, mat("leg"), verts=6)
    cyl((2.3, 0.9, 1.2), 0.24, 0.08, mat("fan", "#e8eef2"), verts=10, rot=(math.radians(90), 0, math.radians(30)))
    box((2.6, 1.6, 0.5), (0.32, 0.32, 1.0), mat("disp", "#f4f4f4"))
    cyl((2.6, 1.6, 1.2), 0.13, 0.4, mat("bottle", "#6fb7e8"), verts=8)

# Lighting
world = bpy.data.worlds.new("W")
scene.world = world
world.use_nodes = True
bg = world.node_tree.nodes["Background"]
bg.inputs[0].default_value = (*srgb(P["world"]), 1)
bg.inputs[1].default_value = P["world_str"]

sun_settings = {
    "": (srgb("#fff3dd"), 3.5, 55, 160),
    "morning": (srgb("#ffc98a"), 3.0, 18, 120),
    "noon": (srgb("#ffffff"), 4.0, 70, 170),
    "afternoon": (srgb("#ffb35c"), 3.2, 30, 210),
    "evening": (srgb("#7a7fd8"), 0.4, 8, 220),
}
if STYLE != "noir":
    col, power, elev, az = sun_settings[TIME]
    sun = bpy.data.lights.new("Sun", "SUN")
    sun.energy = power
    sun.color = col
    so = bpy.data.objects.new("Sun", sun)
    scene.collection.objects.link(so)
    so.rotation_euler = (math.radians(90 - elev), 0, math.radians(az))

def area(loc, power, color, size=1.5):
    l = bpy.data.lights.new("A", "AREA")
    l.energy = power
    l.color = color
    l.size = size
    o = bpy.data.objects.new("A", l)
    o.location = loc
    scene.collection.objects.link(o)

if STYLE == "noir":
    area((0.2, 1.0, 2.9), 120, srgb("#6f8cff"))
    area((-2.5, 0.5, 2.6), 80, srgb("#ff3ea5"), 1.0)
    area((0.25, 1.2, 1.3), 25, srgb("#36e4ff"), 0.6)
else:
    lamp = 160 if TIME == "evening" else 90
    area((0.2, 0.8, 2.9), lamp, srgb("#fff1dc"), 2.0)
    area((-1.8, 0.8, 2.9), lamp * 0.7, srgb("#fff1dc"), 2.0)

# Camera
cam = bpy.data.cameras.new("Cam")
cam.lens = 22
co = bpy.data.objects.new("Cam", cam)
scene.collection.objects.link(co)
co.location = (2.55, -2.35, 1.75)
target = (-0.6, 1.3, 0.95)
dx, dy, dz = (target[i] - co.location[i] for i in range(3))
co.rotation_euler = (math.atan2(math.hypot(dx, dy), -dz), 0, math.atan2(dy, dx) - math.pi / 2)
scene.camera = co

# Render
for eng in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT"):
    try:
        scene.render.engine = eng
        break
    except TypeError:
        continue
try:
    scene.eevee.taa_render_samples = 48
    scene.eevee.use_raytracing = True
except Exception:
    pass
scene.render.resolution_x = 1280
scene.render.resolution_y = 720
scene.render.filepath = OUT
scene.render.image_settings.file_format = "PNG"
bpy.ops.render.render(write_still=True)
print("RENDERED", OUT)
