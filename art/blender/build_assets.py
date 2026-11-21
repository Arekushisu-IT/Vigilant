# Vigilant - detailed low-poly asset builder (GenSan office + people).
# Builds every asset by script (no downloads), exports each to game/assets/models/<name>.glb,
# renders a contact sheet and a people sheet, and saves vigilant_office.blend.
#
# Run headless:
#   "C:/Program Files/Blender Foundation/Blender 5.1/blender.exe" -b --factory-startup --python build_assets.py -- [options]
# Options:
#   --tmp <dir>        folder for intermediate tile renders (default: system temp)
#   --only a,b,c       build/export only these assets (file names without .glb); skips the .blend save
#   --no-render        skip the contact/people sheets
#
# Conventions (Blender Z-up, metres). The glTF exporter converts to Godot Y-up:
#   Blender (x, y, z)  ->  Godot (x, z, -y).   Blender -Y (front)  ==  Godot +Z.
# Every asset's "front" faces Blender -Y (Godot +Z) unless noted; origins are base-centre on the floor
# or desk top, back-face centre for wall items, top centre for ceiling items.
import bpy, bmesh, sys, os, math, random, tempfile
from mathutils import Matrix, Vector, Euler

ROOT = "C:/Users/ADMIN/Desktop/Dev Apps/Vigilant"
MODELS = ROOT + "/game/assets/models"
BLEND = ROOT + "/art/blender/vigilant_office.blend"
SHEET = ROOT + "/art/blender/contact_sheet.png"
PEOPLE_SHEET = ROOT + "/art/blender/people_sheet.png"

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []


def _arg(flag, default=None):
    return argv[argv.index(flag) + 1] if flag in argv else default


TMP = _arg("--tmp", os.path.join(tempfile.gettempdir(), "vigilant_tiles"))
ONLY = set(_arg("--only", "").split(",")) - {""}
RENDER = "--no-render" not in argv
os.makedirs(MODELS, exist_ok=True)
os.makedirs(TMP, exist_ok=True)

# ------------------------------------------------------------------ scene reset
for o in list(bpy.data.objects):
    bpy.data.objects.remove(o, do_unlink=True)
for c in list(bpy.data.collections):
    bpy.data.collections.remove(c)
SCENE = bpy.context.scene
ASSET_COLL = bpy.data.collections.new("Assets")
SCENE.collection.children.link(ASSET_COLL)

FONT = None
for fp in ("C:/Windows/Fonts/segoeuib.ttf", "C:/Windows/Fonts/arialbd.ttf"):
    if os.path.exists(fp):
        try:
            FONT = bpy.data.fonts.load(fp)
            break
        except Exception:
            pass

PI = math.pi
R = math.radians


def lin(h):
    h = h.lstrip("#")
    c = [int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]
    return tuple(x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c)


def shade(h, f):
    h = h.lstrip("#")
    c = [min(255, max(0, int(int(h[i:i + 2], 16) * f))) for i in (0, 2, 4)]
    return "#%02x%02x%02x" % tuple(c)


def xf(loc=(0, 0, 0), rot=(0, 0, 0), scale=(1, 1, 1)):
    if isinstance(scale, (int, float)):
        scale = (scale, scale, scale)
    return Matrix.LocRotScale(Vector(loc), Euler([R(a) for a in rot]), Vector(scale))


# ------------------------------------------------------------------ materials
# name: (hex, roughness, emission, alpha, metallic)
MATS = {
    "Wood": ("#a8744f", .65), "WoodDark": ("#7a5236", .7), "WoodLight": ("#c99c6e", .65),
    "MetalDark": ("#3a3f46", .45, 0, 1, .3), "Metal": ("#8c939b", .4, 0, 1, .5),
    "MetalLight": ("#b9c0c7", .45, 0, 1, .3), "Chrome": ("#d5dade", .25, 0, 1, .7),
    "PlasticBlack": ("#1c1f24", .5), "PlasticDark": ("#2b2e34", .55), "PlasticGrey": ("#5a616b", .6),
    "PlasticWhite": ("#eceae4", .55), "PlasticBeige": ("#ddd5c4", .6), "Keys": ("#50565f", .6),
    "Rubber": ("#202226", .9),
    "Screen": ("#101419", .3), "PowerLED": ("#49e08a", .5, 3.0), "RingBulb": ("#5a1010", .4),
    "LCD": ("#8fbf9a", .4, .5), "PrinterLCD": ("#7fc8f8", .4, 1.0),
    "FabricTeal": ("#2f5d62", .95), "FabricDark": ("#24282e", .95), "FabricPanel": ("#6b7c8c", .95),
    "Counter": ("#7b5236", .7), "CounterTop": ("#e4dac9", .5), "Accent": ("#3fa7d6", .5),
    "Paper": ("#f7f5ef", .9), "PaperBlue": ("#dfe8f0", .9), "Folder": ("#d9b77a", .9),
    "PaperWrap": ("#3f7fc0", .8), "TextGrey": ("#9aa0a6", .9),
    "Glass": ("#c7e0f0", .1, 0, .35), "GlassFrost": ("#f2f6f8", .4, 0, .7),
    "Whiteboard": ("#f7f8f8", .25), "MarkerBlue": ("#1f4e8c", .5), "MarkerRed": ("#c0392b", .5),
    "MarkerBlack": ("#2d2d2d", .5), "EraserFelt": ("#8d8f93", .95),
    "Pot": ("#b5653c", .85), "PotWhite": ("#e9e4da", .6), "PotBand": ("#3d4a52", .6), "Soil": ("#4a3426", 1),
    "Leaf": ("#4f8a4b", .8), "LeafDark": ("#3d7240", .8), "LeafLight": ("#6faa58", .8),
    "SnakeLeaf": ("#3f6e3a", .7), "SnakeEdge": ("#b8b65a", .7), "Stem": ("#5b7a3a", .8),
    "WaterBlue": ("#5aa9e6", .15, 0, .8), "TapRed": ("#d64541", .5), "TapBlue": ("#2e86de", .5),
    "CoffeeBlack": ("#1e1b19", .4), "Coffee": ("#3b2416", .3), "Sugar": ("#f4efe6", .8),
    "MugBody": ("#c0392b", .5), "MugCream": ("#f0e6d2", .5), "MugBlue": ("#2e86ab", .5),
    "MugYellow": ("#e3b04b", .5),
    "PosterTeal": ("#2f5d62", .8), "PosterGold": ("#e3b04b", .6), "White": ("#fbfbf8", .8),
    "Ink": ("#2b4c7e", .6), "InkGold": ("#c98e2a", .6),
    "ClockFace": ("#fbfbf8", .6), "ClockRim": ("#2a2e36", .4), "ClockHand": ("#1d1d22", .5),
    "ClockRed": ("#d64541", .5),
    "ACWhite": ("#f4f4f2", .5), "ACVent": ("#c9cfd6", .6), "ACLED": ("#4fd1ff", .4, 2.0),
    "FanBlade": ("#bfdbe6", .4), "LampShade": ("#e3b04b", .5), "LampBulb": ("#fff2c8", .3, 4.0),
    "LightPanel": ("#fffaf0", .3, 2.0), "PanelFrame": ("#e9e7e1", .5),
    "NeonPink": ("#ff3ea5", .3, 6.0), "NeonCyan": ("#36e4ff", .3, 6.0),
    "DoorMat": ("#3d3a37", 1), "DoorMatBorder": ("#5a4a3c", 1), "Backdrop": ("#d8d2c6", .9, .35),
    "BackdropFloor": ("#b9a58c", .9, .3),
    "FrameDark": ("#454a52", .5), "Blinds": ("#ece6da", .7), "Sill": ("#e9e4da", .6),
    "SkyTop": ("#8fc9ef", 1, 1.0), "SkyHorizon": ("#d4ecf7", 1, 1.0), "Sea": ("#2f86b8", 1, 1.0),
    "SeaLight": ("#5fa9d3", 1, 1.0), "Mountain": ("#5f8f78", 1, 1.0), "MountainFar": ("#8fb3a6", 1, 1.0),
    "CityDay": ("#e6dccb", 1, 1.0), "CityDay2": ("#c7bba8", 1, 1.0), "Palm": ("#3f7a4a", 1, 1.0),
    "NightSky": ("#0b1530", 1, 1.0), "NightHorizon": ("#2a2f5e", 1, 1.0), "NightMountain": ("#151b33", 1, 1.0),
    "NightSea": ("#0e1c33", 1, 1.0), "CityNight": ("#1a2036", 1, 1.0), "CityLights": ("#ffd36e", 1, 4.0),
    "NightGround": ("#121729", 1, 1.0),
    "Cork": ("#b98a5a", .95), "NoteYellow": ("#f3d36b", .9), "NotePink": ("#f2a0b0", .9),
    "NoteBlue": ("#9fcbe8", .9), "NoteGreen": ("#a8d8a0", .9), "PinRed": ("#d64541", .4),
    "Book_Red": ("#d0533f", .8), "Book_Blue": ("#3f8fc4", .8), "Book_Gold": ("#e3b04b", .8),
    "Book_Green": ("#4caf6a", .8), "Book_Purple": ("#8a5cc2", .8), "Book_Coral": ("#f08a7e", .8),
    "Book_Navy": ("#2b4c7e", .8), "Book_Cream": ("#e2d8c3", .8), "Binder": ("#f2f0ea", .7),
    "Eye": ("#1d1d22", .4), "IDCard": ("#f7f7f4", .6), "IDPhoto": ("#9aa7b5", .6),
    "Clipboard": ("#b07a4a", .7), "PhotoSky": ("#8fc9ef", .8), "PhotoSand": ("#e3cf9e", .8),
    "PhotoSea": ("#3f8fc4", .8), "Bell": ("#d8b25a", .3, 0, 1, .6),
    # Home (condo) and cafe.
    "SofaFabric": ("#5b6f8a", .95), "BedSheet": ("#e6ecf0", .9), "Pillow": ("#f4efe4", .9),
    "Blanket": ("#c96f53", .95), "TileKitchen": ("#e3e8e6", .35), "CabinetWhite": ("#f1efe9", .5),
    "Steel": ("#aeb5bb", .3, 0, 1, .6), "CafeWood": ("#8a5a3b", .6), "Chalkboard": ("#2b3330", .9),
    "ChalkWhite": ("#ecebe4", .9), "Apron": ("#3c5a4a", .85), "CupWhite": ("#f6f4ee", .4),
    "IcedCoffee": ("#8a5a3c", .2, 0, .78), "StringBulb": ("#ffd98a", .3, 5.0), "PhoneCase": ("#2a3a52", .5),
    "Curtain": ("#d8c3a0", .95), "Pastry": ("#d9a25b", .8), "PastryDark": ("#9c5b2e", .8),
    "Rug": ("#8c4a3c", 1), "RugBorder": ("#e0c48a", 1), "ScreenBezel": ("#0c0e12", .3),
    # Window views (unshaded in Godot, recoloured per mood like the office views).
    "Road": ("#6a6c70", 1, 1.0), "Sidewalk": ("#bdb5a6", 1, 1.0), "JeepneyBody": ("#d4dade", 1, 1.0),
    "JeepneyStripe": ("#c0392b", 1, 1.0), "JeepneyDark": ("#2b2e34", 1, 1.0), "WindowDay": ("#9cc6e0", 1, 1.0),
}
_MAT_CACHE = {}


def M(name, hexcol=None, rough=0.75, emit=0.0, alpha=1.0, metal=0.0):
    """Returns the named material, creating it from MATS (or the given values) the first time."""
    if name in _MAT_CACHE:
        return _MAT_CACHE[name]
    if name in MATS:
        spec = list(MATS[name]) + [None] * 5
        hexcol = spec[0]
        rough = spec[1] if spec[1] is not None else rough
        emit = spec[2] or 0.0
        alpha = spec[3] if spec[3] is not None else 1.0
        metal = spec[4] or 0.0
    m = bpy.data.materials.new(name)
    if m.node_tree is None:
        m.use_nodes = True
    b = m.node_tree.nodes.get("Principled BSDF")
    c = lin(hexcol)
    b.inputs["Base Color"].default_value = (*c, 1)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    if emit > 0:
        b.inputs["Emission Color"].default_value = (*c, 1)
        b.inputs["Emission Strength"].default_value = emit
    if alpha < 1:
        b.inputs["Alpha"].default_value = alpha
        for attr, val in (("surface_render_method", "BLENDED"), ("blend_method", "BLEND")):
            try:
                setattr(m, attr, val)
            except Exception:
                pass
    m.diffuse_color = (*c, alpha)
    _MAT_CACHE[name] = m
    return m


# ------------------------------------------------------------------ mesh builder
class MB:
    """Accumulates flat-shaded primitives into one bmesh with per-face materials."""

    def __init__(self):
        self.bm = bmesh.new()
        self.mats = []

    def _start(self):
        for f in self.bm.faces:
            f.tag = True
        for v in self.bm.verts:
            v.tag = True

    def _new_verts(self):
        return [v for v in self.bm.verts if not v.tag]

    def _finish(self, m):
        if m not in self.mats:
            self.mats.append(m)
        i = self.mats.index(m)
        for f in self.bm.faces:
            if not f.tag:
                f.material_index = i
                f.smooth = False
                f.tag = True
        for v in self.bm.verts:
            v.tag = True

    @staticmethod
    def _bevel(tb, amount):
        bmesh.ops.bevel(tb, geom=tb.verts[:] + tb.edges[:], offset=amount, segments=1, affect='EDGES', profile=0.5)

    def _emit(self, tb, m, bevel=0.0):
        # Operators run on a private bmesh (they clear element tags), then the result is merged in.
        if bevel > 0:
            self._bevel(tb, bevel)
        self.merge_bm(tb, m)
        tb.free()

    def box(self, size, loc, m, rot=(0, 0, 0), bevel=0.0):
        tb = bmesh.new()
        bmesh.ops.create_cube(tb, size=1.0, matrix=xf(loc, rot, size))
        self._emit(tb, m, bevel)

    def cyl(self, r1, r2, h, loc, m, seg=8, rot=(0, 0, 0), scale=(1, 1, 1)):
        """Cylinder/cone centred at loc along local Z (r1 bottom, r2 top)."""
        tb = bmesh.new()
        bmesh.ops.create_cone(tb, cap_ends=True, cap_tris=False, segments=seg, radius1=r1,
                              radius2=r2, depth=h, matrix=xf(loc, rot, scale))
        self._emit(tb, m)

    def _frame(self, p0, p1, up=(0, -1, 0)):
        p0, p1 = Vector(p0), Vector(p1)
        d = p1 - p0
        L = d.length
        z = d / L
        y = Vector(up)
        y = y - y.dot(z) * z
        if y.length < 1e-6:
            y = z.orthogonal()
        y.normalize()
        x = y.cross(z)
        return Matrix.Translation((p0 + p1) / 2) @ Matrix((x, y, z)).transposed().to_4x4(), L

    def tube(self, p0, p1, r0, r1, m, seg=8):
        """Cylinder between two points (r0 at p0, r1 at p1)."""
        F, L = self._frame(p0, p1)
        tb = bmesh.new()
        bmesh.ops.create_cone(tb, cap_ends=True, cap_tris=False, segments=seg, radius1=r0,
                              radius2=r1, depth=L, matrix=F)
        self._emit(tb, m)

    def beam(self, p0, p1, w, t, m, up=(0, -1, 0), bevel=0.0):
        """Box running from p0 to p1, width w, thickness t along `up`."""
        F, L = self._frame(p0, p1, up)
        tb = bmesh.new()
        bmesh.ops.create_cube(tb, size=1.0, matrix=F @ Matrix.Diagonal((w, t, L, 1)))
        self._emit(tb, m, bevel)

    def sphere(self, loc, scale, m, u=8, v=6, rot=(0, 0, 0)):
        if isinstance(scale, (int, float)):
            scale = (scale, scale, scale)
        tb = bmesh.new()
        bmesh.ops.create_uvsphere(tb, u_segments=u, v_segments=v, radius=1.0, matrix=xf(loc, rot, scale))
        self._emit(tb, m)

    def ico(self, loc, scale, m, sub=1, rot=(0, 0, 0)):
        if isinstance(scale, (int, float)):
            scale = (scale, scale, scale)
        tb = bmesh.new()
        bmesh.ops.create_icosphere(tb, subdivisions=sub, radius=1.0, matrix=xf(loc, rot, scale))
        self._emit(tb, m)

    def loft(self, rings, m, seg=8, matrix=None, cap0=True, cap1=True, inward=False):
        """Tube through rings (z, rx, ry[, cy[, cx]]) along local Z, with a flat face at the front (-Y)."""
        rings = sorted(rings, key=lambda r: r[0])
        a0 = -PI / 2 + PI / seg
        Mx = matrix or Matrix.Identity(4)
        self._start()
        loops = []
        for r in rings:
            z, rx, ry = r[0], r[1], r[2]
            cy = r[3] if len(r) > 3 else 0.0
            cx = r[4] if len(r) > 4 else 0.0
            loops.append([self.bm.verts.new(Mx @ Vector((cx + rx * math.cos(a0 + i * 2 * PI / seg),
                                                          cy + ry * math.sin(a0 + i * 2 * PI / seg), z)))
                          for i in range(seg)])
        for i in range(len(loops) - 1):
            A, B = loops[i], loops[i + 1]
            for j in range(seg):
                q = [A[j], A[(j + 1) % seg], B[(j + 1) % seg], B[j]]
                self.bm.faces.new(q[::-1] if inward else q)
        if cap0:
            f = loops[0][::-1]
            self.bm.faces.new(f[::-1] if inward else f)
        if cap1:
            f = loops[-1]
            self.bm.faces.new(f[::-1] if inward else f)
        self._finish(m)

    def poly(self, pts, m, depth=0.004, yfun=None, lift=0.0, _slice=True):
        """Flat polygon in the XZ plane facing -Y, extruded back (+Y) by depth.
        yfun(x, z) gives the surface y for each point (decals that hug a curved front); such convex
        decals are cut into thin horizontal strips so they follow the curve instead of sinking in."""
        pts = list(pts)
        zs = [p[1] for p in pts]
        if yfun is not None and _slice and max(zs) - min(zs) > 0.02:
            def span(z):
                xs = []
                for i in range(len(pts)):
                    (x1, z1), (x2, z2) = pts[i][:2], pts[(i + 1) % len(pts)][:2]
                    if min(z1, z2) - 1e-9 <= z <= max(z1, z2) + 1e-9 and abs(z2 - z1) > 1e-9:
                        xs.append(x1 + (z - z1) / (z2 - z1) * (x2 - x1))
                return (min(xs), max(xs)) if xs else (0.0, 0.0)
            z0, z1 = min(zs) + 1e-5, max(zs) - 1e-5
            n = int(math.ceil((z1 - z0) / 0.015))
            for i in range(n):
                za, zb = z0 + (z1 - z0) * i / n, z0 + (z1 - z0) * (i + 1) / n
                (la, ra), (lb, rb) = span(za), span(zb)
                sub = [(la, za), (ra, za), (rb, zb), (lb, zb)]
                if ra - la < 1e-4:
                    sub = [(la, za), (rb, zb), (lb, zb)]
                elif rb - lb < 1e-4:
                    sub = [(la, za), (ra, za), (lb, zb)]
                self.poly(sub, m, depth, yfun, lift, _slice=False)
            return
        area = sum(pts[i][0] * pts[(i + 1) % len(pts)][1] - pts[(i + 1) % len(pts)][0] * pts[i][1]
                   for i in range(len(pts)))
        if area < 0:
            pts.reverse()
        self._start()
        front, back = [], []
        for p in pts:
            x, z = p[0], p[1]
            y0 = (yfun(x, z) if yfun else (p[2] if len(p) > 2 else 0.0)) - lift
            front.append(self.bm.verts.new((x, y0, z)))
            back.append(self.bm.verts.new((x, y0 + depth + lift, z)))
        n = len(pts)
        self.bm.faces.new(front)
        self.bm.faces.new(back[::-1])
        for i in range(n):
            j = (i + 1) % n
            self.bm.faces.new([front[j], front[i], back[i], back[j]])
        self._finish(m)

    def merge_bm(self, tb, m, matrix=None):
        self._start()
        vmap = {}
        for v in tb.verts:
            vmap[v] = self.bm.verts.new((matrix @ v.co) if matrix else v.co)
        for f in tb.faces:
            try:
                self.bm.faces.new([vmap[v] for v in f.verts])
            except ValueError:
                pass
        self._finish(m)

    def cap(self, center, scale, cuts, m, u=12, v=8):
        """UV sphere with the positive side of each (point, normal) plane removed (hair caps)."""
        tb = bmesh.new()
        bmesh.ops.create_uvsphere(tb, u_segments=u, v_segments=v, radius=1.0, matrix=xf(center, (0, 0, 0), scale))
        for co, no in cuts:
            geom = tb.verts[:] + tb.edges[:] + tb.faces[:]
            bmesh.ops.bisect_plane(tb, geom=geom, dist=1e-6, plane_co=Vector(co), plane_no=Vector(no).normalized(),
                                   clear_outer=True)
        self.merge_bm(tb, m)
        tb.free()

    def text(self, body, size, m, matrix, extrude=0.0015, align="CENTER"):
        cu = bpy.data.curves.new("tmp_txt", 'FONT')
        cu.body = body
        cu.size = size
        cu.align_x = align
        cu.align_y = 'CENTER'
        cu.extrude = extrude
        cu.resolution_u = 2
        if FONT:
            cu.font = FONT
        ob = bpy.data.objects.new("tmp_txt", cu)
        SCENE.collection.objects.link(ob)
        bpy.context.view_layer.update()
        dg = bpy.context.evaluated_depsgraph_get()
        me = bpy.data.meshes.new_from_object(ob.evaluated_get(dg))
        tb = bmesh.new()
        tb.from_mesh(me)
        self.merge_bm(tb, m, matrix)
        tb.free()
        bpy.data.objects.remove(ob)
        bpy.data.curves.remove(cu)
        bpy.data.meshes.remove(me)

    def quad_y(self, w, h, loc, m, uv=False):
        """Single quad in the XZ plane facing -Y (screens)."""
        self._start()
        x, y, z = loc
        vs = [self.bm.verts.new((x - w / 2, y, z - h / 2)), self.bm.verts.new((x + w / 2, y, z - h / 2)),
              self.bm.verts.new((x + w / 2, y, z + h / 2)), self.bm.verts.new((x - w / 2, y, z + h / 2))]
        f = self.bm.faces.new(vs)
        if uv:
            lay = self.bm.loops.layers.uv.verify()
            for loop, c in zip(f.loops, ((0, 0), (1, 0), (1, 1), (0, 1))):
                loop[lay].uv = c
        self._finish(m)

    def scale(self, k):
        bmesh.ops.scale(self.bm, vec=(k, k, k), verts=self.bm.verts)


def make_obj(name, mb, coll, parent=None, pivot=(0, 0, 0)):
    """Mesh object from a builder (or an empty when mb is None). Geometry is re-centred on `pivot`."""
    pivot = Vector(pivot)
    if mb is None:
        o = bpy.data.objects.new(name, None)
        o.empty_display_size = 0.08
    else:
        if pivot.length:
            bmesh.ops.translate(mb.bm, vec=-pivot, verts=mb.bm.verts)
        me = bpy.data.meshes.new(name)
        mb.bm.normal_update()
        mb.bm.to_mesh(me)
        mb.bm.free()
        for m in mb.mats:
            me.materials.append(m)
        o = bpy.data.objects.new(name, me)
    coll.objects.link(o)
    if parent is not None:
        o.parent = parent
    o.location = pivot
    return o


# ------------------------------------------------------------------ asset registry and export
ASSETS = []


def hierarchy(root):
    return [root] + list(root.children_recursive)


def bbox(objs):
    bpy.context.view_layer.update()
    lo = Vector((1e9, 1e9, 1e9))
    hi = Vector((-1e9, -1e9, -1e9))
    for o in objs:
        if o.type != 'MESH' or o.hide_render:
            continue
        mw = o.matrix_world
        for v in o.data.vertices:
            p = mw @ v.co
            lo = Vector(map(min, lo, p))
            hi = Vector(map(max, hi, p))
    return lo, hi


def export_glb(root, fname):
    for o in bpy.context.view_layer.objects:
        o.select_set(False)
    for o in hierarchy(root):
        o.select_set(True)
    bpy.context.view_layer.objects.active = root
    path = os.path.join(MODELS, fname + ".glb")
    kw = dict(filepath=path, export_format='GLB', use_selection=True, export_yup=True, export_apply=True,
              export_cameras=False, export_lights=False, export_extras=False)
    try:
        bpy.ops.export_scene.gltf(export_animations=False, **kw)
    except TypeError:
        bpy.ops.export_scene.gltf(**kw)
    return path


def build(fname, rootname, fn, origin, view="front"):
    if ONLY and fname not in ONLY:
        return None
    coll = bpy.data.collections.new(rootname)
    ASSET_COLL.children.link(coll)
    root = fn(coll, rootname)
    lo, hi = bbox(hierarchy(root))
    export_glb(root, fname)
    ASSETS.append(dict(file=fname, root=root, coll=coll, lo=lo, hi=hi, origin=origin, view=view))
    # Free the generic child names ("Screen", "Head" ...) for the next asset.
    for o in root.children_recursive:
        o.name = rootname + "__" + o.name
        if o.data is not None:
            o.data.name = o.name
    print("EXPORTED %-22s %.2f x %.2f x %.2f" % (fname, hi.x - lo.x, hi.y - lo.y, hi.z - lo.z))
    return root


def single(fn):
    """Wraps a builder that fills one MB into a single-mesh asset."""
    def _f(coll, name):
        mb = MB()
        fn(mb)
        return make_obj(name, mb, coll)
    return _f


# ================================================================== FURNITURE
def desk(mb):
    # Matches the greybox desk: top 1.6 x 0.75 at 0.75 m, legs at x +-0.76 / y +-0.33, modesty panel at the back.
    mb.box((1.6, 0.75, 0.035), (0, 0, 0.7325), M("Wood"), bevel=0.006)
    mb.box((1.54, 0.69, 0.02), (0, 0, 0.705), M("WoodDark"))
    for sx in (-0.76, 0.76):
        for sy in (-0.33, 0.33):
            mb.box((0.05, 0.05, 0.69), (sx, sy, 0.355), M("MetalDark"), bevel=0.004)
            mb.cyl(0.02, 0.02, 0.012, (sx, sy, 0.006), M("Rubber"), seg=6)
        mb.box((0.04, 0.62, 0.035), (sx, 0, 0.06), M("MetalDark"))
        mb.box((0.035, 0.62, 0.04), (sx, 0, 0.675), M("MetalDark"))
    mb.box((1.48, 0.02, 0.36), (0, 0.335, 0.5), M("WoodDark"))
    # Slim pencil drawer under the right side.
    mb.box((0.42, 0.5, 0.07), (0.48, -0.03, 0.66), M("Wood"), bevel=0.004)
    mb.box((0.12, 0.012, 0.014), (0.48, -0.285, 0.66), M("Metal"))
    # Cable grommet.
    mb.cyl(0.03, 0.03, 0.002, (-0.55, 0.26, 0.7505), M("PlasticDark"), seg=10)


def office_chair(mb):
    # Seat top at 0.47 m. Backrest toward Blender -Y (Godot +Z) exactly like the greybox chair.
    blk, fab = M("PlasticBlack"), M("FabricTeal")
    for i in range(5):
        a = R(90 + i * 72)
        cx, cy = math.cos(a), math.sin(a)
        mb.beam((0.03 * cx, 0.03 * cy, 0.075), (0.29 * cx, 0.29 * cy, 0.06), 0.045, 0.03, blk, up=(0, 0, 1))
        mb.cyl(0.025, 0.025, 0.03, (0.28 * cx, 0.28 * cy, 0.025), M("Rubber"), seg=8, rot=(90, 0, math.degrees(a)))
    mb.cyl(0.055, 0.05, 0.06, (0, 0, 0.08), blk, seg=10)
    mb.cyl(0.036, 0.036, 0.16, (0, 0, 0.19), blk, seg=10)
    mb.cyl(0.024, 0.024, 0.14, (0, 0, 0.32), M("Chrome"), seg=10)
    mb.box((0.24, 0.24, 0.04), (0, 0, 0.38), M("PlasticDark"), bevel=0.006)
    mb.box((0.49, 0.47, 0.075), (0, 0.01, 0.4325), fab, bevel=0.022)
    mb.box((0.06, 0.035, 0.3), (0, -0.25, 0.52), M("PlasticDark"), rot=(8, 0, 0))
    mb.box((0.46, 0.065, 0.5), (0, -0.285, 0.83), fab, rot=(9, 0, 0), bevel=0.025)
    mb.box((0.42, 0.02, 0.44), (0, -0.322, 0.83), M("PlasticDark"), rot=(9, 0, 0), bevel=0.01)
    for sx in (-0.255, 0.255):
        mb.box((0.03, 0.04, 0.2), (sx, -0.04, 0.53), M("PlasticDark"))
        mb.box((0.055, 0.24, 0.03), (sx, 0.0, 0.64), blk, bevel=0.01)


def monitor(coll, name):
    root = make_obj(name, None, coll)
    mb = MB()
    blk = M("PlasticBlack")
    mb.box((0.24, 0.17, 0.015), (0, 0, 0.0075), blk, bevel=0.004)
    mb.box((0.05, 0.04, 0.24), (0, 0.035, 0.13), blk, bevel=0.005)
    mb.box((0.64, 0.035, 0.39), (0, 0, 0.335), blk, bevel=0.004)
    mb.box((0.4, 0.04, 0.24), (0, 0.035, 0.335), blk, bevel=0.012)
    mb.box((0.05, 0.002, 0.008), (0, -0.0185, 0.152), M("MetalLight"))
    mb.box((0.008, 0.002, 0.004), (0.29, -0.0185, 0.152), M("PowerLED"))
    make_obj("MonitorBody", mb, coll, root)
    sc = MB()
    # Same size and place as the greybox screen quad (0.58 x 0.335, centre 0.335 up, 0.0185 in front).
    sc.quad_y(0.58, 0.335, (0, -0.0185, 0.335), M("Screen"), uv=True)
    make_obj("Screen", sc, coll, root)
    return root


def keyboard(mb):
    mb.box((0.44, 0.14, 0.016), (0, 0, 0.008), M("PlasticDark"), bevel=0.003)
    k = M("Keys")
    for row in range(4):
        y = 0.044 - row * 0.026
        for c in range(13):
            mb.box((0.024, 0.021, 0.008), (-0.18 + c * 0.03, y, 0.019), k)
    y = 0.044 - 4 * 0.026
    for x, w in ((-0.165, 0.054), (-0.115, 0.024), (0.0, 0.15), (0.12, 0.024), (0.17, 0.054)):
        mb.box((w, 0.021, 0.008), (x, y, 0.019), k)


def mouse(mb):
    mb.box((0.22, 0.19, 0.003), (0, 0, 0.0015), M("FabricDark"), bevel=0.001)
    mb.sphere((0, 0.005, 0.012), (0.032, 0.054, 0.02), M("PlasticBlack"), u=10, v=6)
    mb.box((0.002, 0.04, 0.004), (0, -0.025, 0.028), M("PlasticGrey"))
    mb.box((0.006, 0.014, 0.006), (0, -0.022, 0.029), M("PlasticGrey"))


def pc_tower(mb):
    mb.box((0.2, 0.42, 0.42), (0, 0, 0.21), M("PlasticBlack"), bevel=0.006)
    mb.box((0.18, 0.006, 0.4), (0, -0.211, 0.21), M("PlasticDark"))
    for i in range(6):
        mb.box((0.12, 0.004, 0.008), (0, -0.214, 0.06 + i * 0.022), M("PlasticBlack"))
    mb.box((0.14, 0.004, 0.035), (0, -0.214, 0.3), M("PlasticBlack"))
    mb.cyl(0.013, 0.013, 0.006, (0.05, -0.215, 0.36), M("PlasticGrey"), seg=10, rot=(90, 0, 0))
    mb.box((0.02, 0.006, 0.02), (0.05, -0.218, 0.36), M("PowerLED"))     # greybox LED spot
    for x in (-0.045, -0.015):
        mb.box((0.018, 0.004, 0.008), (x, -0.215, 0.36), M("Rubber"))


def desk_phone(coll, name):
    # Origin = greybox phone base (desk top under PHONE_LOCAL). Ring bulb exactly at the greybox spot.
    root = make_obj(name, None, coll)
    mb = MB()
    dk = M("PlasticDark")
    mb.box((0.2, 0.22, 0.045), (0, 0, 0.0225), dk, bevel=0.008)
    mb.box((0.2, 0.09, 0.02), (0, 0.06, 0.055), dk, bevel=0.005)
    for r in range(4):
        for c in range(3):
            mb.box((0.018, 0.014, 0.006), (0.012 + c * 0.024, -0.005 - r * 0.02, 0.047), M("PlasticGrey"))
    mb.box((0.08, 0.035, 0.004), (0.035, 0.06, 0.066), M("LCD"))
    for y in (-0.085, 0.085):
        mb.box((0.05, 0.03, 0.03), (-0.065, y, 0.055), dk, bevel=0.004)
    mb.box((0.012, 0.012, 0.004), (0.085, -0.09, 0.047), M("TapRed"))
    make_obj("PhoneBase", mb, coll, root)
    hs = MB()
    _handset(hs, (-0.065, 0, 0.082))
    make_obj("Handset", hs, coll, root, pivot=(-0.065, 0, 0.082))
    bb = MB()
    bb.sphere((0.075, 0.085, 0.065), 0.017, M("RingBulb"), u=10, v=6)
    make_obj("RingBulb", bb, coll, root, pivot=(0.075, 0.085, 0.065))
    return root


def _handset(mb, c, axis_rot=None):
    """Handset lying along Y centred at c (axis_rot: optional 3x3 to orient it)."""
    c = Vector(c)
    parts = [((0.045, 0.13, 0.026), (0, 0, 0.006)), ((0.055, 0.055, 0.036), (0, 0.085, -0.004)),
             ((0.055, 0.055, 0.036), (0, -0.085, -0.004))]
    for size, off in parts:
        loc = c + (axis_rot @ Vector(off) if axis_rot else Vector(off))
        if axis_rot:
            e = axis_rot.to_euler()
            mb.box(size, loc, M("PlasticBlack"), rot=tuple(math.degrees(a) for a in e), bevel=0.008)
        else:
            mb.box(size, loc, M("PlasticBlack"), bevel=0.008)


def reception(mb):
    # Greybox counter: body 2.0 x 0.55 x 1.05, top 2.1 x 0.7 at 1.07 (shifted 0.03 to the front).
    # Centre front panel left plain and dark so the RECEPTION Label3D (at 0.58 m) stays readable.
    mb.box((1.96, 0.5, 0.06), (0, 0.02, 0.03), M("MetalDark"))
    mb.box((2.0, 0.55, 0.99), (0, 0, 0.555), M("Counter"), bevel=0.006)
    for side in (-1, 1):
        for i in range(5):
            x = side * (0.6 + i * 0.075)
            mb.box((0.045, 0.02, 0.74), (x, -0.283, 0.47), M("WoodDark"), bevel=0.004)
    mb.box((2.0, 0.012, 0.06), (0, -0.281, 0.88), M("Accent"))
    mb.box((2.1, 0.7, 0.04), (0, -0.03, 1.07), M("CounterTop"), bevel=0.008)
    # Guest logbook with a pen, and a service bell.
    mb.box((0.34, 0.24, 0.012), (-0.5, -0.17, 1.096), M("Ink"), bevel=0.003)
    mb.box((0.155, 0.22, 0.006), (-0.582, -0.17, 1.105), M("Paper"), rot=(0, -2, 0))
    mb.box((0.155, 0.22, 0.006), (-0.418, -0.17, 1.105), M("Paper"), rot=(0, 2, 0))
    for i in range(5):
        mb.box((0.11, 0.004, 0.001), (-0.418, -0.25 + i * 0.03, 1.109), M("TextGrey"))
    mb.tube((-0.45, -0.23, 1.11), (-0.36, -0.12, 1.112), 0.005, 0.004, M("MarkerBlack"), seg=6)
    mb.cyl(0.045, 0.045, 0.01, (-0.85, -0.2, 1.095), M("MetalDark"), seg=12)
    mb.sphere((-0.85, -0.2, 1.1), (0.04, 0.04, 0.035), M("Bell"), u=12, v=6)
    mb.cyl(0.006, 0.006, 0.015, (-0.85, -0.2, 1.14), M("Bell"), seg=6)


def filing_cabinet(mb):
    mb.box((0.45, 0.6, 0.03), (0, 0, 0.015), M("MetalDark"))
    mb.box((0.47, 0.62, 0.99), (0, 0, 0.525), M("MetalLight"), bevel=0.006)
    for i in range(3):
        zc = 0.2 + i * 0.32
        mb.box((0.43, 0.012, 0.3), (0, -0.315, zc), M("MetalLight"), bevel=0.004)
        mb.box((0.16, 0.025, 0.02), (0, -0.33, zc + 0.02), M("MetalDark"), bevel=0.004)
        mb.box((0.08, 0.004, 0.04), (0, -0.322, zc + 0.09), M("MetalDark"))
        mb.box((0.07, 0.003, 0.03), (0, -0.324, zc + 0.09), M("Paper"))
    mb.box((0.04, 0.03, 0.02), (0.13, -0.31, 1.0), M("Chrome"))


BOOK_MATS = ["Book_Red", "Book_Blue", "Book_Gold", "Book_Green", "Book_Purple", "Book_Coral", "Book_Navy",
             "Book_Cream"]


def bookshelf(mb):
    rnd = random.Random(7)
    w, d, h = 0.9, 0.32, 1.8
    for sx in (-1, 1):
        mb.box((0.025, d, h), (sx * (w / 2 - 0.0125), 0, h / 2), M("Wood"), bevel=0.003)
    mb.box((w, d, 0.025), (0, 0, h - 0.0125), M("Wood"), bevel=0.003)
    mb.box((w - 0.05, d - 0.02, 0.07), (0, 0.0, 0.035), M("WoodDark"))
    mb.box((w - 0.05, 0.01, h - 0.03), (0, d / 2 - 0.005, h / 2), M("WoodDark"))
    levels = [0.07, 0.42, 0.77, 1.12, 1.46]
    for z in levels[1:]:
        mb.box((w - 0.05, d - 0.02, 0.02), (0, 0, z - 0.01), M("Wood"))
    for li, z in enumerate(levels):
        x = -0.41
        gap_at = rnd.randint(3, 8)
        n = 0
        while x < 0.36:
            n += 1
            if n == gap_at:
                # A leaning book after a gap.
                bw, bh = 0.035, 0.25
                mb.box((bw, 0.19, bh), (x + 0.08, -0.03, z + bh / 2 - 0.02), M(rnd.choice(BOOK_MATS)), rot=(0, 18, 0))
                x += 0.16
                continue
            binder = rnd.random() < 0.15
            bw = 0.06 if binder else rnd.uniform(0.022, 0.045)
            bh = 0.29 if binder else rnd.uniform(0.19, 0.28)
            bd = 0.24 if binder else rnd.uniform(0.17, 0.22)
            if x + bw > 0.41:
                break
            mat = M("Binder") if binder else M(rnd.choice(BOOK_MATS))
            mb.box((bw, bd, bh), (x + bw / 2, -0.13 + bd / 2 - 0.02, z + bh / 2), mat)
            if binder:
                mb.box((0.035, 0.002, 0.05), (x + bw / 2, -0.152, z + bh * 0.7), M("Book_Blue"))
            elif rnd.random() < 0.5:
                mb.box((bw + 0.001, bd * 0.6, 0.012), (x + bw / 2, -0.13 + bd / 2 - 0.02, z + bh * 0.8), M("Book_Cream"))
            x += bw + 0.004
    # Folders on top.
    mb.box((0.3, 0.24, 0.05), (-0.2, 0, h + 0.025), M("Folder"), rot=(0, 0, 4))
    mb.box((0.3, 0.24, 0.03), (-0.19, 0, h + 0.065), M("Book_Blue"), rot=(0, 0, -3))


def printer_station(mb):
    # Cabinet 0.7 x 0.5 x 0.72 with a printer and paper reams on top (~1.02 m).
    mb.box((0.66, 0.46, 0.06), (0, 0.01, 0.03), M("WoodDark"))
    mb.box((0.7, 0.5, 0.66), (0, 0, 0.39), M("Wood"), bevel=0.004)
    for sx in (-1, 1):
        mb.box((0.335, 0.012, 0.58), (sx * 0.172, -0.255, 0.39), M("WoodLight"), bevel=0.004)
        mb.box((0.012, 0.02, 0.12), (sx * 0.03, -0.268, 0.5), M("Metal"))
    mb.box((0.72, 0.52, 0.025), (0, 0, 0.7325), M("WoodDark"), bevel=0.004)
    t = 0.745
    mb.box((0.46, 0.4, 0.22), (-0.1, 0.02, t + 0.11), M("PlasticWhite"), bevel=0.012)
    mb.box((0.46, 0.38, 0.045), (-0.1, 0.03, t + 0.2425), M("PlasticBeige"), bevel=0.01)
    mb.box((0.34, 0.1, 0.03), (-0.1, -0.15, t + 0.14), M("PlasticDark"))
    mb.box((0.21, 0.15, 0.006), (-0.1, -0.15, t + 0.158), M("Paper"), rot=(-6, 0, 0))
    mb.box((0.36, 0.05, 0.07), (-0.1, -0.185, t + 0.05), M("PlasticGrey"), bevel=0.006)
    mb.box((0.17, 0.08, 0.02), (0.04, -0.17, t + 0.205), M("PlasticDark"), rot=(-25, 0, 0), bevel=0.004)
    mb.box((0.07, 0.004, 0.035), (0.02, -0.207, t + 0.212), M("PrinterLCD"), rot=(-25, 0, 0))
    mb.cyl(0.008, 0.008, 0.008, (0.09, -0.205, t + 0.21), M("PowerLED"), seg=6, rot=(65, 0, 0))
    for i in range(2):
        mb.box((0.21, 0.3, 0.05), (0.235, 0.0, t + 0.025 + i * 0.05), M("Paper"), rot=(0, 0, i * 6 - 3))
        mb.box((0.212, 0.1, 0.051), (0.235, 0.0, t + 0.025 + i * 0.05), M("PaperWrap"), rot=(0, 0, i * 6 - 3))


def _mug(mb, c, mat, s=1.0):
    x, y, z = c
    mb.cyl(0.04 * s, 0.038 * s, 0.095 * s, (x, y, z + 0.0475 * s), mat, seg=10)
    mb.cyl(0.034 * s, 0.034 * s, 0.004, (x, y, z + 0.085 * s), M("Coffee"), seg=10)
    hx = x + 0.048 * s
    mb.box((0.012 * s, 0.012 * s, 0.05 * s), (hx + 0.008 * s, y, z + 0.05 * s), mat)
    for zz in (0.027, 0.073):
        mb.box((0.022 * s, 0.012 * s, 0.01 * s), (hx - 0.002 * s, y, z + zz * s), mat)


def pantry_counter(mb):
    # 1.4 x 0.6 x 0.9 counter with coffee maker, kettle, jars and mugs.
    mb.box((1.36, 0.54, 0.08), (0, 0.02, 0.04), M("WoodDark"))
    mb.box((1.4, 0.58, 0.8), (0, 0, 0.48), M("Wood"), bevel=0.004)
    for i in range(3):
        x = -0.465 + i * 0.465
        mb.box((0.45, 0.012, 0.7), (x, -0.293, 0.46), M("WoodLight"), bevel=0.004)
        mb.box((0.1, 0.018, 0.012), (x, -0.304, 0.76), M("Metal"))
    mb.box((1.44, 0.62, 0.04), (0, -0.01, 0.9), M("CounterTop"), bevel=0.006)
    mb.box((1.44, 0.02, 0.12), (0, 0.3, 0.98), M("CounterTop"))
    t = 0.92
    # Coffee maker.
    cx = -0.42
    mb.box((0.2, 0.24, 0.035), (cx, 0.0, t + 0.0175), M("CoffeeBlack"), bevel=0.006)
    mb.box((0.2, 0.08, 0.32), (cx, 0.09, t + 0.16), M("CoffeeBlack"), bevel=0.008)
    mb.box((0.2, 0.22, 0.07), (cx, 0.01, t + 0.32), M("CoffeeBlack"), bevel=0.01)
    mb.cyl(0.062, 0.06, 0.13, (cx, -0.03, t + 0.1), M("Glass"), seg=10)
    mb.cyl(0.058, 0.056, 0.06, (cx, -0.03, t + 0.065), M("Coffee"), seg=10)
    mb.box((0.02, 0.03, 0.08), (cx + 0.075, -0.03, t + 0.1), M("CoffeeBlack"))
    mb.box((0.012, 0.004, 0.012), (cx + 0.07, 0.049, t + 0.06), M("TapRed"))
    # Tray of mugs.
    mb.box((0.34, 0.24, 0.015), (0.0, -0.05, t + 0.0075), M("WoodDark"), bevel=0.003)
    _mug(mb, (-0.08, -0.08, t + 0.015), M("MugCream"))
    _mug(mb, (0.06, -0.02, t + 0.015), M("MugBlue"))
    _mug(mb, (0.05, -0.12, t + 0.015), M("MugYellow"))
    # Kettle and jars.
    kx = 0.42
    mb.cyl(0.09, 0.075, 0.2, (kx, 0.02, t + 0.1), M("PlasticWhite"), seg=10)
    mb.cyl(0.05, 0.05, 0.02, (kx, 0.02, t + 0.21), M("PlasticGrey"), seg=10)
    mb.box((0.03, 0.04, 0.16), (kx + 0.1, 0.02, t + 0.11), M("PlasticGrey"), bevel=0.006)
    mb.box((0.04, 0.03, 0.03), (kx - 0.1, 0.02, t + 0.16), M("PlasticWhite"), rot=(0, 30, 0))
    for i, (jx, mat) in enumerate(((0.22, "Sugar"), (0.29, "Coffee"))):
        mb.cyl(0.035, 0.035, 0.12, (jx, 0.18, t + 0.06), M("Glass"), seg=8)
        mb.cyl(0.032, 0.032, 0.07, (jx, 0.18, t + 0.035), M(mat), seg=8)
        mb.cyl(0.037, 0.037, 0.02, (jx, 0.18, t + 0.13), M("WoodDark"), seg=8)


def water_dispenser(mb):
    mb.box((0.32, 0.32, 0.96), (0, 0, 0.48), M("PlasticWhite"), bevel=0.012)
    mb.box((0.22, 0.012, 0.24), (0, -0.157, 0.68), M("PlasticDark"), bevel=0.004)
    for x, mat in ((-0.05, "TapBlue"), (0.05, "TapRed")):
        mb.box((0.03, 0.04, 0.035), (x, -0.17, 0.77), M(mat), bevel=0.006)
        mb.cyl(0.008, 0.008, 0.03, (x, -0.17, 0.74), M("PlasticGrey"), seg=6)
    mb.box((0.18, 0.09, 0.025), (0, -0.19, 0.58), M("PlasticGrey"), bevel=0.004)
    mb.box((0.08, 0.004, 0.02), (0, -0.162, 0.3), M("PlasticGrey"))
    mb.cyl(0.08, 0.08, 0.03, (0, 0, 0.975), M("PlasticGrey"), seg=12)
    rings = [(0.96, .03, .03), (1.0, .03, .03), (1.04, .12, .12), (1.06, .132, .132), (1.12, .132, .132),
             (1.13, .126, .126), (1.14, .132, .132), (1.22, .132, .132), (1.23, .126, .126), (1.24, .132, .132),
             (1.31, .132, .132), (1.34, .12, .12), (1.37, .08, .08)]
    mb.loft(rings, M("WaterBlue"), seg=12)
    mb.cyl(0.045, 0.045, 0.27, (0.2, 0.0, 0.62), M("PlasticWhite"), seg=8)
    mb.cyl(0.04, 0.036, 0.04, (0.2, 0.0, 0.47), M("Paper"), seg=8)


# ------------------------------------------------------------------ wall items (origin: back-face centre)
def aircon(mb):
    mb.box((0.9, 0.21, 0.28), (0, -0.105, 0.0), M("ACWhite"), bevel=0.03)
    mb.box((0.82, 0.03, 0.05), (0, -0.2, -0.11), M("ACVent"), rot=(35, 0, 0))
    mb.box((0.84, 0.004, 0.012), (0, -0.212, 0.05), M("ACVent"))
    for i in range(7):
        mb.box((0.8, 0.012, 0.004), (0, -0.04 - i * 0.022, 0.14), M("ACVent"))
    mb.box((0.03, 0.004, 0.012), (0.34, -0.213, -0.02), M("ACLED"))


def wall_clock(coll, name):
    root = make_obj(name, None, coll)
    mb = MB()
    mb.cyl(0.17, 0.17, 0.045, (0, -0.0225, 0), M("ClockRim"), seg=16, rot=(90, 0, 0))
    mb.cyl(0.15, 0.15, 0.01, (0, -0.045, 0), M("ClockFace"), seg=16, rot=(90, 0, 0))
    for i in range(12):
        a = R(i * 30)
        L = 0.03 if i % 3 == 0 else 0.015
        mb.box((0.008 if i % 3 == 0 else 0.005, 0.003, L), (0.13 * math.sin(a), -0.051, 0.13 * math.cos(a) - 0),
               M("ClockHand"), rot=(0, math.degrees(a), 0))
    mb.cyl(0.012, 0.012, 0.012, (0, -0.058, 0), M("ClockHand"), seg=8, rot=(90, 0, 0))
    make_obj("ClockBody", mb, coll, root)
    # Hands rest at 12:00 and pivot at the centre: rotate them around Godot Z (see report).
    for nm, L, w, y, mat in (("HourHand", 0.075, 0.012, -0.053, "ClockHand"),
                             ("MinuteHand", 0.115, 0.008, -0.056, "ClockHand"),
                             ("SecondHand", 0.12, 0.003, -0.059, "ClockRed")):
        h = MB()
        h.box((w, 0.003, L + 0.02), (0, y, L / 2 - 0.01), M(mat))
        make_obj(nm, h, coll, root, pivot=(0, y, 0))
    return root


def poster(mb):
    mb.box((0.56, 0.02, 0.76), (0, -0.01, 0), M("ClockRim"), bevel=0.003)
    mb.box((0.5, 0.004, 0.7), (0, -0.0215, 0), M("PosterTeal"))
    mb.box((0.38, 0.003, 0.3), (0, -0.0245, 0.13), M("White"))
    # Shield with a check mark.
    shield = [(-0.08, 0.25), (0.08, 0.25), (0.08, 0.15), (0.0, 0.03), (-0.08, 0.15)]
    mb.poly([(x, z, -0.027) for x, z in shield], M("PosterGold"), depth=0.002)
    mb.beam((-0.035, -0.03, 0.15), (-0.008, -0.03, 0.115), 0.016, 0.003, M("White"))
    mb.beam((-0.012, -0.03, 0.118), (0.04, -0.03, 0.195), 0.016, 0.003, M("White"))
    rot = Matrix.Rotation(R(90), 4, 'X')
    mb.text("THINK BEFORE", 0.066, M("White"), Matrix.Translation((0, -0.025, -0.1)) @ rot, extrude=0.001)
    mb.text("YOU CLICK", 0.066, M("PosterGold"), Matrix.Translation((0, -0.025, -0.185)) @ rot, extrude=0.001)
    for i, w in enumerate((0.3, 0.24)):
        mb.box((w, 0.002, 0.01), (0, -0.024, -0.255 - i * 0.025), M("ACVent"))


def cork_board(mb):
    # Small pantry notice board (0.8 x 0.55): wood frame, cork, pinned notes and a ruled schedule sheet.
    W, H = 0.8, 0.55
    fr = M("WoodDark")
    mb.box((W, 0.02, H), (0, -0.01, 0), fr, bevel=0.004)
    mb.box((W - 0.06, 0.006, H - 0.06), (0, -0.023, 0), M("Cork"))
    sheets = [((-0.22, 0.06), (0.2, 0.26), "Paper", -2), ((0.04, 0.1), (0.13, 0.13), "NoteYellow", 6),
              ((0.22, 0.08), (0.14, 0.17), "NoteBlue", -5), ((0.07, -0.12), (0.12, 0.12), "NotePink", 4),
              ((0.24, -0.13), (0.13, 0.11), "NoteGreen", -3), ((-0.2, -0.17), (0.17, 0.07), "PaperBlue", 2)]
    for (x, z), (w, h), mat, rot in sheets:
        mb.box((w, 0.002, h), (x, -0.027, z), M(mat), rot=(0, rot, 0))
        mb.sphere((x, -0.031, z + h / 2 - 0.018), 0.008, M("PinRed"), u=6, v=4)
        n = int(h / 0.03) - 1
        for i in range(max(0, n)):
            lw = w * (0.75 if i % 3 else 0.55)
            mb.box((lw, 0.001, 0.005), (x - (w - lw) / 2 + 0.012, -0.029, z + h / 2 - 0.04 - i * 0.026),
                   M("TextGrey"), rot=(0, rot, 0))


def whiteboard(mb):
    mb.box((2.5, 0.04, 1.3), (0, -0.02, 0), M("Metal"), bevel=0.006)
    mb.box((2.4, 0.012, 1.2), (0, -0.046, 0), M("Whiteboard"))
    mb.box((2.0, 0.08, 0.03), (0, -0.08, -0.63), M("Metal"), bevel=0.004)
    for i, mat in enumerate(("MarkerBlue", "MarkerRed", "MarkerBlack")):
        x = -0.4 + 0.18 * i
        mb.tube((x - 0.065, -0.08, -0.6), (x + 0.045, -0.08, -0.6), 0.011, 0.011, M("PlasticWhite"), seg=8)
        mb.tube((x + 0.045, -0.08, -0.6), (x + 0.07, -0.08, -0.6), 0.012, 0.012, M(mat), seg=8)
    mb.box((0.13, 0.05, 0.03), (0.5, -0.08, -0.6), M("PlasticBlack"), bevel=0.004)
    mb.box((0.13, 0.05, 0.012), (0.5, -0.08, -0.62), M("EraserFelt"))
    rot = Matrix.Rotation(R(90), 4, 'X')
    mb.text("AEGIS SOLUTIONS", 0.19, M("Ink"), Matrix.Translation((0, -0.053, 0.3)) @ rot, extrude=0.0015)
    mb.text("Vigilant Protocol", 0.12, M("InkGold"), Matrix.Translation((0, -0.053, 0.1)) @ rot, extrude=0.0015)
    # Marker doodles: three boxes joined by arrows and an underline (no words).
    blue, red = M("MarkerBlue"), M("MarkerRed")
    for bx in (-0.7, 0.0, 0.7):
        for (a, b) in (((-0.18, -0.2), (0.18, -0.2)), ((-0.18, -0.4), (0.18, -0.4)),
                       ((-0.18, -0.2), (-0.18, -0.4)), ((0.18, -0.2), (0.18, -0.4))):
            mb.beam((bx + a[0], -0.053, a[1]), (bx + b[0], -0.053, b[1]), 0.012, 0.002, blue)
        mb.beam((bx - 0.12, -0.053, -0.27), (bx + 0.1, -0.053, -0.27), 0.008, 0.002, M("TextGrey"))
        mb.beam((bx - 0.12, -0.053, -0.33), (bx + 0.05, -0.053, -0.33), 0.008, 0.002, M("TextGrey"))
    for bx in (-0.35, 0.35):
        mb.beam((bx - 0.12, -0.053, -0.3), (bx + 0.12, -0.053, -0.3), 0.012, 0.002, red)
        mb.beam((bx + 0.12, -0.053, -0.3), (bx + 0.08, -0.053, -0.27), 0.012, 0.002, red)
        mb.beam((bx + 0.12, -0.053, -0.3), (bx + 0.08, -0.053, -0.33), 0.012, 0.002, red)
    mb.beam((-0.55, -0.053, 0.0), (0.55, -0.053, 0.0), 0.01, 0.002, red)


def light_switch(mb):
    mb.box((0.08, 0.008, 0.12), (0, -0.004, 0), M("PlasticWhite"), bevel=0.002)
    for x in (-0.017, 0.017):
        mb.box((0.026, 0.008, 0.06), (x, -0.009, 0), M("PlasticBeige"), rot=(6, 0, 0), bevel=0.002)


def wall_outlet(mb):
    mb.box((0.08, 0.008, 0.12), (0, -0.004, 0), M("PlasticWhite"), bevel=0.002)
    for z in (-0.028, 0.028):
        mb.box((0.05, 0.004, 0.04), (0, -0.009, z), M("PlasticBeige"), bevel=0.003)
        for x in (-0.009, 0.009):
            mb.box((0.004, 0.003, 0.014), (x, -0.0112, z), M("PlasticBlack"))


def window(coll, name):
    # Faux window unit on the wall surface: 2.0 x 1.4 opening, origin = centre of its back face.
    root = make_obj(name, None, coll)
    W, H = 2.0, 1.4
    fr = MB()
    fm = M("FrameDark")
    fr.box((W + 0.12, 0.08, 0.06), (0, -0.04, H / 2 + 0.03), fm, bevel=0.004)
    fr.box((W + 0.12, 0.08, 0.06), (0, -0.04, -H / 2 - 0.03), fm, bevel=0.004)
    for sx in (-1, 1):
        fr.box((0.06, 0.08, H), (sx * (W / 2 + 0.03), -0.04, 0), fm, bevel=0.004)
    fr.box((0.05, 0.06, H), (0, -0.035, 0), fm)
    fr.box((W, 0.04, 0.035), (0, -0.03, -0.12), fm)
    fr.box((W + 0.24, 0.16, 0.04), (0, -0.08, -H / 2 - 0.08), M("Sill"), bevel=0.006)
    make_obj("WindowFrame", fr, coll, root)

    day = MB()
    y0 = -0.004

    def band(z0, z1, mat, y):
        day.box((W, 0.002, z1 - z0), (0, y, (z0 + z1) / 2), M(mat))
    band(0.15, H / 2, "SkyTop", y0)
    band(-0.2, 0.15, "SkyHorizon", y0)
    # Mt. Matutum: broad volcano with a flattish summit.
    mtn = [(-0.95, -0.2), (-0.62, -0.06), (-0.42, 0.18), (-0.33, 0.33), (-0.26, 0.34), (-0.16, 0.2),
           (0.05, -0.02), (0.35, -0.2)]
    day.poly([(x, z, y0 - 0.002) for x, z in mtn], M("MountainFar"), depth=0.001)
    ridge = [(-0.3, 0.33), (-0.2, 0.18), (-0.26, 0.05), (-0.36, 0.2)]
    day.poly([(x, z, y0 - 0.003) for x, z in ridge], M("Mountain"), depth=0.001)
    hills = [(0.2, -0.2), (0.45, -0.08), (0.7, -0.12), (0.95, -0.05), (1.0, -0.2)]
    day.poly([(x, z, y0 - 0.003) for x, z in hills], M("Mountain"), depth=0.001)
    day.box((W, 0.002, 0.26), (0, y0 - 0.004, -0.33), M("Sea"))
    for i in range(6):
        x = -0.8 + i * 0.31
        day.box((0.14, 0.002, 0.008), (x, y0 - 0.005, -0.28 - (i % 3) * 0.05), M("SeaLight"))
    # City rooftops and a palm in the foreground.
    rnd = random.Random(3)
    x = -W / 2
    while x < W / 2 - 0.02:
        bw = rnd.uniform(0.1, 0.22)
        bh = rnd.uniform(0.06, 0.2)
        bw = min(bw, W / 2 - x)
        day.box((bw, 0.002, bh), (x + bw / 2, y0 - 0.006, -H / 2 + bh / 2), M(rnd.choice(["CityDay", "CityDay2"])))
        x += bw
    day.box((0.02, 0.002, 0.3), (0.62, y0 - 0.008, -0.55), M("WoodDark"))
    for a in (-60, -25, 15, 50, 90):
        day.beam((0.62, y0 - 0.009, -0.4), (0.62 + 0.15 * math.cos(R(a + 90)) * -1, y0 - 0.009,
                                            -0.4 + 0.08 * math.sin(R(a + 90))), 0.04, 0.002, M("Palm"))
    make_obj("ViewDay", day, coll, root)

    night = MB()
    yn = -0.012

    def nband(z0, z1, mat, y):
        night.box((W, 0.002, z1 - z0), (0, y, (z0 + z1) / 2), M(mat))
    nband(0.0, H / 2, "NightSky", yn)
    nband(-0.25, 0.0, "NightHorizon", yn)
    night.poly([(x, z, yn - 0.002) for x, z in mtn], M("NightMountain"), depth=0.001)
    night.box((W, 0.002, 0.2), (0, yn - 0.003, -0.35), M("NightSea"))
    # Dark ground behind the skyline (tinted per mood in Godot), so the wall never shows between the roofs.
    nband(-H / 2, -0.25, "NightGround", yn - 0.001)
    rnd = random.Random(11)
    x = -W / 2
    while x < W / 2 - 0.02:
        bw = min(rnd.uniform(0.08, 0.2), W / 2 - x)
        bh = rnd.uniform(0.12, 0.42)
        night.box((bw, 0.002, bh), (x + bw / 2, yn - 0.005, -H / 2 + bh / 2), M("CityNight"))
        for wy in range(int(bh / 0.045)):
            for wx in range(int(bw / 0.035)):
                if rnd.random() < 0.45:
                    night.box((0.014, 0.002, 0.016), (x + 0.018 + wx * 0.035, yn - 0.007, -H / 2 + 0.03 + wy * 0.045),
                              M("CityLights"))
        x += bw
    for i in range(14):
        night.box((0.004, 0.002, 0.004), (-0.9 + i * 0.137, yn - 0.003, 0.25 + ((i * 37) % 9) * 0.045), M("CityLights"))
    for i in range(5):
        night.box((0.1, 0.002, 0.006), (-0.6 + i * 0.3, yn - 0.004, -0.3 - (i % 2) * 0.05), M("CityLights"))
    make_obj("ViewNight", night, coll, root)

    bl = MB()
    bl.box((W + 0.04, 0.05, 0.05), (0, -0.05, H / 2 - 0.025), M("Blinds"), bevel=0.005)
    for i in range(11):
        bl.box((W - 0.02, 0.035, 0.004), (0, -0.05, H / 2 - 0.07 - i * 0.03), M("Blinds"), rot=(35, 0, 0))
    bl.box((W - 0.01, 0.04, 0.02), (0, -0.05, H / 2 - 0.4), M("Blinds"))
    for x in (-0.6, 0.6):
        bl.box((0.003, 0.003, 0.36), (x, -0.07, H / 2 - 0.22), M("TextGrey"))
    bl.tube((0.9, -0.075, H / 2 - 0.05), (0.9, -0.075, H / 2 - 0.65), 0.002, 0.002, M("TextGrey"), seg=4)
    bl.cyl(0.008, 0.006, 0.03, (0.9, -0.075, H / 2 - 0.66), M("PlasticWhite"), seg=6)
    make_obj("Blinds", bl, coll, root)
    return root


def G(x, y, z):
    """Godot local -> Blender local."""
    return (x, -z, y)


def glass_door(coll, name):
    # Origin = Godot (DOOR_X, 0, 5): opening bottom-centre on the inner wall plane. Built in Godot coords.
    root = make_obj(name, None, coll)
    fr = MB()
    md = M("MetalDark")
    for sx in (-0.76, 0.76):
        fr.box((0.08, 0.26, 2.2), G(sx, 1.1, 0.05), md, bevel=0.004)
    fr.box((1.6, 0.26, 0.08), G(0, 2.16, 0.05), md, bevel=0.004)
    fr.box((1.6, 0.26, 0.01), G(0, 0.005, 0.05), M("Metal"))
    make_obj("DoorFrame", fr, coll, root)
    lv = MB()
    for s in (-1, 1):
        cx = s * 0.37
        zc = 0.08
        lv.box((0.04, 0.045, 2.08), G(cx - 0.33, 1.04, zc), M("Metal"))
        lv.box((0.04, 0.045, 2.08), G(cx + 0.33, 1.04, zc), M("Metal"))
        lv.box((0.7, 0.045, 0.07), G(cx, 2.045, zc), M("Metal"))
        lv.box((0.7, 0.045, 0.16), G(cx, 0.08, zc), M("Metal"))
        lv.box((0.62, 0.012, 1.85), G(cx, 1.085, zc), M("Glass"))
        lv.box((0.62, 0.014, 0.12), G(cx, 1.45, zc), M("GlassFrost"))
        hx = s * 0.08
        for zz in (zc - 0.07, zc + 0.07):
            lv.box((0.028, 0.45, 0.028), G(hx, 1.05, zz), M("Chrome"), bevel=0.006)
            for yy in (0.86, 1.24):
                lv.box((0.016, 0.016, 0.05), G(hx, yy, (zz + zc) / 2), M("Chrome"))
    make_obj("DoorLeaves", lv, coll, root)
    bd = MB()
    bd.box((2.6, 0.02, 2.6), G(0, 1.3, 1.1), M("Backdrop"))
    bd.box((2.6, 0.9, 0.02), G(0, -0.01, 0.65), M("BackdropFloor"))
    bd.box((0.5, 0.01, 0.06), G(-0.6, 2.4, 1.09), M("LightPanel"))
    make_obj("Backdrop", bd, coll, root)
    return root


def doormat(mb):
    mb.box((1.5, 0.9, 0.012), (0, 0, 0.006), M("DoorMatBorder"), bevel=0.003)
    mb.box((1.36, 0.76, 0.014), (0, 0, 0.007), M("DoorMat"))


def light_panel(coll, name):
    # Ceiling item: origin = top centre (sits flush at the ceiling, y = 3.0 in Godot).
    root = make_obj(name, None, coll)
    fr = MB()
    fr.box((1.28, 0.68, 0.03), (0, 0, -0.015), M("PanelFrame"), bevel=0.004)
    fr.box((0.012, 0.6, 0.008), (0, 0, -0.04), M("PanelFrame"))
    fr.box((1.2, 0.012, 0.008), (0, 0, -0.04), M("PanelFrame"))
    make_obj("PanelFrame", fr, coll, root)
    df = MB()
    df.box((1.2, 0.6, 0.008), (0, 0, -0.034), M("LightPanel"))
    make_obj("Diffuser", df, coll, root)
    return root


def neon_strip(matname):
    def _f(coll, name):
        root = make_obj(name, None, coll)
        b = MB()
        b.box((2.04, 0.02, 0.045), (0, -0.01, 0), M("PlasticBlack"), bevel=0.003)
        for x in (-0.8, 0.0, 0.8):
            b.box((0.03, 0.04, 0.05), (x, -0.025, 0), M("MetalDark"))
        make_obj("Channel", b, coll, root)
        t = MB()
        t.tube((-1.0, -0.035, 0), (1.0, -0.035, 0), 0.012, 0.012, M(matname), seg=8)
        make_obj("Tube", t, coll, root)
        return root
    return _f


def cubicle_divider(mb):
    # Desk-mounted back panel: origin = bottom centre, sits on the desk top at the back edge.
    mb.box((1.6, 0.035, 0.44), (0, 0, 0.22), M("FabricPanel"), bevel=0.004)
    mb.box((1.6, 0.045, 0.022), (0, 0, 0.45), M("MetalLight"), bevel=0.004)
    for sx in (-0.8, 0.8):
        mb.box((0.022, 0.045, 0.46), (sx, 0, 0.23), M("MetalLight"))
    for sx in (-0.55, 0.55):
        mb.box((0.05, 0.075, 0.02), (sx, 0.0, 0.0), M("MetalDark"))
        mb.box((0.05, 0.012, 0.07), (sx, 0.04, -0.03), M("MetalDark"))


def cubicle_divider_side(mb):
    mb.box((0.035, 0.7, 0.44), (0, 0, 0.22), M("FabricPanel"), bevel=0.004)
    mb.box((0.045, 0.7, 0.022), (0, 0, 0.45), M("MetalLight"), bevel=0.004)
    for sy in (-0.35, 0.35):
        mb.box((0.045, 0.022, 0.46), (0, sy, 0.23), M("MetalLight"))


# ------------------------------------------------------------------ decor
def stand_fan(coll, name):
    root = make_obj(name, None, coll)
    b = MB()
    b.cyl(0.19, 0.17, 0.045, (0, 0, 0.0225), M("PlasticWhite"), seg=12)
    for i, x in enumerate((-0.04, 0.0, 0.04)):
        b.box((0.025, 0.02, 0.008), (x, -0.13, 0.048), M("PlasticGrey"))
    b.cyl(0.028, 0.028, 0.6, (0, 0, 0.345), M("PlasticWhite"), seg=8)
    b.cyl(0.018, 0.018, 0.5, (0, 0, 0.85), M("Chrome"), seg=8)
    hz = 1.18
    b.box((0.05, 0.05, 0.08), (0, 0.02, 1.11), M("PlasticWhite"), bevel=0.01)
    b.sphere((0, 0.1, hz), (0.075, 0.1, 0.075), M("PlasticWhite"), u=10, v=6)
    b.cyl(0.03, 0.03, 0.04, (0, 0.21, hz), M("PlasticWhite"), seg=8, rot=(90, 0, 0))
    # Guard: rings + spokes front and back.
    for y, r in ((-0.07, 0.24), (0.03, 0.24)):
        n = 20
        for i in range(n):
            a0, a1 = 2 * PI * i / n, 2 * PI * (i + 1) / n
            b.tube((r * math.cos(a0), y, hz + r * math.sin(a0)), (r * math.cos(a1), y, hz + r * math.sin(a1)),
                   0.006, 0.006, M("PlasticWhite"), seg=4)
        for i in range(12):
            a = 2 * PI * i / 12
            b.tube((0.03 * math.cos(a), y - (0.015 if y < 0 else 0), hz + 0.03 * math.sin(a)),
                   (r * math.cos(a), y, hz + r * math.sin(a)), 0.003, 0.003, M("PlasticWhite"), seg=4)
    b.tube((0, -0.07, hz - 0.24), (0, 0.03, hz - 0.24), 0.006, 0.006, M("PlasticWhite"), seg=4)
    b.cyl(0.045, 0.045, 0.012, (0, -0.088, hz), M("Accent"), seg=10, rot=(90, 0, 0))
    make_obj("FanBody", b, coll, root)
    bl = MB()
    bl.cyl(0.04, 0.04, 0.04, (0, -0.02, hz), M("PlasticWhite"), seg=10, rot=(90, 0, 0))
    for i in range(3):
        a = 120 * i
        c = Vector((0.12 * math.cos(R(a)), -0.025, hz + 0.12 * math.sin(R(a))))
        bl.sphere(c, (0.11, 0.008, 0.06), M("FanBlade"), u=8, v=4, rot=(0, -a, 0))
    make_obj("FanBlades", bl, coll, root, pivot=(0, -0.025, hz))
    return root


def plant_floor(mb):
    rnd = random.Random(5)
    mb.loft([(0.0, .16, .16), (0.34, .2, .2), (0.36, .225, .225), (0.42, .225, .225)], M("Pot"), seg=10)
    mb.cyl(0.2, 0.2, 0.02, (0, 0, 0.41), M("Soil"), seg=10)
    mb.ico((0.0, 0.0, 0.66), (0.2, 0.2, 0.22), M("LeafDark"), sub=1)
    mb.ico((0.05, -0.03, 0.88), (0.17, 0.17, 0.18), M("Leaf"), sub=1, rot=(20, 10, 0))
    mb.ico((-0.05, 0.04, 1.06), (0.13, 0.13, 0.14), M("LeafDark"), sub=1, rot=(0, 30, 15))
    mats = [M("Leaf"), M("LeafLight"), M("Leaf")]
    for i in range(16):
        a = i * 137.5
        h = 0.55 + (i / 16.0) * 0.55
        tilt = 70 - (i / 16.0) * 45
        d = Vector((math.sin(R(tilt)) * math.cos(R(a)), math.sin(R(tilt)) * math.sin(R(a)), math.cos(R(tilt))))
        base = Vector((0, 0, h)) + Vector((d.x, d.y, 0)) * 0.08
        L = 0.12 + rnd.uniform(0, 0.08)
        lc = base + d * (L + 0.05)
        mb.tube(base, base + d * L, 0.007, 0.005, M("Stem"), seg=4)
        mb.sphere(lc, (0.07, 0.014, 0.12), mats[i % 3], u=6, v=4,
                  rot=(math.degrees(math.atan2(math.hypot(d.x, d.y), d.z)), 0, a - 90))


def plant_snake(mb):
    mb.loft([(0.0, .13, .13), (0.3, .15, .15), (0.32, .155, .155)], M("PotWhite"), seg=10)
    mb.loft([(0.06, .136, .136), (0.1, .14, .14)], M("PotBand"), seg=10)
    mb.cyl(0.14, 0.14, 0.02, (0, 0, 0.31), M("Soil"), seg=10)
    rnd = random.Random(9)
    for i in range(10):
        a = i * 137.5
        r = 0.02 + (i % 3) * 0.035
        bx, by = r * math.cos(R(a)), r * math.sin(R(a))
        h = 0.5 + rnd.uniform(0, 0.45) - (i % 3) * 0.06
        lean = (i % 3) * 7 + 3
        mat = M("SnakeLeaf") if i % 2 == 0 else M("LeafDark")
        mb.cyl(0.035, 0.0, h, (bx, by, 0.32 + h / 2), mat, seg=4, scale=(1.0, 0.3, 1.0),
               rot=(lean * math.sin(R(a)) * -1, lean * math.cos(R(a)), a))


def plant_desk(mb):
    mb.cyl(0.055, 0.065, 0.085, (0, 0, 0.0425), M("Pot"), seg=8)
    mb.cyl(0.058, 0.058, 0.008, (0, 0, 0.083), M("Soil"), seg=8)
    for i in range(7):
        a = i * 51
        mb.cyl(0.022, 0.0, 0.07, (0.018 * math.cos(R(a)), 0.018 * math.sin(R(a)), 0.115), M("LeafLight"), seg=4,
               scale=(1, 0.45, 1), rot=(30 * math.sin(R(a)) * -1, 30 * math.cos(R(a)), a))
    mb.cyl(0.02, 0.0, 0.08, (0, 0, 0.125), M("Leaf"), seg=4)


def desk_lamp(coll, name):
    root = make_obj(name, None, coll)
    mb = MB()
    mb.cyl(0.075, 0.08, 0.02, (0, 0, 0.01), M("MetalDark"), seg=12)
    mb.sphere((0, 0, 0.03), 0.018, M("MetalDark"), u=8, v=4)
    p0, p1, p2 = Vector((0, 0, 0.03)), Vector((0, 0.08, 0.3)), Vector((0, -0.12, 0.42))
    mb.tube(p0, p1, 0.011, 0.011, M("MetalDark"), seg=6)
    mb.sphere(p1, 0.016, M("MetalDark"), u=8, v=4)
    mb.tube(p1, p2, 0.01, 0.01, M("MetalDark"), seg=6)
    mb.sphere(p2, 0.016, M("MetalDark"), u=8, v=4)
    sc = p2 + Vector((0, -0.035, -0.05))
    mb.cyl(0.035, 0.09, 0.12, sc, M("LampShade"), seg=10, rot=(-25, 0, 0))
    make_obj("LampBody", mb, coll, root)
    bb = MB()
    bb.sphere(sc + Vector((0, -0.01, -0.03)), 0.028, M("LampBulb"), u=8, v=5)
    make_obj("LampBulb", bb, coll, root)
    return root


def paper_stack(mb):
    mb.box((0.24, 0.31, 0.008), (0, 0, 0.004), M("Folder"), rot=(0, 0, -4))
    for i in range(5):
        mb.box((0.21, 0.297, 0.003), (0.004 * i - 0.008, 0.003 * i, 0.0095 + i * 0.0035),
               M("Paper") if i % 2 == 0 else M("PaperBlue"), rot=(0, 0, i * 3 - 6))
    for i in range(4):
        mb.box((0.14, 0.004, 0.0005), (0.0, -0.1 + i * 0.02, 0.0265), M("TextGrey"), rot=(0, 0, 90))


def pen_cup(mb):
    mb.cyl(0.036, 0.036, 0.1, (0, 0, 0.05), M("MugBlue"), seg=10)
    mb.cyl(0.032, 0.032, 0.004, (0, 0, 0.096), M("PlasticBlack"), seg=10)
    pens = [((0.01, 0.0), (8, 4), "MarkerBlue"), ((-0.012, 0.008), (-6, 10), "MarkerRed"),
            ((0.0, -0.014), (12, -6), "MarkerBlack"), ((-0.008, -0.004), (-10, -8), "MugYellow")]
    for (x, y), (rx, ry), mat in pens:
        base = Vector((x, y, 0.03))
        tip = base + Vector((math.sin(R(ry)), -math.sin(R(rx)), 1.0)).normalized() * 0.14
        mb.tube(base, tip, 0.0055, 0.0055, M(mat), seg=6)
        mb.tube(tip, tip + (tip - base).normalized() * 0.012, 0.0055, 0.002, M("PlasticWhite") if mat != "MugYellow" else M("Book_Coral"), seg=6)


def mug(mb):
    _mug(mb, (0, 0, 0), M("MugBody"))


def photo_frame(mb):
    mb.box((0.14, 0.015, 0.11), (0, 0, 0.055), M("WoodDark"), rot=(-12, 0, 0), bevel=0.003)
    rot = (-12, 0, 0)
    f = Matrix.Rotation(R(-12), 3, 'X')
    for (w, h, cz, mat) in ((0.11, 0.045, 0.075, "PhotoSky"), (0.11, 0.035, 0.035, "PhotoSea"),
                            (0.11, 0.01, 0.02, "PhotoSand")):
        c = f @ Vector((0, -0.009, cz - 0.055)) + Vector((0, 0, 0.055))
        mb.box((w, 0.002, h), c, M(mat), rot=rot)
    for x, s in ((-0.015, 1.0), (0.012, 0.85)):
        c = f @ Vector((x, -0.0105, 0.045 - 0.055 + 0.012 * s)) + Vector((0, 0, 0.055))
        mb.box((0.012 * s, 0.002, 0.028 * s), c, M("Ink"), rot=rot)
        c2 = f @ Vector((x, -0.0105, 0.045 - 0.055 + 0.032 * s)) + Vector((0, 0, 0.055))
        mb.box((0.01 * s, 0.002, 0.01 * s), c2, M("PhotoSand"), rot=rot)
    mb.beam((0, 0.0, 0.08), (0, 0.06, 0.0), 0.02, 0.006, M("WoodDark"))


def trash_bin(mb):
    mb.loft([(0.0, .115, .115), (0.32, .14, .14)], M("PlasticGrey"), seg=10, cap1=False)
    mb.loft([(0.012, .105, .105), (0.32, .13, .13)], M("PlasticGrey"), seg=10, cap0=False, cap1=False, inward=True)
    mb.loft([(0.305, .145, .145), (0.325, .145, .145)], M("PlasticDark"), seg=10, cap0=False, cap1=False)
    mb.loft([(0.325, .145, .145), (0.3251, .128, .128)], M("PlasticDark"), seg=10, cap0=False, cap1=False)
    for i, (x, y, z) in enumerate(((0.03, 0.02, 0.06), (-0.04, -0.01, 0.07), (0.0, -0.05, 0.11))):
        mb.ico((x, y, z), 0.04, M("Paper"), sub=1, rot=(i * 40, i * 25, 0))


# ================================================================== HOME (condo) AND CAFE
# The player's smartphone is the only device in these places. Window views reuse the office view material
# names (SkyTop, SkyHorizon, NightSky, ...) and the ViewDay / ViewNight children, so the Godot mood code finds them.
def quad(mb, bl, br, tr, tl, m, uv=False):
    """One quad from four corners (bottom-left, bottom-right, top-right, top-left seen from its front)."""
    mb._start()
    f = mb.bm.faces.new([mb.bm.verts.new(Vector(p)) for p in (bl, br, tr, tl)])
    if uv:
        lay = mb.bm.loops.layers.uv.verify()
        for loop, c in zip(f.loops, ((0, 0), (1, 0), (1, 1), (0, 1))):
            loop[lay].uv = c
    mb._finish(m)


def _skyline(mb, x0, x1, zbase, hmin, hmax, y, mats, seed, lights=None, wmin=0.08, wmax=0.2, win_p=0.45):
    """Row of flat building blocks from x0 to x1 standing on zbase (optional lit windows in `lights`)."""
    rnd = random.Random(seed)
    x = x0
    while x < x1 - 0.02:
        bw = min(rnd.uniform(wmin, wmax), x1 - x)
        bh = rnd.uniform(hmin, hmax)
        mb.box((bw, 0.002, bh), (x + bw / 2, y, zbase + bh / 2), M(rnd.choice(mats)))
        if lights:
            for wy in range(int(bh / 0.045)):
                for wx in range(int(bw / 0.035)):
                    if rnd.random() < win_p:
                        mb.box((0.014, 0.002, 0.016), (x + 0.018 + wx * 0.035, y - 0.002, zbase + 0.03 + wy * 0.045),
                               M(lights))
        x += bw


def _palm(mb, x, zbase, h, y, trunk="WoodDark", leaf="Palm"):
    mb.box((0.02, 0.002, h), (x, y, zbase + h / 2), M(trunk))
    top = zbase + h
    for a in (-60, -25, 15, 50, 90, 130):
        mb.beam((x, y - 0.001, top), (x - 0.15 * math.cos(R(a + 90)), y - 0.001, top + 0.08 * math.sin(R(a + 90)) - 0.03),
                0.04, 0.002, M(leaf))


def sofa(mb):
    # Three-seater, seat top 0.44 m, backrest at the back (+Y), front -Y.
    fab, leg = M("SofaFabric"), M("WoodDark")
    for sx in (-0.8, 0.8):
        for sy in (-0.33, 0.33):
            mb.cyl(0.025, 0.018, 0.08, (sx, sy, 0.04), leg, seg=6)
    mb.box((1.8, 0.85, 0.2), (0, 0, 0.18), fab, bevel=0.02)
    for sx in (-0.82, 0.82):
        mb.box((0.16, 0.85, 0.36), (sx, 0, 0.44), fab, bevel=0.035)
    for sx in (-0.37, 0.37):
        mb.box((0.73, 0.64, 0.16), (sx, -0.09, 0.36), fab, bevel=0.03)
        mb.box((0.71, 0.18, 0.44), (sx, 0.25, 0.6), fab, rot=(-9, 0, 0), bevel=0.04)
    mb.box((1.8, 0.16, 0.5), (0, 0.345, 0.53), fab, bevel=0.03)
    mb.box((0.36, 0.13, 0.34), (-0.56, 0.13, 0.6), M("Pillow"), rot=(-12, 0, 12), bevel=0.05)
    mb.box((0.34, 0.12, 0.32), (0.58, 0.14, 0.59), M("MugYellow"), rot=(-12, 0, -10), bevel=0.05)
    mb.box((0.5, 0.6, 0.03), (0.48, -0.08, 0.455), M("Blanket"), rot=(0, 0, 8), bevel=0.01)


def coffee_table(mb):
    mb.box((0.9, 0.5, 0.03), (0, 0, 0.405), M("Wood"), bevel=0.006)
    for sx in (-0.41, 0.41):
        for sy in (-0.21, 0.21):
            mb.box((0.04, 0.04, 0.39), (sx, sy, 0.195), M("WoodDark"))
    mb.box((0.82, 0.42, 0.02), (0, 0, 0.12), M("WoodLight"))
    mb.box((0.22, 0.28, 0.012), (-0.18, 0.0, 0.136), M("PaperBlue"), rot=(0, 0, 8))
    mb.box((0.2, 0.26, 0.01), (-0.16, 0.02, 0.147), M("Book_Coral"), rot=(0, 0, -5))
    mb.box((0.045, 0.16, 0.016), (0.22, 0.06, 0.428), M("PlasticBlack"), rot=(0, 0, 20), bevel=0.004)
    _mug(mb, (-0.26, -0.06, 0.42), M("MugBlue"))
    mb.cyl(0.11, 0.11, 0.01, (0.1, -0.1, 0.425), M("WoodDark"), seg=10)


def bed_single(mb):
    # Head at the back (+Y). Mattress top 0.53 m.
    for sx in (-0.47, 0.47):
        for sy in (-0.97, 0.97):
            mb.box((0.05, 0.05, 0.1), (sx, sy, 0.05), M("WoodDark"))
    mb.box((1.0, 2.0, 0.25), (0, 0, 0.2), M("WoodLight"), bevel=0.01)
    mb.box((0.94, 1.94, 0.2), (0, 0, 0.425), M("BedSheet"), bevel=0.03)
    mb.box((1.04, 0.06, 0.9), (0, 1.0, 0.45), M("WoodDark"), bevel=0.01)
    mb.box((0.6, 0.34, 0.12), (0, 0.74, 0.58), M("Pillow"), bevel=0.045)
    mb.box((0.98, 1.3, 0.04), (0, -0.3, 0.54), M("Blanket"), bevel=0.012)
    mb.box((0.98, 0.18, 0.05), (0, 0.38, 0.545), M("BedSheet"), bevel=0.015)
    for sx in (-0.5, 0.5):
        mb.box((0.02, 1.3, 0.24), (sx, -0.3, 0.43), M("Blanket"))


def kitchenette(mb):
    # 1.8 m counter (top 0.92 m) with a sink, a two-burner hob, tiles and upper cabinets. Back at +Y.
    cab, hd = M("CabinetWhite"), M("Steel")
    mb.box((1.76, 0.5, 0.08), (0, 0.02, 0.04), M("PlasticDark"))
    mb.box((1.8, 0.58, 0.8), (0, 0, 0.48), cab, bevel=0.004)
    for i in range(4):
        x = -0.675 + i * 0.45
        mb.box((0.43, 0.012, 0.74), (x, -0.295, 0.48), cab, bevel=0.004)
        mb.box((0.012, 0.02, 0.14), (x + (0.17 if i % 2 == 0 else -0.17), -0.305, 0.74), hd)
    mb.box((1.84, 0.62, 0.04), (0, -0.01, 0.9), M("CounterTop"), bevel=0.005)
    # Sink and tap.
    mb.box((0.5, 0.38, 0.006), (-0.45, -0.02, 0.921), hd)
    mb.box((0.42, 0.3, 0.002), (-0.45, -0.02, 0.9245), M("Metal"))
    mb.tube((-0.45, 0.2, 0.92), (-0.45, 0.2, 1.16), 0.012, 0.012, M("Chrome"), seg=8)
    mb.tube((-0.45, 0.2, 1.16), (-0.45, 0.06, 1.13), 0.011, 0.009, M("Chrome"), seg=8)
    mb.box((0.03, 0.06, 0.02), (-0.36, 0.2, 0.935), M("Chrome"))
    # Hob.
    mb.box((0.56, 0.44, 0.02), (0.45, -0.02, 0.93), M("PlasticBlack"), bevel=0.004)
    for bx in (0.32, 0.58):
        mb.cyl(0.08, 0.08, 0.008, (bx, -0.02, 0.944), M("Metal"), seg=12)
        mb.cyl(0.035, 0.035, 0.012, (bx, -0.02, 0.946), M("MetalDark"), seg=10)
        mb.cyl(0.015, 0.015, 0.012, (bx, -0.215, 0.95), M("PlasticGrey"), seg=8)
    # Cutting board and a plate rack.
    mb.box((0.3, 0.22, 0.015), (0.0, -0.08, 0.9275), M("WoodLight"), rot=(0, 0, -6), bevel=0.003)
    for i in range(3):
        mb.cyl(0.095, 0.095, 0.01, (-0.06 + i * 0.03, 0.18, 1.02), M("CupWhite"), seg=12, rot=(0, 90, 0))
    mb.box((0.14, 0.14, 0.02), (-0.03, 0.18, 0.93), M("MetalLight"))
    # Tiled splashback and upper cabinets with a range hood.
    mb.box((1.8, 0.02, 0.6), (0, 0.29, 1.22), M("TileKitchen"))
    for z in (1.07, 1.22, 1.37):
        mb.box((1.8, 0.004, 0.006), (0, 0.278, z), M("TextGrey"))
    for i in range(12):
        mb.box((0.006, 0.004, 0.6), (-0.75 + i * 0.15, 0.278, 1.22), M("TextGrey"))
    mb.box((1.8, 0.34, 0.6), (0, 0.13, 1.86), cab, bevel=0.004)
    for i in range(4):
        x = -0.675 + i * 0.45
        mb.box((0.43, 0.012, 0.56), (x, -0.045, 1.86), cab, bevel=0.004)
        mb.box((0.12, 0.02, 0.012), (x, -0.056, 1.6), hd)
    mb.box((0.6, 0.34, 0.08), (0.45, 0.13, 1.52), hd, bevel=0.006)


def mini_fridge(mb):
    mb.box((0.5, 0.55, 0.85), (0, 0, 0.445), M("PlasticWhite"), bevel=0.015)
    for sx in (-0.2, 0.2):
        for sy in (-0.22, 0.22):
            mb.box((0.04, 0.04, 0.02), (sx, sy, 0.01), M("PlasticDark"))
    mb.box((0.48, 0.004, 0.006), (0, -0.277, 0.64), M("PlasticGrey"))
    mb.box((0.02, 0.03, 0.2), (0.2, -0.29, 0.45), M("Metal"), bevel=0.004)
    mb.box((0.02, 0.03, 0.1), (0.2, -0.29, 0.74), M("Metal"), bevel=0.004)
    mb.box((0.08, 0.002, 0.1), (-0.1, -0.277, 0.5), M("NoteYellow"), rot=(0, 5, 0))
    mb.box((0.06, 0.002, 0.07), (-0.02, -0.277, 0.36), M("NoteBlue"), rot=(0, -4, 0))
    mb.sphere((-0.1, -0.28, 0.545), 0.008, M("PinRed"), u=6, v=4)
    # A fruit bowl on top.
    mb.cyl(0.06, 0.12, 0.05, (0.0, 0.02, 0.895), M("WoodLight"), seg=10)
    for i, mat in enumerate(("MugYellow", "Leaf", "TapRed")):
        mb.sphere((-0.04 + i * 0.04, 0.02 + (i % 2) * 0.03, 0.93), 0.03, M(mat), u=8, v=5)


def rice_cooker(mb):
    mb.loft([(0.0, .11, .11), (0.03, .125, .125), (0.16, .13, .13), (0.19, .12, .12)], M("PlasticWhite"), seg=12)
    mb.loft([(0.19, .118, .118), (0.22, .1, .1), (0.235, .06, .06), (0.242, .02, .02)], M("PlasticWhite"), seg=12)
    mb.cyl(0.018, 0.018, 0.015, (0.03, 0.0, 0.24), M("Steel"), seg=8)
    mb.box((0.17, 0.025, 0.02), (0, 0.04, 0.245), M("PlasticGrey"), bevel=0.006)
    mb.box((0.09, 0.012, 0.055), (0, -0.126, 0.1), M("PlasticDark"), bevel=0.004)
    mb.box((0.012, 0.004, 0.01), (-0.025, -0.133, 0.115), M("PowerLED"))
    mb.box((0.012, 0.004, 0.01), (0.02, -0.133, 0.085), M("TapRed"))


def tv_console(coll, name):
    root = make_obj(name, None, coll)
    mb = MB()
    for sx in (-0.65, 0.65):
        mb.box((0.04, 0.3, 0.06), (sx, 0, 0.03), M("MetalDark"))
    mb.box((1.4, 0.4, 0.4), (0, 0, 0.26), M("WoodDark"), bevel=0.006)
    for i in range(3):
        x = -0.46 + i * 0.46
        mb.box((0.44, 0.012, 0.34), (x, -0.205, 0.26), M("Wood"), bevel=0.004)
        mb.box((0.1, 0.02, 0.012), (x, -0.215, 0.37), M("Metal"))
    mb.box((0.24, 0.16, 0.05), (0.45, 0.0, 0.485), M("PlasticBlack"), bevel=0.004)
    mb.box((0.012, 0.004, 0.006), (0.4, -0.081, 0.49), M("PowerLED"))
    mb.cyl(0.05, 0.06, 0.12, (-0.5, 0.05, 0.52), M("PotWhite"), seg=8)
    mb.ico((-0.5, 0.05, 0.64), (0.09, 0.09, 0.1), M("LeafDark"), sub=1)
    make_obj("ConsoleBody", mb, coll, root)
    tv = MB()
    tv.box((0.32, 0.2, 0.015), (0, 0.02, 0.4675), M("PlasticBlack"), bevel=0.004)
    tv.box((0.06, 0.04, 0.12), (0, 0.04, 0.53), M("PlasticBlack"))
    tv.box((1.0, 0.04, 0.6), (0, 0.0, 0.88), M("PlasticBlack"), bevel=0.004)
    tv.box((0.5, 0.05, 0.3), (0, 0.03, 0.88), M("PlasticDark"), bevel=0.01)
    make_obj("TVBody", tv, coll, root)
    sc = MB()
    sc.quad_y(0.96, 0.54, (0, -0.0205, 0.88), M("Screen"), uv=True)
    make_obj("Screen", sc, coll, root)
    return root


def dining_table_small(mb):
    # Top 0.8 x 0.8, surface at 0.75 m.
    mb.box((0.8, 0.8, 0.035), (0, 0, 0.7325), M("Wood"), bevel=0.006)
    mb.box((0.7, 0.7, 0.08), (0, 0, 0.675), M("WoodDark"))
    for sx in (-0.34, 0.34):
        for sy in (-0.34, 0.34):
            mb.box((0.045, 0.045, 0.7), (sx, sy, 0.35), M("WoodDark"))
    mb.box((0.36, 0.24, 0.003), (0.0, 0.2, 0.7515), M("Rug"))
    mb.cyl(0.035, 0.045, 0.14, (0.08, 0.22, 0.82), M("PotWhite"), seg=8)
    for i in range(3):
        a = R(i * 120)
        tip = Vector((0.08 + 0.05 * math.cos(a), 0.22 + 0.05 * math.sin(a), 0.98))
        mb.tube((0.08, 0.22, 0.88), tip, 0.003, 0.003, M("Stem"), seg=4)
        mb.sphere(tip, 0.02, M(("NotePink", "NoteYellow", "PotWhite")[i]), u=6, v=4)


def dining_chair(mb):
    # Seat top 0.47 m; backrest toward Blender -Y (Godot +Z) like the office chair: the sitter faces +Y.
    mb.box((0.42, 0.42, 0.04), (0, 0, 0.43), M("Wood"), bevel=0.005)
    mb.box((0.38, 0.38, 0.02), (0, 0.01, 0.46), M("SofaFabric"), bevel=0.006)
    for sx in (-0.18, 0.18):
        for sy in (-0.18, 0.18):
            mb.box((0.035, 0.035, 0.41), (sx, sy, 0.205), M("WoodDark"))
        mb.box((0.035, 0.035, 0.5), (sx, -0.19, 0.66), M("WoodDark"), rot=(6, 0, 0))
        mb.box((0.03, 0.36, 0.025), (sx, 0, 0.12), M("WoodDark"))
    mb.box((0.42, 0.03, 0.09), (0, -0.215, 0.87), M("Wood"), rot=(6, 0, 0), bevel=0.006)
    for x in (-0.09, 0.0, 0.09):
        mb.box((0.04, 0.02, 0.3), (x, -0.2, 0.68), M("Wood"), rot=(6, 0, 0))


def floor_lamp(coll, name):
    root = make_obj(name, None, coll)
    mb = MB()
    mb.cyl(0.14, 0.15, 0.025, (0, 0, 0.0125), M("MetalDark"), seg=12)
    mb.cyl(0.012, 0.012, 1.42, (0, 0, 0.735), M("Metal"), seg=6)
    rings = [(1.36, .2, .2), (1.64, .13, .13)]
    mb.loft(rings, M("Pillow"), seg=12, cap0=False, cap1=False)
    mb.loft([(1.36, .195, .195), (1.64, .125, .125)], M("LampShade"), seg=12, cap0=False, cap1=False, inward=True)
    mb.cyl(0.02, 0.02, 0.04, (0, 0, 1.43), M("PlasticGrey"), seg=8)
    make_obj("LampBody", mb, coll, root)
    bb = MB()
    bb.sphere((0, 0, 1.48), 0.045, M("LampBulb"), u=8, v=5)
    make_obj("LampBulb", bb, coll, root)
    return root


def ceiling_lamp_round(coll, name):
    # Flush round ceiling lamp: origin = top centre.
    root = make_obj(name, None, coll)
    fr = MB()
    fr.cyl(0.23, 0.23, 0.03, (0, 0, -0.015), M("PanelFrame"), seg=16)
    make_obj("LampFrame", fr, coll, root)
    df = MB()
    df.sphere((0, 0, -0.03), (0.21, 0.21, 0.065), M("LightPanel"), u=16, v=6)
    make_obj("Diffuser", df, coll, root)
    return root


def condo_window(coll, name):
    # Sliding balcony door 1.8 x 2.1, origin = centre of its back face. The view: a GenSan skyline with
    # Mt. Matutum behind it (ViewDay / ViewNight), the balcony railing in front, curtains at the sides.
    root = make_obj(name, None, coll)
    W, H = 1.8, 2.1
    hz = H / 2
    fr = MB()
    fm = M("FrameDark")
    fr.box((W + 0.1, 0.09, 0.05), (0, -0.045, hz + 0.025), fm, bevel=0.004)
    fr.box((W + 0.1, 0.1, 0.04), (0, -0.05, -hz - 0.02), M("Metal"), bevel=0.004)
    for sx in (-1, 1):
        fr.box((0.05, 0.09, H), (sx * (W / 2 + 0.025), -0.045, 0), fm, bevel=0.004)
    for x in (-0.025, 0.025):
        fr.box((0.04, 0.06 + abs(x), H), (x, -0.04 - abs(x), 0), fm)
    fr.box((0.02, 0.03, 0.16), (0.09, -0.085, -0.02), M("Chrome"), bevel=0.004)
    fr.box((0.02, 0.03, 0.16), (-0.09, -0.065, -0.02), M("Chrome"), bevel=0.004)
    # Balcony railing (between the glass and the view).
    rl = M("MetalDark")
    fr.box((W, 0.03, 0.04), (0, -0.02, -0.06), rl)
    fr.box((W, 0.02, 0.02), (0, -0.02, -hz + 0.1), rl)
    for i in range(15):
        fr.box((0.015, 0.015, 0.92), (-W / 2 + 0.06 + i * 0.12, -0.02, -0.55), rl)
    # Curtains and rod.
    fr.tube((-W / 2 - 0.3, -0.13, hz + 0.1), (W / 2 + 0.3, -0.13, hz + 0.1), 0.012, 0.012, M("Chrome"), seg=6)
    for sx in (-1, 1):
        for k in range(4):
            x = sx * (W / 2 + 0.02 + k * 0.075)
            fr.box((0.08, 0.03, H + 0.12), (x, -0.12 + (k % 2) * 0.02, 0.02), M("Curtain"), rot=(0, 0, sx * (25 if k % 2 else -25)))
    make_obj("WindowFrame", fr, coll, root)

    day = MB()
    y0 = -0.004
    day.box((W, 0.002, hz - 0.35), (0, y0, (hz + 0.35) / 2), M("SkyTop"))
    day.box((W, 0.002, 0.5), (0, y0, 0.1), M("SkyHorizon"))
    mtn = [(-0.9, -0.3), (-0.6, -0.05), (-0.38, 0.3), (-0.28, 0.48), (-0.2, 0.5), (-0.08, 0.32), (0.2, 0.02), (0.6, -0.3)]
    day.poly([(x, z, y0 - 0.002) for x, z in mtn], M("MountainFar"), depth=0.001)
    day.poly([(x, z, y0 - 0.003) for x, z in [(-0.24, 0.49), (-0.12, 0.3), (-0.2, 0.14), (-0.32, 0.32)]], M("Mountain"), depth=0.001)
    day.poly([(x, z, y0 - 0.003) for x, z in [(0.3, -0.3), (0.55, -0.12), (0.75, -0.18), (0.9, -0.1), (0.9, -0.3)]], M("Mountain"), depth=0.001)
    day.box((W, 0.002, hz - 0.3), (0, y0 - 0.004, -hz + (hz - 0.3) / 2), M("CityDay2"))
    _skyline(day, -W / 2, W / 2, -hz + 0.3, 0.2, 0.75, y0 - 0.006, ["CityDay", "CityDay2"], 21, wmin=0.1, wmax=0.24)
    _palm(day, 0.62, -hz + 0.2, 0.6, y0 - 0.009)
    _palm(day, -0.7, -hz + 0.2, 0.45, y0 - 0.009)
    make_obj("ViewDay", day, coll, root)

    night = MB()
    yn = -0.012
    night.box((W, 0.002, hz - 0.1), (0, yn, (hz + 0.1) / 2), M("NightSky"))
    night.box((W, 0.002, 0.4), (0, yn, -0.1), M("NightHorizon"))
    night.poly([(x, z, yn - 0.002) for x, z in mtn], M("NightMountain"), depth=0.001)
    night.box((W, 0.002, 0.75), (0, yn - 0.001, -hz + 0.375), M("NightGround"))
    _skyline(night, -W / 2, W / 2, -hz + 0.3, 0.2, 0.8, yn - 0.005, ["CityNight"], 23, lights="CityLights")
    for i in range(12):
        night.box((0.004, 0.002, 0.004), (-0.8 + i * 0.14, yn - 0.003, 0.45 + ((i * 37) % 9) * 0.06), M("CityLights"))
    make_obj("ViewNight", night, coll, root)
    return root


def condo_door(mb):
    # Unit entrance door on the wall plane (front -Y into the room); origin = bottom centre.
    for sx in (-0.48, 0.48):
        mb.box((0.06, 0.1, 2.1), (sx, -0.03, 1.05), M("WoodLight"), bevel=0.004)
    mb.box((1.02, 0.1, 0.06), (0, -0.03, 2.13), M("WoodLight"), bevel=0.004)
    mb.box((0.9, 0.045, 2.08), (0, -0.025, 1.04), M("WoodDark"), bevel=0.004)
    for z in (0.55, 1.45):
        for sx in (-0.2, 0.2):
            mb.box((0.3, 0.012, 0.62), (sx, -0.052, z), M("Wood"), bevel=0.006)
    mb.cyl(0.03, 0.03, 0.01, (0.36, -0.052, 1.0), M("Chrome"), seg=10, rot=(90, 0, 0))
    mb.sphere((0.36, -0.075, 1.0), 0.026, M("Chrome"), u=8, v=5)
    mb.cyl(0.018, 0.018, 0.02, (0.36, -0.055, 1.15), M("Chrome"), seg=8, rot=(90, 0, 0))
    mb.cyl(0.008, 0.008, 0.012, (0, -0.052, 1.55), M("Chrome"), seg=8, rot=(90, 0, 0))
    mb.box((0.14, 0.006, 0.06), (0, -0.05, 1.78), M("Bell"))


def wall_shelf(mb):
    mb.box((0.8, 0.22, 0.025), (0, -0.11, 0), M("WoodLight"), bevel=0.004)
    for sx in (-0.3, 0.3):
        mb.box((0.02, 0.18, 0.02), (sx, -0.09, -0.0225), M("MetalDark"))
        mb.box((0.02, 0.02, 0.12), (sx, -0.01, -0.07), M("MetalDark"))
    x = -0.36
    for i, mat in enumerate(("Book_Navy", "Book_Gold", "Book_Coral", "Book_Green", "Book_Cream")):
        bw, bh = 0.03 + (i % 2) * 0.01, 0.2 + (i % 3) * 0.025
        mb.box((bw, 0.15, bh), (x + bw / 2, -0.1, 0.0125 + bh / 2), M(mat))
        x += bw + 0.003
    mb.box((0.03, 0.15, 0.2), (x + 0.04, -0.1, 0.1), M("Book_Blue"), rot=(0, 20, 0))
    mb.cyl(0.05, 0.06, 0.09, (0.08, -0.11, 0.0575), M("Pot"), seg=8)
    mb.ico((0.08, -0.11, 0.14), (0.07, 0.07, 0.06), M("LeafLight"), sub=1)
    mb.box((0.16, 0.015, 0.12), (0.28, -0.08, 0.075), M("WoodDark"), rot=(-8, 0, -6), bevel=0.003)
    mb.box((0.13, 0.002, 0.09), (0.28, -0.089, 0.076), M("PhotoSky"), rot=(-8, 0, -6))


def smartphone(coll, name):
    # The player's phone lying flat, screen up: 0.075 x 0.155 x ~0.012, top of the screen toward +Y (away from
    # the player, who stands at its -Y / Godot +Z side). Screen is a uv quad facing up.
    root = make_obj(name, None, coll)
    mb = MB()
    mb.box((0.03, 0.03, 0.0015), (-0.018, 0.05, 0.00075), M("PlasticBlack"), bevel=0.0005)      # camera bump
    mb.box((0.075, 0.155, 0.009), (0, 0, 0.006), M("PhoneCase"), bevel=0.003)
    mb.box((0.071, 0.151, 0.0012), (0, 0, 0.0111), M("ScreenBezel"))
    mb.cyl(0.0022, 0.0022, 0.0004, (0, 0.0705, 0.0119), M("Eye"), seg=8)
    mb.box((0.002, 0.022, 0.003), (0.0385, 0.03, 0.007), M("PlasticGrey"))
    mb.box((0.002, 0.012, 0.003), (-0.0385, 0.04, 0.007), M("PlasticGrey"))
    make_obj("PhoneBody", mb, coll, root)
    sc = MB()
    z = 0.0119
    quad(sc, (-0.033, -0.072, z), (0.033, -0.072, z), (0.033, 0.067, z), (-0.033, 0.067, z), M("Screen"), uv=True)
    make_obj("Screen", sc, coll, root)
    return root


def cafe_counter(mb):
    # 2.4 m bar, top surface 1.04 m; customers at the front (-Y), the barista behind (+Y).
    mb.box((2.36, 0.55, 0.04), (0, 0.02, 0.02), M("MetalDark"))
    mb.box((2.4, 0.6, 0.96), (0, 0, 0.52), M("CafeWood"), bevel=0.005)
    for i in range(19):
        mb.box((0.05, 0.02, 0.84), (-1.08 + i * 0.12, -0.31, 0.5), M("WoodDark"), bevel=0.004)
    mb.box((2.4, 0.012, 0.05), (0, -0.312, 0.95), M("PosterGold"))
    mb.box((2.5, 0.7, 0.04), (0, -0.02, 1.02), M("CounterTop"), bevel=0.006)
    t = 1.04
    # Glass pastry case.
    cx = -0.75
    mb.box((0.7, 0.5, 0.04), (cx, 0.0, t + 0.02), M("Metal"))
    mb.box((0.68, 0.46, 0.3), (cx, 0.0, t + 0.19), M("Glass"))
    mb.box((0.7, 0.48, 0.015), (cx, 0.0, t + 0.3475), M("MetalDark"))
    mb.box((0.66, 0.44, 0.006), (cx, 0.0, t + 0.18), M("GlassFrost"))
    for i in range(4):
        for row, y in enumerate((-0.09, 0.09)):
            px = cx - 0.24 + i * 0.16
            mb.sphere((px, y, t + 0.065), (0.045, 0.045, 0.025), M("Pastry"), u=8, v=4)
            mb.sphere((px, y, t + 0.08), (0.04, 0.04, 0.01), M("Sugar"), u=8, v=3)
            mb.sphere((px + 0.02, y, t + 0.2), (0.04, 0.03, 0.02), M("PastryDark"), u=6, v=4)
    # Cup stacks, napkins and the register.
    for i in range(3):
        for j in range(4):
            mb.cyl(0.035, 0.045, 0.09, (0.1 + i * 0.1, 0.18, t + 0.045 + j * 0.022), M("CupWhite"), seg=10)
    mb.box((0.1, 0.06, 0.1), (0.42, -0.2, t + 0.05), M("MetalLight"), bevel=0.004)
    mb.box((0.08, 0.004, 0.06), (0.42, -0.2, t + 0.11), M("Paper"))
    mb.cyl(0.06, 0.06, 0.12, (0.6, -0.22, t + 0.06), M("Glass"), seg=10)
    mb.box((0.3, 0.28, 0.08), (0.9, 0.05, t + 0.04), M("PlasticDark"), bevel=0.006)
    mb.box((0.04, 0.03, 0.14), (0.9, 0.1, t + 0.15), M("PlasticBlack"))
    mb.box((0.26, 0.02, 0.17), (0.9, 0.1, t + 0.27), M("PlasticBlack"), rot=(-15, 0, 0), bevel=0.004)
    mb.box((0.23, 0.004, 0.14), (0.9, 0.112, t + 0.27), M("PrinterLCD"), rot=(-15, 0, 0))
    mb.box((0.1, 0.02, 0.06), (0.9, -0.08, t + 0.13), M("PlasticBlack"), rot=(20, 0, 0))
    mb.box((0.085, 0.004, 0.045), (0.9, -0.091, t + 0.132), M("LCD"), rot=(20, 0, 0))


def espresso_machine(mb):
    st = M("Steel")
    for sx in (-0.2, 0.2):
        for sy in (-0.14, 0.14):
            mb.cyl(0.02, 0.02, 0.04, (sx, sy, 0.02), M("Rubber"), seg=6)
    mb.box((0.52, 0.42, 0.36), (0, 0, 0.22), st, bevel=0.01)
    mb.box((0.46, 0.012, 0.12), (0, -0.212, 0.33), M("PlasticBlack"), bevel=0.003)
    mb.cyl(0.024, 0.024, 0.006, (0, -0.22, 0.33), M("ClockFace"), seg=12, rot=(90, 0, 0))
    for gx in (-0.12, 0.12):
        mb.cyl(0.035, 0.03, 0.04, (gx, -0.235, 0.255), M("Metal"), seg=10)
        mb.beam((gx, -0.25, 0.235), (gx, -0.38, 0.215), 0.025, 0.02, M("PlasticBlack"), up=(0, 0, 1), bevel=0.005)
        mb.cyl(0.03, 0.026, 0.055, (gx, -0.25, 0.085), M("CupWhite"), seg=10)
    mb.box((0.46, 0.15, 0.03), (0, -0.22, 0.055), M("MetalLight"))
    mb.tube((0.235, -0.22, 0.3), (0.235, -0.3, 0.12), 0.006, 0.005, M("Chrome"), seg=6)
    for i in range(3):
        for j in range(2):
            mb.cyl(0.03, 0.026, 0.055, (-0.14 + i * 0.14, -0.06 + j * 0.12, 0.43), M("CupWhite"), seg=10)
    mb.box((0.5, 0.4, 0.008), (0, 0, 0.404), M("MetalLight"))


def menu_board(mb):
    # Chalkboard menu: drinks and pastries with peso prices (no QR codes anywhere in the cafe).
    mb.box((1.2, 0.03, 0.82), (0, -0.015, 0), M("WoodDark"), bevel=0.006)
    mb.box((1.12, 0.006, 0.74), (0, -0.033, 0), M("Chalkboard"))
    rot = Matrix.Rotation(R(90), 4, 'X')
    ch = M("ChalkWhite")
    mb.text("MENU", 0.1, ch, Matrix.Translation((0, -0.037, 0.27)) @ rot, extrude=0.001)
    items = [("Kape Barako", "₱95"), ("Iced Latte", "₱140"), ("Spanish Latte", "₱150"),
             ("Ensaymada", "₱65"), ("Pandesal (3 pcs)", "₱25")]
    for i, (n, p) in enumerate(items):
        z = 0.13 - i * 0.09
        mb.text(n, 0.052, ch, Matrix.Translation((-0.5, -0.037, z)) @ rot, extrude=0.001, align="LEFT")
        mb.text(p, 0.052, M("PosterGold"), Matrix.Translation((0.5, -0.037, z)) @ rot, extrude=0.001, align="RIGHT")
    mb.beam((-0.3, -0.037, 0.21), (0.3, -0.037, 0.21), 0.006, 0.002, ch)
    for sx in (-1, 1):
        cx = sx * 0.43
        mb.beam((cx - 0.04, -0.037, 0.3), (cx + 0.04, -0.037, 0.3), 0.006, 0.002, ch)
        mb.beam((cx - 0.04, -0.037, 0.3), (cx - 0.03, -0.037, 0.23), 0.006, 0.002, ch)
        mb.beam((cx + 0.04, -0.037, 0.3), (cx + 0.03, -0.037, 0.23), 0.006, 0.002, ch)
        mb.beam((cx - 0.03, -0.037, 0.23), (cx + 0.03, -0.037, 0.23), 0.006, 0.002, ch)


def cafe_sign(mb):
    mb.box((1.5, 0.04, 0.42), (0, -0.02, 0), M("CafeWood"), bevel=0.01)
    mb.box((1.4, 0.006, 0.34), (0, -0.043, 0), M("Ink"))
    rot = Matrix.Rotation(R(90), 4, 'X')
    mb.text("KAPE KANTO", 0.15, M("PosterGold"), Matrix.Translation((0.06, -0.047, 0.035)) @ rot, extrude=0.0015)
    mb.text("COFFEE & PASTRIES", 0.05, M("White"), Matrix.Translation((0.06, -0.047, -0.1)) @ rot, extrude=0.001)
    # A steaming cup icon on the left.
    mb.cyl(0.05, 0.04, 0.09, (-0.56, -0.06, -0.02), M("CupWhite"), seg=10)
    mb.box((0.03, 0.02, 0.04), (-0.5, -0.06, -0.015), M("CupWhite"))
    for i, x in enumerate((-0.58, -0.54)):
        mb.beam((x, -0.05, 0.04), (x + 0.01, -0.05, 0.12), 0.008, 0.002, M("White"))


def cafe_table_round(mb):
    mb.cyl(0.35, 0.35, 0.03, (0, 0, 0.735), M("CafeWood"), seg=16)
    mb.cyl(0.33, 0.33, 0.02, (0, 0, 0.71), M("WoodDark"), seg=16)
    mb.cyl(0.03, 0.03, 0.68, (0, 0, 0.37), M("MetalDark"), seg=8)
    mb.cyl(0.22, 0.24, 0.03, (0, 0, 0.015), M("MetalDark"), seg=12)


def cafe_chair(mb):
    # Seat top 0.47 m; backrest toward Blender -Y (Godot +Z): the sitter faces +Y like the office chair.
    md = M("MetalDark")
    mb.box((0.42, 0.4, 0.03), (0, 0.01, 0.455), M("CafeWood"), bevel=0.01)
    for sx in (-1, 1):
        for sy in (-1, 1):
            mb.tube((sx * 0.17, sy * 0.16, 0.44), (sx * 0.2, sy * 0.19, 0.0), 0.012, 0.012, md, seg=6)
        mb.tube((sx * 0.17, -0.17, 0.44), (sx * 0.17, -0.21, 0.86), 0.012, 0.012, md, seg=6)
    mb.box((0.4, 0.03, 0.15), (0, -0.205, 0.78), M("CafeWood"), rot=(8, 0, 0), bevel=0.008)
    mb.tube((-0.18, 0.0, 0.18), (0.18, 0.0, 0.18), 0.008, 0.008, md, seg=6)


def bar_stool(mb):
    md = M("MetalDark")
    mb.cyl(0.17, 0.17, 0.05, (0, 0, 0.725), M("CafeWood"), seg=12)
    for a in (45, 135, 225, 315):
        c, s = math.cos(R(a)), math.sin(R(a))
        mb.tube((0.1 * c, 0.1 * s, 0.7), (0.19 * c, 0.19 * s, 0.0), 0.012, 0.012, md, seg=6)
    n = 12
    for i in range(n):
        a0, a1 = 2 * PI * i / n, 2 * PI * (i + 1) / n
        r = 0.16
        mb.tube((r * math.cos(a0), r * math.sin(a0), 0.28), (r * math.cos(a1), r * math.sin(a1), 0.28), 0.008, 0.008,
                md, seg=4)


def pendant_lamp(coll, name):
    # Origin = top centre (ceiling). Shade bottom at 0.92 m below the ceiling.
    root = make_obj(name, None, coll)
    mb = MB()
    mb.cyl(0.05, 0.05, 0.02, (0, 0, -0.01), M("MetalDark"), seg=10)
    mb.tube((0, 0, -0.02), (0, 0, -0.72), 0.004, 0.004, M("PlasticBlack"), seg=4)
    mb.loft([(-0.92, .17, .17), (-0.72, .05, .05)], M("MetalDark"), seg=12, cap0=False, cap1=True)
    mb.loft([(-0.92, .165, .165), (-0.725, .045, .045)], M("PlasticWhite"), seg=12, cap0=False, cap1=False, inward=True)
    make_obj("LampBody", mb, coll, root)
    bb = MB()
    bb.sphere((0, 0, -0.82), 0.04, M("LampBulb"), u=8, v=5)
    make_obj("LampBulb", bb, coll, root)
    return root


def string_lights(mb):
    # Fairy lights in two sagging spans across 3 m of wall (origin = back-face centre, at the hooks' height).
    pts = []
    for x0 in (-1.5, 0.0):
        for i in range(13):
            t = i / 12
            x = x0 + 1.5 * t
            pts.append((x, -0.03, -0.16 * 4 * t * (1 - t)))
    for a, b in zip(pts, pts[1:]):
        if abs(a[0] - b[0]) > 1e-6:
            mb.tube(a, b, 0.003, 0.003, M("PlasticBlack"), seg=4)
    for x in (-1.5, 0.0, 1.5):
        mb.box((0.02, 0.04, 0.02), (x, -0.02, 0.0), M("Metal"))
    for i, p in enumerate(pts):
        if i % 2 == 1:
            mb.cyl(0.008, 0.008, 0.02, (p[0], p[1], p[2] - 0.015), M("PlasticBlack"), seg=6)
            mb.sphere((p[0], p[1], p[2] - 0.045), (0.022, 0.022, 0.028), M("StringBulb"), u=8, v=5)


def storefront_window(coll, name):
    # Shop window 3.2 x 2.0 (three panes and a transom), origin = centre of its back face. The view: the street
    # outside the cafe with a jeepney passing, palms and the buildings across the road (ViewDay / ViewNight).
    root = make_obj(name, None, coll)
    W, H = 3.2, 2.0
    hz = H / 2
    fr = MB()
    fm = M("MetalDark")
    fr.box((W + 0.12, 0.09, 0.06), (0, -0.045, hz + 0.03), fm, bevel=0.004)
    fr.box((W + 0.12, 0.09, 0.06), (0, -0.045, -hz - 0.03), fm, bevel=0.004)
    for sx in (-1, 1):
        fr.box((0.06, 0.09, H), (sx * (W / 2 + 0.03), -0.045, 0), fm, bevel=0.004)
    for x in (-W / 6, W / 6):
        fr.box((0.05, 0.07, H), (x, -0.035, 0), fm)
    fr.box((W, 0.07, 0.05), (0, -0.035, 0.55), fm)
    fr.box((W + 0.2, 0.22, 0.04), (0, -0.11, -hz - 0.08), M("CafeWood"), bevel=0.006)
    make_obj("WindowFrame", fr, coll, root)

    day = MB()
    y0 = -0.004
    day.box((W, 0.002, hz - 0.35), (0, y0, (hz + 0.35) / 2), M("SkyTop"))
    day.box((W, 0.002, 0.45), (0, y0, 0.125), M("SkyHorizon"))
    _skyline(day, -W / 2, W / 2, -0.2, 0.3, 0.95, y0 - 0.002, ["CityDay", "CityDay2"], 31, wmin=0.25, wmax=0.55)
    rnd = random.Random(5)
    for i in range(22):
        day.box((0.06, 0.002, 0.08), (-1.5 + rnd.random() * 3.0, y0 - 0.004, -0.05 + rnd.random() * 0.5), M("WindowDay"))
    day.box((W, 0.002, 0.08), (0, y0 - 0.005, -0.24), M("Sidewalk"))
    day.box((W, 0.002, 0.42), (0, y0 - 0.005, -0.49), M("Road"))
    for i in range(7):
        day.box((0.22, 0.002, 0.012), (-1.4 + i * 0.47, y0 - 0.006, -0.5), M("White"))
    day.box((W, 0.002, 0.3), (0, y0 - 0.005, -hz + 0.15), M("Sidewalk"))
    # Jeepney (side view) driving past.
    jx, jz = -0.45, -0.66
    day.box((0.9, 0.002, 0.2), (jx, y0 - 0.007, jz + 0.12), M("JeepneyBody"))
    day.box((0.86, 0.002, 0.03), (jx, y0 - 0.008, jz + 0.1), M("JeepneyStripe"))
    day.box((0.78, 0.002, 0.05), (jx, y0 - 0.008, jz + 0.27), M("JeepneyStripe"))
    day.box((0.8, 0.002, 0.07), (jx - 0.04, y0 - 0.008, jz + 0.19), M("JeepneyDark"))
    day.box((0.2, 0.002, 0.13), (jx + 0.52, y0 - 0.007, jz + 0.08), M("JeepneyBody"))
    day.box((0.04, 0.002, 0.18), (jx + 0.6, y0 - 0.008, jz + 0.2), M("Chrome"))
    for wx in (jx - 0.28, jx + 0.45):
        day.cyl(0.055, 0.055, 0.002, (wx, y0 - 0.009, jz + 0.02), M("JeepneyDark"), seg=10, rot=(90, 0, 0))
    for px, h in ((-1.35, 0.85), (0.55, 0.95), (1.35, 0.8)):
        _palm(day, px, -0.25, h, y0 - 0.01)
    make_obj("ViewDay", day, coll, root)

    night = MB()
    yn = -0.012
    night.box((W, 0.002, hz - 0.2), (0, yn, (hz + 0.2) / 2), M("NightSky"))
    night.box((W, 0.002, 0.45), (0, yn, -0.025), M("NightHorizon"))
    _skyline(night, -W / 2, W / 2, -0.2, 0.3, 1.0, yn - 0.002, ["CityNight"], 33, lights="CityLights",
             wmin=0.25, wmax=0.55, win_p=0.35)
    night.box((W, 0.002, 0.8), (0, yn - 0.003, -hz + 0.4), M("NightGround"))
    night.box((0.9, 0.002, 0.26), (jx + 0.07, yn - 0.005, jz + 0.15), M("CityNight"))
    night.box((0.06, 0.002, 0.04), (jx + 0.62, yn - 0.006, jz + 0.07), M("CityLights"))
    night.box((0.04, 0.002, 0.04), (jx - 0.36, yn - 0.006, jz + 0.07), M("PinRed"))
    for i in range(6):
        night.box((0.07, 0.002, 0.04), (jx - 0.3 + i * 0.13, yn - 0.006, jz + 0.2), M("CityLights"))
    for lx in (-1.0, 0.9):
        night.box((0.012, 0.002, 0.8), (lx, yn - 0.005, -0.45), M("NightMountain"))
        night.box((0.08, 0.002, 0.03), (lx, yn - 0.006, -0.05), M("CityLights"))
    for i in range(16):
        night.box((0.004, 0.002, 0.004), (-1.5 + i * 0.2, yn - 0.003, 0.55 + ((i * 37) % 9) * 0.045), M("CityLights"))
    make_obj("ViewNight", night, coll, root)
    return root


def coffee_cup_saucer(mb):
    mb.cyl(0.06, 0.075, 0.012, (0, 0, 0.006), M("CupWhite"), seg=14)
    mb.loft([(0.012, .033, .033), (0.07, .046, .046)], M("CupWhite"), seg=12)
    mb.cyl(0.042, 0.042, 0.003, (0, 0, 0.064), M("Coffee"), seg=12)
    mb.box((0.01, 0.012, 0.035), (0.058, 0, 0.044), M("CupWhite"))
    for z in (0.028, 0.06):
        mb.box((0.018, 0.012, 0.008), (0.05, 0, z), M("CupWhite"))
    mb.box((0.012, 0.09, 0.003), (0.035, -0.04, 0.0135), M("Chrome"), rot=(0, 0, 20))


def iced_coffee(mb):
    mb.cyl(0.05, 0.05, 0.006, (0, 0, 0.003), M("Cork"), seg=10)
    mb.loft([(0.006, .033, .033), (0.16, .042, .042)], M("IcedCoffee"), seg=10)
    for i in range(3):
        mb.box((0.022, 0.022, 0.022), (-0.012 + i * 0.012, (i % 2) * 0.012 - 0.006, 0.14), M("Glass"), rot=(i * 20, i * 15, i * 30))
    mb.tube((0.01, 0.0, 0.05), (0.024, -0.01, 0.215), 0.004, 0.004, M("MugBody"), seg=6)


def laptop(coll, name):
    # Open laptop: keyboard toward the user (front -Y), lid hinged at the back (+Y) and opened to 105 degrees.
    root = make_obj(name, None, coll)
    mb = MB()
    mb.box((0.32, 0.22, 0.016), (0, 0, 0.008), M("MetalLight"), bevel=0.003)
    mb.box((0.28, 0.1, 0.0015), (0, 0.035, 0.0165), M("Keys"))
    mb.box((0.09, 0.06, 0.001), (0, -0.06, 0.0162), M("PlasticGrey"))
    d = Vector((0, math.sin(R(15)), math.cos(R(15))))
    n = Vector((0, -math.cos(R(15)), math.sin(R(15))))
    c = Vector((0, 0.11, 0.016)) + d * 0.105 - n * 0.004
    mb.box((0.32, 0.008, 0.21), tuple(c), M("MetalLight"), rot=(-15, 0, 0), bevel=0.002)
    mb.box((0.04, 0.002, 0.04), tuple(c - n * 0.005), M("PlasticWhite"), rot=(-15, 0, 0))
    make_obj("LaptopBody", mb, coll, root)
    sc = MB()
    u = Vector((1, 0, 0))
    s = c + n * 0.0045
    quad(sc, s - u * 0.145 - d * 0.09, s + u * 0.145 - d * 0.09, s + u * 0.145 + d * 0.09, s - u * 0.145 + d * 0.09,
         M("Screen"), uv=True)
    make_obj("Screen", sc, coll, root)
    return root


def pastry_plate(mb):
    mb.cyl(0.07, 0.09, 0.012, (0, 0, 0.006), M("CupWhite"), seg=14)
    mb.sphere((0, 0, 0.03), (0.05, 0.05, 0.028), M("Pastry"), u=10, v=5)
    mb.sphere((0, 0, 0.05), (0.044, 0.044, 0.012), M("Sugar"), u=10, v=4)
    mb.box((0.012, 0.11, 0.003), (0.065, -0.01, 0.0135), M("Chrome"), rot=(0, 0, -10))


# ================================================================== PEOPLE
class Part:
    def __init__(self, name, parent=None, offset=(0, 0, 0)):
        self.name = name
        self.parent = parent
        self.offset = Vector(offset)
        self.rot = Matrix.Identity(3)
        self.mb = None
        self.children = []
        if parent:
            parent.children.append(self)

    def local(self):
        return Matrix.Translation(self.offset) @ self.rot.to_4x4()

    def world(self):
        return (self.parent.world() if self.parent else Matrix.Identity(4)) @ self.local()

    def wpos(self):
        return self.world().translation.copy()


def set_dir(part, d):
    """Points the part's local -Z (its length) along world direction d with minimal twist."""
    P = part.parent.world().to_3x3().normalized()
    rest = P @ Vector((0, 0, -1))
    q = rest.rotation_difference(Vector(d).normalized())
    part.rot = P.transposed() @ (q.to_matrix() @ P)


def set_frame(part, f, n, side):
    """Hand frame: fingers (-Z) along f, palm facing world direction n. side +1 = left (palm is local -X)."""
    P = part.parent.world().to_3x3().normalized()
    Zc = -Vector(f).normalized()
    Xc = -Vector(n) if side > 0 else Vector(n)
    Xc = (Xc - Xc.dot(Zc) * Zc).normalized()
    Yc = Zc.cross(Xc)
    part.rot = P.transposed() @ Matrix((Xc, Yc, Zc)).transposed()


def set_world_rot(part, Rw):
    P = part.parent.world().to_3x3().normalized()
    part.rot = P.transposed() @ Rw


def ik(up, lo, target, pole):
    a = lo.offset.length
    b = lo.children[0].offset.length if lo.children else 0.24
    S = up.wpos()
    d = Vector(target) - S
    dist = min(max(d.length, abs(a - b) + 1e-3), (a + b) * 0.995)
    u = d.normalized()
    cosA = max(-1.0, min(1.0, (a * a + dist * dist - b * b) / (2 * a * dist)))
    A = math.acos(cosA)
    v = Vector(pole)
    v = (v - v.dot(u) * u).normalized()
    E = S + u * (a * math.cos(A)) + v * (a * math.sin(A))
    T = S + u * dist
    set_dir(up, E - S)
    set_dir(lo, T - E)


def attach(part, parent, world_matrix):
    L = parent.world().inverted() @ world_matrix
    part.offset = L.translation.copy()
    part.rot = L.to_3x3().normalized()


def rings_interp(rings, z):
    rings = sorted(rings, key=lambda r: r[0])
    def full(r):
        return (r[0], r[1], r[2], r[3] if len(r) > 3 else 0.0, r[4] if len(r) > 4 else 0.0)
    rs = [full(r) for r in rings]
    if z <= rs[0][0]:
        return rs[0][1:]
    for r0, r1 in zip(rs, rs[1:]):
        if r0[0] <= z <= r1[0]:
            t = (z - r0[0]) / max(1e-9, r1[0] - r0[0])
            return tuple(r0[i] + t * (r1[i] - r0[i]) for i in range(1, 5))
    return rs[-1][1:]


def surf_y(rings, seg, z, x):
    """Front surface y of a loft (with the flat-front convention) at height z and lateral x."""
    rx, ry, cy, cx = rings_interp(rings, z)
    a0 = -PI / 2 + PI / seg
    pts = [(cx + rx * math.cos(a0 + i * 2 * PI / seg), cy + ry * math.sin(a0 + i * 2 * PI / seg)) for i in range(seg)]
    best = None
    for i in range(seg):
        (x1, y1), (x2, y2) = pts[i], pts[(i + 1) % seg]
        if (y1 + y2) / 2 >= cy:
            continue
        if min(x1, x2) - 1e-9 <= x <= max(x1, x2) + 1e-9:
            t = (x - x1) / (x2 - x1) if abs(x2 - x1) > 1e-9 else 0.0
            y = y1 + t * (y2 - y1)
            best = y if best is None else min(best, y)
    return best if best is not None else cy - ry


HEAD_RINGS = [(-0.015, .03, .028, -0.045), (0.02, .06, .07, -0.02), (0.06, .075, .088, -0.008),
              (0.1, .082, .097, 0.0), (0.14, .085, .1, 0.003), (0.18, .08, .096, 0.006),
              (0.21, .065, .08, 0.01), (0.23, .04, .05, 0.012), (0.24, .012, .015, 0.012)]
HEAD_SEG = 10


def person_mats(S):
    key = S["root"]
    mats = dict(
        skin=M("Skin_" + key, S["skin"], .7), hair=M("Hair_" + key, S["hair"], .6),
        top=M("Top_" + key, S["top"], .85), inner=M("Inner_" + key, S.get("inner", "#f2f0ea"), .8),
        pants=M("Pants_" + key, S["pants"], .85), shoes=M("Shoes_" + key, S["shoes"], .45),
        sole=M("Sole_" + key, shade(S["shoes"], 0.6) if S["shoes"] != "#151618" else "#2c2c2e", .8),
        lip=M("Lip_" + key, shade(S["skin"], 0.72), .6),
        # No lanyard (people outside the office): the colour is only used for a bun's hair tie.
        lanyard=M("Lanyard_" + key, S.get("lanyard") or S.get("tie", "#8e2f3a"), .6),
        belt=M("Belt_" + key, "#2a211c", .5), eye=M("Eye"), card=M("IDCard"), photo=M("IDPhoto"),
        button=M("Button_" + key, shade(S.get("inner", S["top"]), 0.55), .5),
        lapel=M("Lapel_" + key, shade(S["top"], 0.75), .8),
    )
    return mats


def chest_rings(fem, sw, outfit):
    if fem:
        upper = [(0.04, .13, .088), (0.13, .137, .093), (0.2, .148, .104, -0.006), (0.26, .153, .1, -0.003),
                 (0.31, .158 * sw / .92, .094), (0.35, .14, .083), (0.38, .095, .066), (0.40, .05, .045)]
    else:
        upper = [(0.04, .138, .092), (0.14, .152, .1), (0.23, .168, .106), (0.31, .176 * sw, .1),
                 (0.355, .155, .088), (0.385, .1, .068), (0.40, .05, .045)]
    if outfit in ("polo", "longsleeve", "blouse", "apron"):
        bottom = [(-0.03, .135 if not fem else .128, .09 if not fem else .086)]                                  # tucked in under the belt
    elif outfit in ("blazer", "cardigan"):
        bottom = [(-0.17, .174, .116), (-0.09, .178, .116)]            # hip-length jacket / cardigan
    else:
        bottom = [(-0.1, .176, .114), (-0.04, .162, .105)]             # untucked blouse
    return bottom + upper


def poly_cols(mb, bl, br, tr, tl, m, depth, yfun, lift, cols=6):
    """A wide decal (trapezoid bl, br, tr, tl in x, z) cut into vertical columns as well, so its middle follows a
    convex body instead of sinking into it."""
    for j in range(cols):
        t0, t1 = max(0.0, (j - 0.15) / cols), min(1.0, (j + 1.15) / cols)       # slight overlap: no seams
        def at(a, b, t):
            return (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t)
        mb.poly([at(bl, br, t0), at(bl, br, t1), at(tl, tr, t1), at(tl, tr, t0)], m, depth=depth, yfun=yfun, lift=lift)


def build_chest(S, MS, fem, sw):
    mb = MB()
    out = S["outfit"]
    rings = chest_rings(fem, sw, out)
    mb.loft(rings, MS["top"], seg=10)

    def yf(x, z):
        return surf_y(rings, 10, z, x)
    if out == "blazer":
        mb.poly([(-0.058, 0.392), (0.058, 0.392), (0.0, 0.18)], MS["inner"], depth=0.01, yfun=yf, lift=0.002)
        for s in (-1, 1):
            mb.poly([(s * 0.058, 0.394), (s * 0.085, 0.385), (s * 0.016, 0.17), (s * 0.0, 0.178)], MS["lapel"],
                    depth=0.01, yfun=yf, lift=0.004)
            mb.poly([(s * 0.06, -0.085), (s * 0.13, -0.085), (s * 0.13, -0.07), (s * 0.06, -0.07)], MS["lapel"],
                    depth=0.01, yfun=yf, lift=0.002)
        for z in (0.11, 0.03):
            mb.sphere((0, yf(0, z) - 0.004, z), 0.009, MS["button"], u=6, v=4)
        mb.poly([(-0.012, -0.17), (0.012, -0.17), (0.012, 0.17), (-0.012, 0.17)], MS["lapel"], depth=0.01,
                yfun=yf, lift=0.0015)
    elif out == "polo":
        mb.loft([(0.355, .088, .074, 0.004), (0.395, .072, .062, 0.004)], MS["top"], seg=10)
        mb.poly([(-0.016, 0.28), (0.016, 0.28), (0.016, 0.385), (-0.016, 0.385)], MS["inner"], depth=0.01, yfun=yf,
                lift=0.002)
        for z in (0.30, 0.34):
            mb.sphere((0, yf(0, z) - 0.004, z), 0.006, M("White"), u=6, v=4)
        for s in (-1, 1):
            mb.poly([(s * 0.005, 0.398), (s * 0.072, 0.398), (s * 0.04, 0.35)], MS["lapel"], depth=0.008, yfun=yf,
                    lift=0.004)
    elif out == "blouse":
        mb.poly([(-0.045, 0.398), (0.045, 0.398), (0.0, 0.32)], MS["skin"], depth=0.01, yfun=yf, lift=0.002)
    elif out == "longsleeve":
        mb.loft([(0.36, .085, .072, 0.004), (0.398, .07, .06, 0.004)], MS["inner"], seg=10)
        mb.poly([(-0.008, -0.06), (0.008, -0.06), (0.008, 0.37), (-0.008, 0.37)], MS["inner"], depth=0.01,
                yfun=yf, lift=0.0015)
        for z in (0.0, 0.09, 0.18, 0.27):
            mb.sphere((0, yf(0, z) - 0.004, z), 0.006, M("White"), u=6, v=4)
        mb.poly([(0.05, 0.22), (0.11, 0.22), (0.11, 0.29), (0.05, 0.29)], MS["inner"], depth=0.01, yfun=yf,
                lift=0.002)
        for s in (-1, 1):
            mb.poly([(s * 0.004, 0.4), (s * 0.075, 0.4), (s * 0.035, 0.345)], MS["inner"], depth=0.008, yfun=yf,
                    lift=0.004)
    elif out == "cardigan":
        mb.poly([(-0.062, 0.394), (0.062, 0.394), (0.0, 0.13)], MS["inner"], depth=0.01, yfun=yf, lift=0.002)
        mb.poly([(-0.035, 0.398), (0.035, 0.398), (0.0, 0.355)], MS["skin"], depth=0.01, yfun=yf, lift=0.003)
        mb.poly([(-0.006, -0.17), (0.006, -0.17), (0.006, 0.135), (-0.006, 0.135)], MS["lapel"], depth=0.01,
                yfun=yf, lift=0.0015)
        for z in (-0.11, -0.04, 0.03, 0.1):
            mb.sphere((0.0, yf(0.0, z) - 0.004, z), 0.008, MS["button"], u=6, v=4)
    elif out == "apron":
        # Crew-neck tee under a cafe apron: the bib on the chest and the strap round the neck.
        mb.poly([(-0.035, 0.398), (0.035, 0.398), (0.0, 0.375)], MS["skin"], depth=0.01, yfun=yf, lift=0.002)
        poly_cols(mb, (-0.088, -0.03), (0.088, -0.03), (0.074, 0.27), (-0.074, 0.27), M("Apron"), 0.01, yf, 0.003)
        for s in (-1, 1):
            mb.poly([(s * 0.074, 0.27), (s * 0.056, 0.27), (s * 0.03, 0.396), (s * 0.048, 0.396)], M("Apron"),
                    depth=0.008, yfun=yf, lift=0.003)
    if S.get("lanyard") is None:
        return mb
    # Company ID on a lanyard.
    for s in (-1, 1):
        mb.poly([(s * 0.045, 0.39), (s * 0.058, 0.39), (s * 0.016, 0.17), (s * 0.006, 0.17)], MS["lanyard"],
                depth=0.006, yfun=yf, lift=0.006)
    mb.poly([(-0.03, 0.08), (0.03, 0.08), (0.03, 0.17), (-0.03, 0.17)], MS["card"], depth=0.006, yfun=yf, lift=0.009)
    mb.poly([(-0.03, 0.15), (0.03, 0.15), (0.03, 0.17), (-0.03, 0.17)], MS["lanyard"], depth=0.006, yfun=yf,
            lift=0.0105)
    mb.poly([(-0.022, 0.1), (-0.004, 0.1), (-0.004, 0.13), (-0.022, 0.13)], MS["photo"], depth=0.006, yfun=yf,
            lift=0.0105)
    return mb


def build_hips(S, MS, fem):
    mb = MB()
    if fem:
        r = [(-0.13, .14, .092), (-0.07, .165, .103), (0.0, .163, .1), (0.06, .135, .09), (0.09, .128, .087)]
    else:
        r = [(-0.13, .135, .09), (-0.07, .155, .1), (0.0, .155, .1), (0.06, .142, .094), (0.09, .138, .092)]
    mb.loft(r, MS["pants"], seg=10)
    if S["outfit"] == "apron":
        # Apron strings round the waist and the apron hanging to above the knee, with a pocket.
        band = [(0.05, r[3][1] + 0.008, r[3][2] + 0.008), (0.085, r[4][1] + 0.008, r[4][2] + 0.008)]
        mb.loft(band, M("Apron"), seg=10)
        hy = lambda x, z: surf_y(r, 10, z, x)
        poly_cols(mb, (-0.165, -0.42), (0.165, -0.42), (0.15, 0.075), (-0.15, 0.075), M("Apron"), 0.01, hy, 0.006, cols=8)
        poly_cols(mb, (-0.1, -0.2), (0.1, -0.2), (0.1, -0.12), (-0.1, -0.12),
                  M("ApronPocket", shade(MATS["Apron"][0], 0.75), .85), 0.01, hy, 0.008)
    elif S["outfit"] in ("polo", "longsleeve", "blouse"):
        mb.loft([(0.05, r[3][1] + 0.006, r[3][2] + 0.006), (0.085, r[4][1] + 0.006, r[4][2] + 0.006)], MS["belt"], seg=10)
        yb = surf_y([(0.05, r[3][1] + 0.006, r[3][2] + 0.006), (0.085, r[4][1] + 0.006, r[4][2] + 0.006)], 10, 0.068, 0)
        mb.box((0.045, 0.01, 0.03), (0, yb - 0.003, 0.068), M("Chrome"))
    return mb


def build_head(S, MS):
    mb = MB()
    mb.loft(HEAD_RINGS, MS["skin"], seg=HEAD_SEG)

    def hy(x, z):
        return surf_y(HEAD_RINGS, HEAD_SEG, z, x)
    for s in (-1, 1):
        ex = s * 0.034
        mb.sphere((ex, hy(ex, 0.118) + 0.004, 0.118), (0.0125, 0.008, 0.0165), MS["eye"], u=8, v=5)
        bx = s * 0.037
        mb.box((0.036, 0.009, 0.009), (bx, hy(bx, 0.148) - 0.001, 0.148), MS["hair"], rot=(0, s * 7, 0))
        mb.sphere((s * 0.085, 0.004, 0.112), (0.013, 0.024, 0.032), MS["skin"], u=6, v=5)
    mb.box((0.022, 0.024, 0.04), (0, hy(0, 0.09) - 0.008, 0.09), MS["skin"], rot=(-10, 0, 0), bevel=0.005)
    mb.box((0.032, 0.006, 0.007), (0, hy(0, 0.052) + 0.0005, 0.052), MS["lip"])
    hair, st = MS["hair"], S["hair_style"]

    def hcap(center, scale, cuts):
        # Hair cap a little larger than the head (and finer), so the faceted scalp never pokes through.
        sx, sy, sz = scale
        mb.cap(center, (sx + 0.006, sy + 0.008, sz + 0.007), cuts, hair, u=16, v=10)
    if st in ("short", "sidepart"):
        hcap((0, 0.008, 0.142), (0.095, 0.11, 0.12), [((0, 0, 0.12), (0, -0.9, -1))])
        if st == "sidepart":
            mb.box((0.13, 0.075, 0.04), (0.012, -0.02, 0.247), hair, rot=(-10, 0, 6), bevel=0.016)
    elif st in ("bun", "ponytail"):
        hcap((0, 0.006, 0.138), (0.091, 0.106, 0.11), [((0, 0, 0.115), (0, -1.0, -1))])
        if st == "bun":
            mb.sphere((0, 0.122, 0.165), (0.052, 0.045, 0.05), hair, u=10, v=6)
            mb.loft([(0.0, .03, .012), (0.012, .03, .012)], MS["lanyard"], seg=8,
                    matrix=Matrix.Translation((0, 0.089, 0.165)) @ Matrix.Rotation(R(90), 4, 'X'))
        else:
            # Ponytail: a hair knot sunk into the cap, a dark scrunchie, then the tail.
            mb.sphere((0, 0.104, 0.162), (0.04, 0.034, 0.038), hair, u=10, v=6)
            mb.loft([(0.0, .03, .028), (0.016, .03, .028)], M("Scrunchie", "#8e2f3a", .7), seg=8,
                    matrix=Matrix.Translation((0, 0.128, 0.158)) @ Matrix.Rotation(R(70), 4, 'X'))
            mb.tube((0, 0.13, 0.158), (0, 0.155, 0.06), 0.03, 0.03, hair, seg=7)
            mb.tube((0, 0.155, 0.06), (0, 0.148, -0.03), 0.03, 0.008, hair, seg=7)
    elif st == "bob":
        hcap((0, 0.012, 0.13), (0.103, 0.115, 0.122),
             [((0, 0, 0.035), (0, 0, -1)), ((0, -0.065, 0.2), (0, -1, -0.35))])
    bmesh.ops.scale(mb.bm, vec=(1.07, 1.0, 0.95), verts=mb.bm.verts)
    return mb


def build_uarm(S, MS, s):
    mb = MB()
    sl = S.get("sleeve", "long")
    mb.sphere((-s * 0.008, 0, -0.008), (0.05, 0.054, 0.046), MS["top"], u=8, v=6)
    if sl == "long" or sl == "rolled":
        mb.loft([(-0.285, .041, .043), (-0.15, .048, .051), (0, .053, .056)], MS["top"], seg=8)
    else:
        mb.loft([(-0.285, .036, .038), (-0.12, .043, .046), (0, .048, .05)], MS["skin"], seg=8)
        mb.loft([(-0.14, .051, .054), (0, .056, .058)], MS["top"], seg=8)
    return mb


def build_farm(S, MS, s):
    mb = MB()
    sl = S.get("sleeve", "long")
    if sl == "long":
        mb.sphere((0, 0, 0), (0.042, 0.044, 0.042), MS["top"], u=8, v=5)
        mb.loft([(-0.215, .032, .035), (-0.12, .039, .043), (0, .042, .045)], MS["top"], seg=8)
        mb.loft([(-0.235, .033, .036), (-0.205, .034, .037)], MS["inner"] if S["outfit"] == "blazer" else MS["top"], seg=8)
    elif sl == "rolled":
        mb.sphere((0, 0, 0), (0.042, 0.044, 0.042), MS["top"], u=8, v=5)
        mb.loft([(-0.24, .028, .031), (-0.1, .036, .04), (0, .04, .042)], MS["skin"], seg=8)
        mb.loft([(-0.11, .043, .046), (-0.06, .045, .048)], MS["top"], seg=8)
        mb.loft([(-0.06, .043, .046), (0, .044, .046)], MS["top"], seg=8)
    else:
        mb.sphere((0, 0, 0), (0.038, 0.04, 0.038), MS["skin"], u=8, v=5)
        mb.loft([(-0.24, .028, .031), (-0.12, .035, .039), (0, .038, .041)], MS["skin"], seg=8)
    return mb


def build_hand(S, MS, s):
    mb = MB()
    sk = MS["skin"]
    mb.sphere((0, 0, -0.005), 0.03, sk, u=8, v=5)
    mb.box((0.03, 0.074, 0.085), (0, 0, -0.05), sk, bevel=0.008)
    mb.box((0.025, 0.068, 0.07), (-s * 0.008, 0.0, -0.118), sk, rot=(0, s * 16, 0), bevel=0.007)
    mb.box((0.022, 0.024, 0.06), (-s * 0.012, -0.04, -0.045), sk, rot=(-28, s * 14, 0), bevel=0.006)
    return mb


def build_thigh(S, MS, fem):
    mb = MB()
    mb.sphere((0, 0, 0), (0.08, 0.084, 0.08), MS["pants"], u=8, v=6)
    t = 0.006 if fem else 0.0
    mb.loft([(-0.36, .053, .056), (-0.25, .064 + t, .068 + t), (-0.1, .076 + t, .08 + t), (0, .079, .083)], MS["pants"], seg=8)
    return mb


def build_shin(S, MS):
    mb = MB()
    mb.sphere((0, 0, 0), (0.056, 0.058, 0.056), MS["pants"], u=8, v=5)
    mb.loft([(-0.375, .05, .052), (-0.2, .052, .055), (0, .055, .057)], MS["pants"], seg=8)
    return mb


def build_foot(S, MS, fem):
    mb = MB()
    w = 0.92 if fem else 1.0
    rings = [(-0.06, .036 * w, .035), (-0.035, .042 * w, .04), (0.04, .045 * w, .034), (0.12, .046 * w, .026),
             (0.17, .042 * w, .02), (0.2, .03 * w, .015)]
    rings = [(z * 0.88, rx, ry, -0.08 + ry + 0.01) for z, rx, ry in rings]
    mb.loft(rings, MS["shoes"], seg=8, matrix=Matrix.Rotation(R(90), 4, 'X'))
    mb.box((0.088 * w, 0.235, 0.014), (0, -0.062, -0.073), MS["sole"], bevel=0.004)
    return mb


def build_person(S, coll):
    k = S["H"] / 1.65
    fem = S["sex"] == "f"
    sw = 0.92 if fem else 1.0
    MS = person_mats(S)
    root = Part(S["root"])
    hips = Part("Hips", root, (0, 0, 0.88))
    hips.mb = build_hips(S, MS, fem)
    legs = {}
    for side, s in (("L", 1), ("R", -1)):
        th = Part("Thigh_" + side, hips, (s * 0.085, 0, -0.06))
        th.mb = build_thigh(S, MS, fem)
        sh = Part("Shin_" + side, th, (0, 0, -0.36))
        sh.mb = build_shin(S, MS)
        ft = Part("Foot_" + side, sh, (0, 0, -0.38))
        ft.mb = build_foot(S, MS, fem)
        legs[side] = (th, sh, ft)
    torso = Part("Torso", hips, (0, 0, 0.08))
    chest = Part("Chest", torso, (0, 0, 0))
    chest.mb = build_chest(S, MS, fem, sw)
    neck = Part("Neck", torso, (0, 0.005, 0.375))
    nm = MB()
    nm.loft([(-0.03, .045, .045), (0.08, .041, .041)], MS["skin"], seg=8)
    neck.mb = nm
    head = Part("Head", neck, (0, -0.005, 0.065))
    head.mb = build_head(S, MS)
    arms = {}
    for side, s in (("L", 1), ("R", -1)):
        ua = Part("UpperArm_" + side, torso, (s * 0.168 * sw, 0, 0.305))
        ua.mb = build_uarm(S, MS, s)
        fa = Part("Forearm_" + side, ua, (0, 0, -0.285))
        fa.mb = build_farm(S, MS, s)
        hd = Part("Hand_" + side, fa, (0, 0, -0.24))
        hd.mb = build_hand(S, MS, s)
        arms[side] = (ua, fa, hd)
    # Uniform size: scale geometry and joint offsets by k.
    def walk(p):
        yield p
        for c in p.children:
            yield from walk(c)
    for p in walk(root):
        p.offset = p.offset * k
        if p.mb:
            p.mb.scale(k)
    J = dict(root=root, hips=hips, torso=torso, chest=chest, neck=neck, head=head, legs=legs, arms=arms, k=k, MS=MS)
    POSES[S["pose"]](J, S)
    if S.get("seated"):
        # Seated people face Blender +Y (Godot -Z) so they drop into a chair with the chair's own transform.
        Rz = Matrix.Rotation(PI, 3, 'Z')
        hips.offset = Rz @ hips.offset
        hips.rot = Rz @ hips.rot
    # Objects.
    def mk(p, parent_obj):
        o = make_obj(p.name, p.mb, coll, parent_obj)
        o.matrix_basis = p.local()
        for c in p.children:
            mk(c, o)
        return o
    return mk(root, None)


# ------------------------------------------------------------------ poses
def stand_legs(J, toe_out=7, spread=0.035):
    for side, s in (("L", 1), ("R", -1)):
        th, sh, ft = J["legs"][side]
        set_dir(th, (s * spread, 0, -1))
        set_dir(sh, (s * spread * 0.3, 0.01, -1))
        set_world_rot(ft, Matrix.Rotation(R(s * toe_out), 3, 'Z'))
    fix_feet(J)


def seat_legs(J, spread=0.07, hip_y=0.03, thigh_drop=0.1, shin_fwd=0.15):
    J["hips"].offset.y = hip_y
    for side, s in (("L", 1), ("R", -1)):
        th, sh, ft = J["legs"][side]
        set_dir(th, (s * spread, -1, -thigh_drop))
        set_dir(sh, (s * 0.02, -shin_fwd, -1))
        set_world_rot(ft, Matrix.Rotation(R(s * 6), 3, 'Z'))
    fix_feet(J)


def fix_feet(J):
    lows = [J["legs"][s][2].wpos().z for s in ("L", "R")]
    J["hips"].offset.z += (0.08 * J["k"]) - min(lows) + 0.002


def relaxed_arm(J, side, fwd=0.0, bend=14, out=0.1):
    s = 1 if side == "L" else -1
    ua, fa, hd = J["arms"][side]
    set_dir(ua, (s * out, 0.04 - fwd, -1))
    a = R(bend)
    set_dir(fa, (s * out * 0.6, -math.sin(a) - fwd, -math.cos(a)))
    set_frame(hd, (s * 0.06, -math.sin(a) * 1.2 - fwd, -1), (-s, 0.15, 0), s)


def pose_clipboard(J, S):
    stand_legs(J)
    J["torso"].rot = Euler((R(-2), 0, R(4))).to_matrix()
    J["head"].rot = Euler((R(3), R(-2), R(12))).to_matrix()
    k = J["k"]
    relaxed_arm(J, "R")
    ua, fa, hd = J["arms"]["L"]
    sh = ua.wpos()
    ik(ua, fa, sh + Vector((-0.06, -0.22, -0.3)) * k, (1, 0.6, -0.4))
    set_frame(hd, (-0.55, -0.75, 0.2), (0, 0.15, 1), 1)
    W = hd.world()
    # Clipboard resting on the forearm and hand, tilted toward her.
    c = W @ Vector((-0.03, -0.02, -0.06))
    c = Vector((c.x - 0.03, c.y - 0.06, c.z + 0.11))
    Rw = Euler((R(62), 0, R(-18))).to_matrix()
    cp = Part("Clipboard", hd)
    attach(cp, hd, Matrix.Translation(c) @ Rw.to_4x4())
    mb = MB()
    mb.box((0.23, 0.31, 0.008), (0, 0, 0), M("Clipboard"), bevel=0.003)
    mb.box((0.205, 0.27, 0.003), (0, -0.012, 0.0055), M("Paper"))
    mb.box((0.09, 0.03, 0.016), (0, 0.15, 0.01), M("Metal"), bevel=0.003)
    for i in range(6):
        mb.box((0.15 - (i % 3) * 0.03, 0.006, 0.001), (-0.01, 0.09 - i * 0.035, 0.0075), M("TextGrey"))
    cp.mb = mb


def pose_typing(J, S):
    seat_legs(J)
    k = J["k"]
    J["torso"].rot = Euler((R(14), 0, 0)).to_matrix()
    J["neck"].rot = Euler((R(-6), 0, 0)).to_matrix()
    J["head"].rot = Euler((R(4), 0, R(-3))).to_matrix()
    for side, s in (("L", 1), ("R", -1)):
        ua, fa, hd = J["arms"][side]
        ik(ua, fa, Vector((s * 0.12, -0.5, 0.8)), (s * 0.8, 0.5, -1))
        set_frame(hd, (-s * 0.12, -1, -0.28), (s * 0.15, 0, -1), s)


def pose_phone(J, S):
    # Sitting upright on the front half of the seat, leaning slightly toward the desk: thighs on the seat,
    # shins near vertical. Right hand holds the handset upright against the right ear (earpiece at the ear,
    # mouthpiece by the jaw), elbow out to the side and forward; the left elbow is down by the armrest, the
    # forearm rising to the desk edge.
    seat_legs(J, spread=0.05, hip_y=0.0, thigh_drop=0.2, shin_fwd=0.03)
    k = J["k"]
    J["torso"].rot = Euler((R(9), R(-2), R(-4))).to_matrix()
    J["neck"].rot = Euler((R(2), 0, 0)).to_matrix()
    J["head"].rot = Euler((R(5), R(-10), R(-5))).to_matrix()
    H = J["head"].world()
    Hr = H.to_3x3().normalized()
    ear = H @ (Vector((-0.122, 0.006, 0.104)) * k)        # just outside the right ear
    jaw = H @ (Vector((-0.1, -0.072, -0.03)) * k)         # beside and below the jaw, clear of the mouth
    z = (ear - jaw).normalized()                          # handset axis, mouthpiece -> earpiece
    x = Hr @ Vector((1, 0, 0))                            # toward the head (she holds it on her right)
    x = (x - x.dot(z) * z).normalized()
    y = z.cross(x)
    Rw = Matrix((x, y, z)).transposed()
    L = (ear - jaw).length
    mid = (ear + jaw) / 2
    # Wrist below the handset's middle and outside it, fingers up along the handset, palm toward the cheek.
    wrist = mid - z * 0.07 - x * 0.04 + y * 0.012
    ua, fa, hd = J["arms"]["R"]
    # Elbow out to her right side and a little forward (the classic phone hold), so the forearm rises
    # beside the face instead of crossing the jaw.
    ik(ua, fa, wrist, (-0.75, -0.45, -0.5))
    set_frame(hd, z, x, -1)
    hs = Part("Handset", hd)
    attach(hs, hd, Matrix.Translation(mid) @ Rw.to_4x4())
    mb = MB()
    pb = M("PlasticBlack")
    mb.box((0.028, 0.044, L), (0, 0, 0), pb, bevel=0.007)                     # grip (thin side to the cheek)
    mb.box((0.036, 0.052, 0.05), (0.008, 0.004, L / 2), pb, bevel=0.01)      # earpiece cup, against the ear
    mb.box((0.036, 0.052, 0.05), (0.008, 0.006, -L / 2), pb, bevel=0.01)     # mouthpiece by the jaw
    hs.mb = mb
    # Free (left) arm: elbow down at her side by the armrest, bent about 70 degrees, forearm rising to the desk
    # edge (top 0.75 m, front edge 0.365 m ahead of the seat centre) with the hand resting on the desk top.
    ua, fa, hd = J["arms"]["L"]
    S = ua.wpos()
    ik(ua, fa, Vector((0.1, -0.3, 0.785)), (0.6, 0.3, -1))
    set_frame(hd, (-0.3, -1, -0.08), (0.0, 0.0, -1), 1)


def pose_papers(J, S):
    stand_legs(J, toe_out=6, spread=0.04)
    k = J["k"]
    J["torso"].rot = Euler((R(3), 0, 0)).to_matrix()
    J["neck"].rot = Euler((R(8), 0, 0)).to_matrix()
    J["head"].rot = Euler((R(16), 0, R(4))).to_matrix()
    for side, s in (("L", 1), ("R", -1)):
        ua, fa, hd = J["arms"][side]
        ik(ua, fa, Vector((s * 0.115, -0.28, 1.02)), (s * 0.9, 0.5, -1))
        set_frame(hd, (-s * 0.2, -1, 0.3), (-s, 0, 0.25), s)
    hd = J["arms"]["R"][2]
    pl = J["arms"]["L"][2].wpos()
    pr = hd.wpos()
    c = (pl + pr) / 2 + Vector((0, -0.075, 0.035))
    pp = Part("Papers", hd)
    attach(pp, hd, Matrix.Translation(c) @ Euler((R(58), 0, 0)).to_matrix().to_4x4())
    mb = MB()
    mb.box((0.215, 0.012, 0.297), (0, 0, 0), M("Paper"))
    for i in range(7):
        mb.box((0.15 - (i % 3) * 0.03, 0.001, 0.006), (-0.01, -0.0065, 0.1 - i * 0.03), M("TextGrey"))
    mb.box((0.21, 0.003, 0.29), (0.004, 0.006, -0.002), M("PaperBlue"), rot=(0, 3, 0))
    pp.mb = mb


def pose_mug(J, S):
    stand_legs(J, toe_out=8, spread=0.03)
    k = J["k"]
    J["torso"].rot = Euler((R(-1), R(2), R(-6))).to_matrix()
    J["head"].rot = Euler((R(2), R(4), R(-14))).to_matrix()
    relaxed_arm(J, "L", bend=18)
    ua, fa, hd = J["arms"]["R"]
    ik(ua, fa, Vector((-0.11, -0.26, 1.08)), (-0.9, 0.4, -1))
    set_frame(hd, (0.45, -0.75, 0.25), (0.75, -0.55, 0.0), -1)
    W = hd.world()
    palm = W @ Vector((0.015, 0.0, -0.06))
    n = W.to_3x3() @ Vector((1, 0, 0))
    c = palm + n * 0.05 + Vector((0, -0.02, 0))
    c.z -= 0.045
    mg = Part("Mug", hd)
    attach(mg, hd, Matrix.Translation(c) @ Matrix.Rotation(math.atan2(-n.y, -n.x) + PI, 4, 'Z'))
    mb = MB()
    _mug(mb, (0, 0, 0), M("MugYellow"))
    mg.mb = mb


def pose_barista(J, S):
    # Standing behind the cafe counter (top 1.04 m), both hands resting on it, leaning in a little.
    stand_legs(J, toe_out=6, spread=0.04)
    J["torso"].rot = Euler((R(5), 0, 0)).to_matrix()
    J["neck"].rot = Euler((R(4), 0, 0)).to_matrix()
    J["head"].rot = Euler((R(6), 0, R(-6))).to_matrix()
    for side, s in (("L", 1), ("R", -1)):
        ua, fa, hd = J["arms"][side]
        ik(ua, fa, Vector((s * 0.16, -0.36, 1.07)), (s * 0.9, 0.5, -1))
        set_frame(hd, (s * 0.15, -1, -0.35), (0, 0, -1), s)


def pose_phone_look(J, S):
    # Seated, both hands holding a phone in front of the chest, head bowed to read it.
    seat_legs(J)
    J["torso"].rot = Euler((R(10), 0, 0)).to_matrix()
    J["neck"].rot = Euler((R(14), 0, 0)).to_matrix()
    J["head"].rot = Euler((R(20), 0, 0)).to_matrix()
    T = J["torso"].world()
    c = T @ Vector((0, -0.3, 0.17))
    Rw = Euler((R(35), 0, 0)).to_matrix()                 # screen toward the face, top tipped away
    up = Rw @ Vector((0, 0, 1))
    for side, s in (("L", 1), ("R", -1)):
        ua, fa, hd = J["arms"][side]
        wrist = c + Vector((s * 0.065, 0.05, 0)) - up * 0.06
        ik(ua, fa, wrist, (s * 0.9, 0.4, -1))
        set_frame(hd, up + Vector((-s * 0.25, 0, 0)), (-s, 0, 0), s)
    hd = J["arms"]["R"][2]
    ph = Part("Phone", hd)
    attach(ph, hd, Matrix.Translation(c) @ Rw.to_4x4())
    mb = MB()
    mb.box((0.075, 0.009, 0.155), (0, 0, 0), M("PhoneCase"), bevel=0.003)
    mb.box((0.067, 0.002, 0.143), (0, 0.0045, 0), M("PrinterLCD"))
    ph.mb = mb


def pose_sip(J, S):
    # Seated with a mug held at the chest (between sips); the free hand rests on the table (top 0.75 m).
    seat_legs(J)
    J["torso"].rot = Euler((R(4), R(-3), R(-4))).to_matrix()
    J["head"].rot = Euler((R(2), R(3), R(-10))).to_matrix()
    ua, fa, hd = J["arms"]["R"]
    sh = ua.wpos()
    ik(ua, fa, sh + Vector((0.06, -0.26, -0.17)), (-0.9, 0.4, -1))
    set_frame(hd, (0.45, -0.75, 0.25), (0.75, -0.55, 0.0), -1)
    W = hd.world()
    palm = W @ Vector((0.015, 0.0, -0.06))
    n = W.to_3x3() @ Vector((1, 0, 0))
    c = palm + n * 0.05 + Vector((0, -0.02, 0))
    c.z -= 0.045
    mg = Part("Mug", hd)
    attach(mg, hd, Matrix.Translation(c) @ Matrix.Rotation(math.atan2(-n.y, -n.x) + PI, 4, 'Z'))
    mb = MB()
    _mug(mb, (0, 0, 0), M("CupWhite"))
    mg.mb = mb
    ua, fa, hd = J["arms"]["L"]
    ik(ua, fa, Vector((0.12, -0.42, 0.79)), (0.6, 0.3, -1))
    set_frame(hd, (-0.3, -1, -0.08), (0.0, 0.0, -1), 1)


POSES = dict(clipboard=pose_clipboard, typing=pose_typing, phone=pose_phone, papers=pose_papers, mug=pose_mug,
             barista=pose_barista, phone_look=pose_phone_look, sip=pose_sip)

PEOPLE = [
    dict(file="person_dela_vega", root="DelaVega", H=1.62, sex="f", skin="#c48a62", hair="#1c1612",
         hair_style="bun", outfit="blazer", top="#27344d", inner="#f2f0ea", pants="#2a2e36", shoes="#151618",
         lanyard="#c0392b", pose="clipboard", sleeve="long"),
    dict(file="person_coworker_typing", root="CoworkerTyping", H=1.68, sex="m", skin="#9a6440", hair="#1c1612",
         hair_style="short", outfit="polo", top="#e3b04b", inner="#c98e2a", pants="#3b3f4a", shoes="#4a3326",
         lanyard="#3fa7d6", pose="typing", seated=True, sleeve="short"),
    dict(file="person_coworker_phone", root="CoworkerPhone", H=1.56, sex="f", skin="#dcae86", hair="#241a15",
         hair_style="ponytail", outfit="blouse", top="#e07a6a", pants="#2b3550", shoes="#3a2a22",
         lanyard="#3fa7d6", pose="phone", seated=True, sleeve="short"),
    dict(file="person_coworker_printer", root="CoworkerPrinter", H=1.70, sex="m", skin="#b07650", hair="#1c1612",
         hair_style="sidepart", outfit="longsleeve", top="#9cc3e6", inner="#7fa9d0", pants="#b49a74",
         shoes="#3b2a20", lanyard="#3fa7d6", pose="papers", sleeve="rolled"),
    dict(file="person_coworker_mug", root="CoworkerMug", H=1.60, sex="f", skin="#c99a72", hair="#2e2019",
         hair_style="bob", outfit="cardigan", top="#4f8a6b", inner="#f0e6d2", pants="#26282d", shoes="#1c1d20",
         lanyard="#3fa7d6", pose="mug", sleeve="long"),
    # Cafe people (Chapters 8 and 10): no lanyard, seat 0.47 m, table 0.75 m.
    dict(file="person_barista", root="Barista", H=1.6, sex="f", skin="#b98055", hair="#1a1411",
         hair_style="ponytail", outfit="apron", top="#f2efe8", inner="#f2efe8", pants="#2a2e36", shoes="#151618",
         pose="barista", sleeve="short"),
    dict(file="person_cafe_laptop", root="CafeLaptop", H=1.7, sex="m", skin="#a86d48", hair="#16110e",
         hair_style="short", outfit="polo", top="#3f6e8c", inner="#2f5670", pants="#b9a47c", shoes="#3a2a22",
         pose="typing", seated=True, sleeve="short"),
    dict(file="person_cafe_phone", root="CafePhone", H=1.57, sex="f", skin="#d4a37c", hair="#2a1d16",
         hair_style="bob", outfit="blouse", top="#a68cc4", pants="#3a4a6a", shoes="#e9e4da",
         pose="phone_look", seated=True, sleeve="short"),
    dict(file="person_cafe_sip", root="CafeSip", H=1.69, sex="m", skin="#8d5a3a", hair="#1c1612",
         hair_style="sidepart", outfit="cardigan", top="#7a6a58", inner="#e8e2d4", pants="#2b2e36", shoes="#4a3326",
         pose="sip", seated=True, sleeve="long"),
]


# ================================================================== BUILD ALL
FLOOR, DESKTOP, WALL, CEIL = "base-centre (floor)", "base-centre (desk top)", "back-face centre (wall)", "top centre (ceiling)"
build("desk", "Desk", single(desk), FLOOR)
build("office_chair", "OfficeChair", single(office_chair), FLOOR)
build("monitor", "Monitor", monitor, DESKTOP)
build("keyboard", "Keyboard", single(keyboard), DESKTOP)
build("mouse", "Mouse", single(mouse), DESKTOP)
build("pc_tower", "PCTower", single(pc_tower), DESKTOP)
build("desk_phone", "DeskPhone", desk_phone, DESKTOP)
build("desk_lamp", "DeskLamp", desk_lamp, DESKTOP)
build("paper_stack", "PaperStack", single(paper_stack), DESKTOP)
build("pen_cup", "PenCup", single(pen_cup), DESKTOP)
build("mug", "CoffeeMug", single(mug), DESKTOP)
build("photo_frame", "PhotoFrame", single(photo_frame), DESKTOP)
build("plant_desk", "PlantDesk", single(plant_desk), DESKTOP)
build("cubicle_divider", "CubicleDivider", single(cubicle_divider), DESKTOP)
build("cubicle_divider_side", "CubicleDividerSide", single(cubicle_divider_side), DESKTOP)
build("reception_counter", "ReceptionCounter", single(reception), FLOOR)
build("filing_cabinet", "FilingCabinet", single(filing_cabinet), FLOOR)
build("bookshelf", "Bookshelf", single(bookshelf), FLOOR)
build("printer_station", "PrinterStation", single(printer_station), FLOOR)
build("pantry_counter", "PantryCounter", single(pantry_counter), FLOOR)
build("water_dispenser", "WaterDispenser", single(water_dispenser), FLOOR)
build("stand_fan", "StandFan", stand_fan, FLOOR)
build("plant_floor", "PlantFloor", single(plant_floor), FLOOR)
build("plant_snake", "PlantSnake", single(plant_snake), FLOOR)
build("trash_bin", "TrashBin", single(trash_bin), FLOOR)
build("doormat", "Doormat", single(doormat), FLOOR)
build("glass_door", "GlassDoor", glass_door, "opening bottom-centre on the inner wall plane", view="back")
build("window", "Window", window, WALL)
build("whiteboard", "Whiteboard", single(whiteboard), WALL)
build("poster_security", "PosterSecurity", single(poster), WALL)
build("cork_board", "CorkBoard", single(cork_board), WALL)
build("wall_clock", "WallClock", wall_clock, WALL)
build("aircon", "Aircon", single(aircon), WALL)
build("light_switch", "LightSwitch", single(light_switch), WALL)
build("wall_outlet", "WallOutlet", single(wall_outlet), WALL)
build("neon_strip_pink", "NeonStripPink", neon_strip("NeonPink"), WALL)
build("neon_strip_cyan", "NeonStripCyan", neon_strip("NeonCyan"), WALL)
build("light_panel", "LightPanel", light_panel, CEIL, view="below")
# Home (condo).
build("sofa", "Sofa", single(sofa), FLOOR)
build("coffee_table", "CoffeeTable", single(coffee_table), FLOOR)
build("bed_single", "BedSingle", single(bed_single), FLOOR)
build("kitchenette", "Kitchenette", single(kitchenette), FLOOR)
build("mini_fridge", "MiniFridge", single(mini_fridge), FLOOR)
build("rice_cooker", "RiceCooker", single(rice_cooker), DESKTOP)
build("tv_console", "TVConsole", tv_console, FLOOR)
build("dining_table_small", "DiningTable", single(dining_table_small), FLOOR)
build("dining_chair", "DiningChair", single(dining_chair), FLOOR)
build("floor_lamp", "FloorLamp", floor_lamp, FLOOR)
build("ceiling_lamp_round", "CeilingLampRound", ceiling_lamp_round, CEIL, view="below")
build("condo_window", "CondoWindow", condo_window, WALL)
build("condo_door", "CondoDoor", single(condo_door), FLOOR)
build("wall_shelf", "WallShelf", single(wall_shelf), WALL)
# Both places: the player's phone.
build("smartphone", "Smartphone", smartphone, DESKTOP)
# Cafe.
build("cafe_counter", "CafeCounter", single(cafe_counter), FLOOR)
build("espresso_machine", "EspressoMachine", single(espresso_machine), DESKTOP)
build("menu_board", "MenuBoard", single(menu_board), WALL)
build("cafe_sign", "CafeSign", single(cafe_sign), WALL)
build("cafe_table_round", "CafeTableRound", single(cafe_table_round), FLOOR)
build("cafe_chair", "CafeChair", single(cafe_chair), FLOOR)
build("bar_stool", "BarStool", single(bar_stool), FLOOR)
build("pendant_lamp", "PendantLamp", pendant_lamp, CEIL, view="below")
build("string_lights", "StringLights", single(string_lights), WALL)
build("storefront_window", "StorefrontWindow", storefront_window, WALL)
build("coffee_cup_saucer", "CupSaucer", single(coffee_cup_saucer), DESKTOP)
build("iced_coffee", "IcedCoffee", single(iced_coffee), DESKTOP)
build("laptop", "Laptop", laptop, DESKTOP)
build("pastry_plate", "PastryPlate", single(pastry_plate), DESKTOP)
for spec in PEOPLE:
    build(spec["file"], spec["root"], lambda coll, name, s=spec: build_person(s, coll),
          "feet on the floor, centre between the feet" if not spec.get("seated") else
          "floor point under the chair seat centre (use the chair's transform)", view="person")


# ================================================================== RENDERING
def setup_render(rx, ry, samples=24):
    for eng in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT"):
        try:
            SCENE.render.engine = eng
            break
        except TypeError:
            continue
    try:
        SCENE.eevee.taa_render_samples = samples
    except Exception:
        pass
    SCENE.render.resolution_x = rx
    SCENE.render.resolution_y = ry
    SCENE.render.resolution_percentage = 100
    SCENE.render.image_settings.file_format = 'PNG'
    SCENE.render.film_transparent = False


def set_world(hexcol, strength):
    w = SCENE.world or bpy.data.worlds.new("World")
    SCENE.world = w
    if w.node_tree is None:
        w.use_nodes = True
    bg = w.node_tree.nodes.get("Background")
    bg.inputs[0].default_value = (*lin(hexcol), 1)
    bg.inputs[1].default_value = strength


RIG = bpy.data.collections.new("RenderRig")
SCENE.collection.children.link(RIG)


def add_light(kind, name, energy, color, loc=(0, 0, 0), rot=(0, 0, 0), size=1.0):
    l = bpy.data.lights.new(name, kind)
    l.energy = energy
    l.color = lin(color)
    if kind == 'AREA':
        l.size = size
    if kind == 'SUN':
        l.angle = R(8)
    o = bpy.data.objects.new(name, l)
    o.location = loc
    o.rotation_euler = [R(a) for a in rot]
    RIG.objects.link(o)
    return o


def look_rot(cam_pos, target):
    d = Vector(target) - Vector(cam_pos)
    return d.to_track_quat('-Z', 'Y').to_euler()


def load_px(path):
    import numpy as np
    img = bpy.data.images.load(path)
    w, h = img.size
    a = np.empty(w * h * 4, dtype=np.float32)
    img.pixels.foreach_get(a)
    bpy.data.images.remove(img)
    return a.reshape(h, w, 4)


def save_px(arr, path):
    h, w = arr.shape[:2]
    out = bpy.data.images.new("sheet_out", w, h, alpha=False)
    out.pixels.foreach_set(arr.ravel())
    out.filepath_raw = path
    out.file_format = 'PNG'
    out.save()
    bpy.data.images.remove(out)


def render_to(path):
    SCENE.render.filepath = path
    bpy.ops.render.render(write_still=True)


if RENDER and ASSETS:
    import numpy as np
    setup_render(400, 400, 24)
    set_world("#f2e7d5", 0.9)
    sun = add_light('SUN', "Sun", 3.2, "#fff1dc", rot=(50, 0, 35))
    cam_data = bpy.data.cameras.new("SheetCam")
    cam = bpy.data.objects.new("SheetCam", cam_data)
    RIG.objects.link(cam)
    SCENE.camera = cam
    cam_data.type = 'ORTHO'
    label_mat = M("LabelInk", "#2a2a2a", 1, 1.0)
    tiles = []
    entries = []
    for a in ASSETS:
        entries.append((a, a["file"], None))
        if a["file"] in ("window", "condo_window", "storefront_window"):
            entries.append((a, a["file"] + " (ViewNight)", "night"))
    for i, (a, label, variant) in enumerate(entries):
        for b in ASSETS:
            b["coll"].hide_render = b is not a
        day = night = None
        if a["file"] in ("window", "condo_window", "storefront_window"):
            for o in a["root"].children:
                if o.name.endswith("ViewDay"):
                    day = o
                if o.name.endswith("ViewNight"):
                    night = o
            day.hide_render = variant == "night"
            night.hide_render = variant != "night"
        lo, hi = bbox(hierarchy(a["root"]))
        c = (lo + hi) / 2
        view = a["view"]
        dvec = Vector((0.75, -1.0, -0.65 if view == "below" else 0.6)).normalized()
        if view == "back":
            dvec = Vector((0.75, 1.0, 0.4)).normalized()
        hidden = [o for o in a["root"].children if o.name.endswith("Backdrop")]
        for o in hidden:
            o.hide_render = True
        if view == "person":
            dvec = Vector((0.45, -1.0, 0.25)).normalized()
        cam.location = c + dvec * 20
        cam.rotation_euler = look_rot(cam.location, c)
        bpy.context.view_layer.update()
        Rinv = cam.matrix_world.to_3x3().inverted()
        ext = 0.0
        ys = []
        for x in (lo.x, hi.x):
            for y in (lo.y, hi.y):
                for z in (lo.z, hi.z):
                    p = Rinv @ (Vector((x, y, z)) - c)
                    ext = max(ext, abs(p.x), abs(p.y))
        ortho = ext * 2 * 1.3
        cam_data.ortho_scale = ortho
        # Leave the lower band for the label.
        cam.location = cam.location - cam.matrix_world.to_3x3() @ Vector((0, ortho * 0.07, 0))
        dims = hi - lo
        body = "%s\n%.2f x %.2f x %.2f m" % (label, dims.x, dims.y, dims.z)
        cu = bpy.data.curves.new("lbl", 'FONT')
        cu.body = body
        cu.size = ortho * 0.05
        cu.align_x = 'CENTER'
        cu.align_y = 'CENTER'
        if FONT:
            cu.font = FONT
        cu.materials.append(label_mat)
        lbl = bpy.data.objects.new("lbl", cu)
        RIG.objects.link(lbl)
        lbl.parent = cam
        lbl.location = (0, -ortho * 0.41, -1.0)
        path = os.path.join(TMP, "tile_%02d.png" % i)
        SCENE.render.film_transparent = True
        SCENE.render.image_settings.color_mode = 'RGBA'
        render_to(path)
        SCENE.render.film_transparent = False
        bpy.data.objects.remove(lbl)
        bpy.data.curves.remove(cu)
        for o in hidden:
            o.hide_render = False
        if day:
            day.hide_render = False
            night.hide_render = False
        tiles.append(path)
    cols = 7
    tw = th = 400
    rows = (len(tiles) + cols - 1) // cols
    big = np.ones((rows * th, cols * tw, 4), dtype=np.float32)
    for i, p in enumerate(tiles):
        r, cidx = divmod(i, cols)
        px = load_px(p)
        alpha = px[:, :, 3:4]
        card = np.array([0.95, 0.93, 0.90, 1.0], dtype=np.float32)
        px = px * alpha + card * (1 - alpha)
        px[:, :, 3] = 1.0
        y0 = (rows - 1 - r) * th
        big[y0:y0 + th, cidx * tw:(cidx + 1) * tw] = px
        big[y0:y0 + th, cidx * tw:cidx * tw + 1] = 0.75
        big[y0:y0 + 1, cidx * tw:(cidx + 1) * tw] = 0.75
    save_px(big, SHEET)
    print("SAVED", SHEET)

    # ---------------- people sheet: lineup + head close-ups
    people = [a for a in ASSETS if a["view"] == "person"]
    if people:
        for b in ASSETS:
            b["coll"].hide_render = b not in people
        props = bpy.data.collections.new("SheetProps")
        SCENE.collection.children.link(props)
        chair_asset = next((a for a in ASSETS if a["file"] == "office_chair"), None)
        npl = len(people)
        span = max(12.0, npl * 1.1 + 4.0)
        floor = MB()
        floor.box((span, 8, 0.1), (0, 1, -0.05), M("SheetFloor", "#c9a27a", .8))
        floor.box((span, 0.1, 3.0), (0, 2.0, 1.5), M("SheetWall", "#efe6d6", .9))
        floor.box((span, 0.03, 1.0), (0, 1.94, 0.5), M("SheetWainscot", "#8b5a3c", .7))
        make_obj("SheetRoom", floor, props)
        xs = [(i - (npl - 1) / 2) * 1.1 for i in range(npl)]
        for x, a in zip(xs, people):
            a["root"].location = (x, 0, 0)
            seated = any(o.name.endswith("__Hips") and abs(abs(o.matrix_basis.to_euler().z) - PI) < 0.3
                         for o in a["root"].children)
            a["root"].rotation_euler = (0, 0, PI if seated else 0)
            if seated and chair_asset:
                ch = bpy.data.objects.new("SheetChair", chair_asset["root"].data)
                props.objects.link(ch)
                ch.location = (x, 0, 0)
                ch.rotation_euler = (0, 0, PI)
        sheet_w = 384 * npl
        setup_render(sheet_w, 1080, 48)
        set_world("#f2e7d5", 0.6)
        sun.data.energy = 2.6
        sun.rotation_euler = (R(55), 0, R(25))
        key = add_light('AREA', "Key", 600, "#fff1dc", loc=(-2.5, -4.0, 3.5), size=4.0)
        key.rotation_euler = look_rot(key.location, (0, 0, 1))
        cam_data.type = 'PERSP'
        # Fit the whole row (with a margin) across the frame width; up to 5 people keep the original framing.
        cam_data.lens = 42 if npl <= 5 else 18.0 / ((npl * 1.1 + 0.9) / 2 / 6.6)
        cam.location = (0.9 if npl <= 5 else 0.0, -6.6, 1.55)
        cam.rotation_euler = look_rot(cam.location, (0, 0, 0.82))
        lineup = os.path.join(TMP, "people_lineup.png")
        render_to(lineup)
        # Head close-ups.
        setup_render(384, 384, 48)
        cam_data.lens = 60
        heads = []
        for i, a in enumerate(people):
            hobj = next(o for o in a["root"].children_recursive if o.name.endswith("__Head"))
            bpy.context.view_layer.update()
            hp = hobj.matrix_world @ Vector((0, 0, 0.12))
            fwd = (hobj.matrix_world.to_3x3() @ Vector((0, -1, 0)))
            fwd.z = 0
            fwd.normalize()
            side = Vector((fwd.y, -fwd.x, 0))
            cam.location = hp + fwd * 1.1 + side * 0.35 + Vector((0, 0, 0.08))
            cam.rotation_euler = look_rot(cam.location, hp + Vector((0, 0, -0.06)))
            p = os.path.join(TMP, "head_%d.png" % i)
            render_to(p)
            heads.append(p)
        top = load_px(lineup)
        strip = np.ones((384, sheet_w, 4), dtype=np.float32)
        for i, p in enumerate(heads):
            strip[:, i * 384:(i + 1) * 384] = load_px(p)
        save_px(np.concatenate([strip, top], axis=0), PEOPLE_SHEET)
        print("SAVED", PEOPLE_SHEET)
        bpy.data.objects.remove(bpy.data.objects["SheetRoom"])
        for o in list(props.objects):
            bpy.data.objects.remove(o)
        bpy.data.collections.remove(props)
        key_obj = bpy.data.objects.get("Key")
        if key_obj:
            bpy.data.objects.remove(key_obj)
    # ---------------- integration vignette (scratch only): props placed with Godot desk-local numbers
    byf = {a["file"]: a for a in ASSETS}
    need = ["desk", "office_chair", "monitor", "keyboard", "mouse", "desk_phone", "pc_tower", "cubicle_divider",
            "person_coworker_typing", "person_coworker_phone", "printer_station", "person_coworker_printer",
            "pantry_counter", "person_coworker_mug", "water_dispenser", "person_dela_vega", "reception_counter"]
    if all(n in byf for n in need):
        vg = bpy.data.collections.new("Vignette")
        SCENE.collection.children.link(vg)
        for b in ASSETS:
            b["coll"].hide_render = True

        def dup(root):
            m = {}
            for o in hierarchy(root):
                c = o.copy()
                vg.objects.link(c)
                m[o] = c
            for o, c in m.items():
                if o.parent in m:
                    c.parent = m[o.parent]
            return m[root]

        def gx(pos, yaw=0.0):
            x, y, z = pos
            return Matrix.Translation((x, -z, y)) @ Matrix.Rotation(R(yaw), 4, 'Z')

        def place(fname, pos, yaw=0.0, base=Matrix.Identity(4)):
            o = dup(byf[fname]["root"])
            o.matrix_world = base @ gx(pos, yaw)
            return o
        for dx, who in ((0.0, "person_coworker_typing"), (2.5, "person_coworker_phone")):
            B = gx((dx, 0, 0))
            place("desk", (0, 0, 0), base=B)
            place("cubicle_divider", (0, 0.75, -0.355), base=B)
            place("monitor", (-0.05, 0.75, -0.2), base=B)
            place("keyboard", (-0.05, 0.75, 0.12), base=B)
            place("mouse", (0.27, 0.75, 0.12), base=B)
            place("pc_tower", (-0.6, 0.75, -0.12), base=B)
            place("desk_phone", (0.55, 0.75, 0.0), base=B)
            place("office_chair", (-0.05, 0, 0.74), base=B)
            place(who, (-0.05, 0, 0.74), base=B)
        place("printer_station", (5.2, 0, -0.6))
        place("person_coworker_printer", (5.15, 0, 0.12), 180)
        place("pantry_counter", (7.3, 0, -0.6))
        place("water_dispenser", (8.4, 0, -0.65))
        place("person_coworker_mug", (7.1, 0, 0.3), 200)
        place("reception_counter", (-3.2, 0, 0.0))
        place("person_dela_vega", (-3.2, 0, -0.62))
        fl = MB()
        fl.box((16, 8, 0.1), (2.5, -1.0, -0.05), M("SheetFloor", "#c9a27a", .8))
        fl.box((16, 0.1, 3), (2.5, 1.5, 1.5), M("SheetWall", "#efe6d6", .9))
        make_obj("VignetteRoom", fl, vg)
        setup_render(1600, 900, 32)
        cam.location = (2.6, -7.6, 3.0)
        cam_data.lens = 30
        cam.rotation_euler = look_rot(cam.location, (2.6, 0.0, 0.7))
        render_to(os.path.join(TMP, "vignette_front.png"))
        cam.location = (2.0, -1.6, 1.3)
        cam_data.lens = 35
        cam.rotation_euler = look_rot(cam.location, (0.0, -0.4, 0.8))
        render_to(os.path.join(TMP, "vignette_side.png"))
        for o in list(vg.objects):
            bpy.data.objects.remove(o)
        bpy.data.collections.remove(vg)
    for b in ASSETS:
        b["coll"].hide_render = False

# ================================================================== LAYOUT + SAVE
if not ONLY:
    x = 0.0
    row_y = {"floor": 0.0}
    xs = {"desk": 0.0}
    cx, cy, row_w = 0.0, 0.0, 0.0
    for a in ASSETS:
        w = a["hi"].x - a["lo"].x
        if a["view"] == "person":
            continue
        if cx + w > 16.0:
            cx = 0.0
            cy -= 3.0
        a["root"].location = (cx + w / 2 - (a["lo"].x + a["hi"].x) / 2, cy, 0 if a["origin"] != CEIL else 3.0)
        a["root"].rotation_euler = (0, 0, 0)
        cx += w + 0.5
    px = 0.0
    for a in ASSETS:
        if a["view"] == "person":
            a["root"].location = (px, cy - 3.5, 0)
            a["root"].rotation_euler = (0, 0, 0)
            px += 1.2
    bpy.ops.wm.save_as_mainfile(filepath=BLEND)
    print("SAVED", BLEND)
