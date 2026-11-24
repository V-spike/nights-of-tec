# Manos del jugador sosteniendo la linterna (vista en primera persona).
# Convención: la linterna apunta a +Y (adelante en Blender), Z arriba.
import sys, os
AQUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, AQUI)
from comun import *  # funciones de ayuda: material, skin_object, export
reset()
skin = mat("Piel", (0.62, 0.47, 0.40), 0.55)
sleeve = mat("Manga", (0.035, 0.04, 0.05), 0.9)
metal = mat("LinternaCuerpo", (0.02, 0.02, 0.022), 0.35, 0.6)
chrome = mat("LinternaBisel", (0.6, 0.6, 0.62), 0.2, 1.0)
lens = mat("LinternaLente", (0.9, 0.9, 0.85), 0.05, 0.0, (1.0, 0.95, 0.8), 2.0)

R = 0.017  # radio del cuerpo de la linterna
# ---- Linterna: cuerpo, cabeza más ancha, bisel y lente
def cyl(name, r1, r2, y0, y1, m, verts=32):
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r1, radius2=r2, depth=y1-y0,
                                    location=(0, (y0+y1)/2, 0), rotation=(-math.pi/2, 0, 0))
    o = bpy.context.active_object; o.name = name; o.data.materials.append(m); shade_smooth(o); return o
body = cyl("Cuerpo", R, R, -0.09, 0.05, metal)
neck = cyl("Cuello", R, 0.024, 0.05, 0.075, metal)
head = cyl("Cabeza", 0.024, 0.024, 0.075, 0.11, metal)
bezel = cyl("Bisel", 0.026, 0.026, 0.105, 0.115, chrome)
lensd = cyl("Lente", 0.021, 0.021, 0.113, 0.116, lens)
tail = cyl("Tapa", R*1.05, R*1.05, -0.1, -0.088, chrome)
# botón de encendido
bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=0.005, depth=0.006, location=(0, 0.035, R+0.002))
btn = bpy.context.active_object; btn.data.materials.append(chrome)

# ---- Mano derecha (puño cerrado alrededor del cuerpo)
def P(phi_deg, r, y):
    a = math.radians(phi_deg); return (r*math.cos(a), y, r*math.sin(a))
verts=[]; edges=[]; radii=[]
def add(p, r):
    verts.append(p); radii.append(r); return len(verts)-1
wrist = add((0.035, -0.085, -0.012), (0.024, 0.018))
palm  = add((0.033, -0.035, 0.004), (0.03, 0.017))
edges.append((wrist, palm))
fy = [0.026, 0.008, -0.010, -0.027]          # índice, medio, anular, meñique
fr = [0.0085, 0.009, 0.0085, 0.0075]
for i, y in enumerate(fy):
    k  = add(P(35, 0.040, y), fr[i]*1.15)    # nudillo (arriba a la derecha)
    edges.append((palm, k))
    a = add(P(-25, R+fr[i]+0.002, y), fr[i])
    b = add(P(-95, R+fr[i]+0.001, y), fr[i]*0.95)
    c = add(P(-150, R+fr[i], y+0.002), fr[i]*0.85)
    edges += [(k, a), (a, b), (b, c)]
# pulgar: sale del lado de la palma y pasa por encima
t0 = add(P(-5, 0.035, -0.045), 0.012)
t1 = add(P(55, R+0.011, -0.01), 0.010)
t2 = add(P(110, R+0.009, 0.018), 0.0085)
t3 = add(P(150, R+0.008, 0.034), 0.0075)
edges += [(palm, t0), (t0, t1), (t1, t2), (t2, t3)]
# antebrazo (dentro de la manga)
fore = add((0.09, -0.30, -0.09), (0.032, 0.03))
edges.append((wrist, fore))
hand = skin_object("Mano", verts, edges, radii, skin, 2)

# ---- Manga: cilindro de tela del puño al codo
sv = [(0.04, -0.105, -0.015), (0.075, -0.22, -0.065), (0.12, -0.42, -0.13)]
sl = skin_object("Manga", sv, [(0,1),(1,2)], [(0.036,0.034),(0.044,0.04),(0.05,0.046)], sleeve, 2)

for o in list(bpy.data.objects):
    if o.type == 'MESH':
        bpy.context.view_layer.objects.active = o
        apply_all(o)
export(os.path.join(AQUI, '..', '..', 'assets', 'models', 'manos_linterna.glb'))

# ---- Vista previa (Workbench)
bpy.ops.object.light_add(type='SUN', location=(0.5,-0.5,1)); 
bpy.ops.object.camera_add(location=(-0.06, -0.33, 0.11), rotation=(math.radians(78), 0, math.radians(-10)))
cam = bpy.context.active_object; bpy.context.scene.camera = cam; cam.data.lens = 30
sc = bpy.context.scene; sc.render.engine = 'CYCLES'; sc.cycles.device='CPU'; sc.cycles.samples=16
w=bpy.data.worlds.new('W'); sc.world=w; w.use_nodes=True; w.node_tree.nodes['Background'].inputs[0].default_value=(0.4,0.42,0.45,1)
sc.render.resolution_x = 640; sc.render.resolution_y = 400
sc.render.filepath = os.path.join(AQUI, 'manos_prev.png')
bpy.ops.render.render(write_still=True)
cam.location=(0.25,0.0,0.05); cam.rotation_euler=(math.radians(90),0,math.radians(100))
sc.render.filepath = os.path.join(AQUI, 'manos_prev2.png'); bpy.ops.render.render(write_still=True)
print("OK")
