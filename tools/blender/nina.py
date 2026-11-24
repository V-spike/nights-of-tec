# La niña del screamer: niña fantasma con vestido rasgado y cabello largo que
# le tapa la cara. Modelada por código (modificador Skin + mallas procedurales).
import sys, os
AQUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, AQUI)
from comun import *  # funciones de ayuda: material, skin_object, export
reset()
rnd = random.Random(4)
skin  = mat("PielPalida", (0.36, 0.38, 0.40), 0.7)
dress = mat("VestidoSucio", (0.42, 0.40, 0.35), 0.95)
hairm = mat("Cabello", (0.008, 0.008, 0.01), 0.45)
eyem  = mat("OjoNegro", (0.0, 0.0, 0.0), 0.2)
pupil = mat("Pupila", (1, 1, 1), 0.2, 0, (0.85, 0.9, 1.0), 6.0)
mouth = mat("Boca", (0.02, 0.0, 0.0), 0.5)

H = 1.18  # estatura (niña de ~8 años)
# ---- Cuerpo (esqueleto con Skin): pelvis, torso, cuello, brazos largos, piernas delgadas
V=[]; E=[]; Rr=[]
def add(p, r): V.append(p); Rr.append(r); return len(V)-1
pel = add((0, 0, 0.62), (0.085, 0.06))
chest = add((0, 0.01, 0.86), (0.095, 0.06))
neck = add((0, 0.015, 0.98), 0.032)
E += [(pel, chest), (chest, neck)]
for s in (-1, 1):
    sh = add((s*0.11, 0.01, 0.93), 0.035)
    el = add((s*0.15, 0.03, 0.70), 0.026)        # brazos colgando, un poco hacia adelante
    wr = add((s*0.16, 0.07, 0.47), 0.02)          # brazos demasiado largos (inquietante)
    hd = add((s*0.165, 0.08, 0.41), (0.024, 0.012))
    E += [(chest, sh), (sh, el), (el, wr), (wr, hd)]
    # dedos largos
    for k in range(4):
        f1 = add((s*(0.15+0.01*k), 0.08+0.006*k-0.01, 0.36), 0.0055)
        f2 = add((s*(0.148+0.011*k), 0.085+0.006*k-0.01, 0.30), 0.0045)
        E += [(hd, f1), (f1, f2)]
    hip = add((s*0.06, 0, 0.6), 0.05)
    kn = add((s*0.065, 0.02, 0.32), 0.032)
    an = add((s*0.06, 0.0, 0.05), 0.024)
    ft = add((s*0.06, 0.09, 0.02), (0.03, 0.018))
    E += [(pel, hip), (hip, kn), (kn, an), (an, ft)]
body = skin_object("Cuerpo", V, E, Rr, skin, 2)

# ---- Cabeza: esfera algo alargada, inclinada a un lado
bpy.ops.mesh.primitive_uv_sphere_add(segments=32, ring_count=20, radius=0.1, location=(0.02, 0.025, 1.09))
head = bpy.context.active_object; head.name = "Cabeza"
head.scale = (0.9, 0.95, 1.12); head.rotation_euler = (math.radians(8), math.radians(-14), 0)
head.data.materials.append(skin); shade_smooth(head)
# Ojos: cuencas negras y una pupila brillante (solo un ojo se asoma entre el pelo)
for s, show in ((-1, True), (1, False)):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=8, radius=0.024,
        location=(0.02+s*0.036, 0.117, 1.10 + (0.0 if s<0 else -0.01)))
    e = bpy.context.active_object; e.scale=(1.1,0.55,1.35); e.data.materials.append(eyem); shade_smooth(e)
    if show:
        bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=6, radius=0.0055, location=(0.02+s*0.036, 0.13, 1.10))
        p = bpy.context.active_object; p.data.materials.append(pupil)
# boca abierta, alargada
bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=8, radius=0.022, location=(0.01, 0.1, 1.02))
m = bpy.context.active_object; m.scale=(0.9,0.45,1.9); m.data.materials.append(mouth); shade_smooth(m)

# ---- Vestido: tubo que se abre hacia abajo, con dobladillo rasgado
seg, rings = 48, 14
bm = bmesh.new()
rows = []
for j in range(rings+1):
    t = j / rings
    z = 0.95 - t * 0.62
    r = 0.085 + 0.13 * (t ** 1.3)
    row = []
    for i in range(seg):
        a = 2*math.pi*i/seg
        rr = r * (1 + 0.06*math.sin(a*5 + t*4) * t)   # pliegues
        zz = z
        if j == rings:  # dobladillo rasgado: tiras de distinto largo
            zz += rnd.uniform(-0.12, 0.06)
        row.append(bm.verts.new((rr*math.cos(a)*1.05, rr*math.sin(a)*0.85+0.01, zz)))
    rows.append(row)
for j in range(rings):
    for i in range(seg):
        bm.faces.new((rows[j][i], rows[j][(i+1)%seg], rows[j+1][(i+1)%seg], rows[j+1][i]))
me = bpy.data.meshes.new("Vestido"); bm.to_mesh(me)
dr = bpy.data.objects.new("Vestido", me); bpy.context.collection.objects.link(dr)
dr.data.materials.append(dress); shade_smooth(dr)
so = dr.modifiers.new("Grosor", "SOLIDIFY"); so.thickness = 0.008
ss = dr.modifiers.new("Sub", "SUBSURF"); ss.levels = 1
# tirantes/hombros del vestido
sv = [(-0.11,0.01,0.93),(0,0.02,0.95),(0.11,0.01,0.93)]
skin_object("Hombros", sv, [(0,1),(1,2)], [0.04,0.06,0.04], dress, 1)

# ---- Cabello: muchos mechones largos (cintas) que caen y tapan la cara
hb = bmesh.new()
cx, cy, cz = 0.02, 0.02, 1.12
n = 170
for k in range(n):
    a = 2*math.pi*k/n + rnd.uniform(-0.03,0.03)
    front = math.cos(a - math.pi/2)   # 1 = frente (+Y)
    # raíz sobre el cuero cabelludo
    root = Vector((cx + 0.095*math.cos(a), cy + 0.095*math.sin(a), cz + 0.06))
    length = rnd.uniform(0.55, 0.8) if front < 0.3 else rnd.uniform(0.35, 0.55)
    # deja una rendija para que se asome el ojo izquierdo
    # raya en medio: el cabello se abre y deja ver la cara (cara a +Y, a = pi/2)
    da = abs(a - math.pi/2)
    if da < 0.3:
        continue
    if da < 0.55:
        length = rnd.uniform(0.6, 0.8)   # mechones largos que enmarcan la cara
    w = rnd.uniform(0.012, 0.022)
    steps = 7
    prev = None
    side = Vector((-math.sin(a), math.cos(a), 0)) * w
    for s in range(steps+1):
        t = s/steps
        out = 0.105 + 0.03*math.sin(t*math.pi*0.9) + (0.045 if front>0.5 else 0.0)*t
        p = Vector((cx + out*math.cos(a), cy + out*math.sin(a), cz + 0.06 - t*length))
        p.x += rnd.uniform(-0.006,0.006); p.y += rnd.uniform(-0.006,0.006)
        sw = side * (1 - 0.7*t)
        v1 = hb.verts.new(p - sw); v2 = hb.verts.new(p + sw)
        if prev: hb.faces.new((prev[0], prev[1], v2, v1))
        prev = (v1, v2)
# casquete del cabello
hm = bpy.data.meshes.new("Cabello"); hb.to_mesh(hm)
hair = bpy.data.objects.new("Cabello", hm); bpy.context.collection.objects.link(hair)
hair.data.materials.append(hairm); shade_smooth(hair)
so = hair.modifiers.new("Grosor", "SOLIDIFY"); so.thickness = 0.003
bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=12, radius=0.108, location=(0.02, -0.012, 1.15))
cap = bpy.context.active_object; cap.scale=(0.97,0.95,0.92); cap.data.materials.append(hairm); shade_smooth(cap)

for o in list(bpy.data.objects):
    if o.type == 'MESH':
        apply_all(o)
# Unir todo en un solo objeto (más simple para Godot)
bpy.ops.object.select_all(action='SELECT')
bpy.context.view_layer.objects.active = body
bpy.ops.object.join()
export(os.path.join(AQUI, '..', '..', 'assets', 'models', 'nina.glb'))

# ---- Vista previa
sc = bpy.context.scene; sc.render.engine = 'CYCLES'; sc.cycles.device='CPU'; sc.cycles.samples=24
w=bpy.data.worlds.new('W'); sc.world=w; w.use_nodes=True; w.node_tree.nodes['Background'].inputs[0].default_value=(0.25,0.26,0.28,1)
bpy.ops.object.light_add(type='AREA', location=(0.6, 1.4, 1.6)); L=bpy.context.active_object; L.data.energy=60; L.rotation_euler=(math.radians(-50),math.radians(20),math.radians(180))
bpy.ops.object.camera_add(location=(0.0, 2.2, 0.9), rotation=(math.radians(88), 0, math.radians(180)))
cam = bpy.context.active_object; sc.camera = cam; cam.data.lens = 40
sc.render.resolution_x = 360; sc.render.resolution_y = 480
sc.render.filepath = os.path.join(AQUI, 'nina_prev.png'); bpy.ops.render.render(write_still=True)
cam.location=(0.0, 0.55, 1.08); cam.rotation_euler=(math.radians(90),0,math.radians(180)); cam.data.lens=35
sc.render.filepath = os.path.join(AQUI, 'nina_prev2.png'); bpy.ops.render.render(write_still=True)
print("OK")
