import bpy, numpy as np, sys
d = sys.argv[sys.argv.index("--") + 1]
names = ["day_morning", "day_noon", "day_afternoon", "day_evening"]
tiles = []
for n in names:
    im = bpy.data.images.load(f"{d}/{n}.png")
    a = np.array(im.pixels[:], dtype=np.float32).reshape(720, 1280, 4)
    tiles.append(a[::2, ::2])
bottom = np.concatenate([tiles[2], tiles[3]], axis=1)  # Blender rows go bottom-up
top = np.concatenate([tiles[0], tiles[1]], axis=1)
grid = np.concatenate([bottom, top], axis=0)
out = bpy.data.images.new("grid", 1280, 720, alpha=True)
out.pixels = grid.ravel()
out.filepath_raw = f"{d}/day_cycle.png"
out.file_format = "PNG"
out.save()
print("GRID OK")
