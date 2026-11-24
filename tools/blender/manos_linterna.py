# Mano del jugador (con guante) sosteniendo la linterna, vista en primera persona.
# Convención: la linterna apunta a +Y (adelante en Blender), Z arriba.
# Al exportar a glTF, +Y de Blender queda como -Z en Godot (el "adelante" de Godot).
#
# v1.1b: guante de piel oscuro + manga de chamarra con puño, cola de la linterna
# en hule mate (antes era cromada y parecía que el foco te apuntaba a ti).
import sys, os
AQUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, AQUI)
from comun import *  # funciones de ayuda: material, skin_object, export
reset()
guante = mat("Guante", (0.045, 0.038, 0.034), 0.45)
manga = mat("Manga", (0.055, 0.065, 0.075), 0.95)
puno = mat("Puno", (0.03, 0.033, 0.036), 1.0)
cuerpo = mat("LinternaCuerpo", (0.025, 0.026, 0.028), 0.4, 0.7)
hule = mat("LinternaHule", (0.012, 0.012, 0.012), 0.85)
cromo = mat("LinternaBisel", (0.7, 0.7, 0.72), 0.18, 1.0)
lente = mat("LinternaLente", (0.9, 0.9, 0.85), 0.05, 0.0, (1.0, 0.95, 0.8), 2.0)

R = 0.018  # radio del cuerpo de la linterna

# ---- Linterna: cola de hule, cuerpo con anillos de agarre, cuello, cabeza, bisel y lente
def cyl(name, r1, r2, y0, y1, m, verts=32):
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r1, radius2=r2, depth=y1-y0,
                                    location=(0, (y0+y1)/2, 0), rotation=(-math.pi/2, 0, 0))
    o = bpy.context.active_object; o.name = name; o.data.materials.append(m); shade_smooth(o); return o
cyl("Cola", R*1.02, R*1.02, -0.115, -0.095, hule)
cyl("Cuerpo", R, R, -0.095, 0.05, cuerpo)
for i in range(6):  # anillos de agarre detrás de la mano
    y = -0.09 + i * 0.006
    cyl("Anillo%d" % i, R*1.05, R*1.05, y, y + 0.003, cuerpo)
cyl("Cuello", R, 0.026, 0.05, 0.078, cuerpo)
cyl("Cabeza", 0.026, 0.026, 0.078, 0.112, cuerpo)
cyl("Bisel", 0.0285, 0.0285, 0.108, 0.118, cromo)
cyl("Lente", 0.023, 0.023, 0.114, 0.119, lente)
bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=0.0055, depth=0.006, location=(0, 0.04, R + 0.002))
btn = bpy.context.active_object; btn.name = "Boton"; btn.data.materials.append(hule)

# ---- Mano derecha con guante: puño cerrado alrededor del cuerpo
def P(phi_deg, r, y):
    """Punto alrededor del eje de la linterna: ángulo (0 = derecha, 90 = arriba), radio y avance."""
    a = math.radians(phi_deg); return (r*math.cos(a), y, r*math.sin(a))
# Cada dedo es una cadena SEPARADA (sin ramificar): el modificador Skin deja
# huecos raros cuando de un mismo vértice salen muchas ramas.
def chain(name, pts, rads):
    return skin_object(name, pts, [(i, i + 1) for i in range(len(pts) - 1)], rads, guante, 2)

# Dorso de la mano: un elipsoide aplanado, con el dorso mirando arriba a la derecha
bpy.ops.mesh.primitive_uv_sphere_add(segments=32, ring_count=16, location=P(38, 0.036, -0.022))
dorso = bpy.context.active_object; dorso.name = "Dorso"
dorso.scale = (0.03, 0.04, 0.014)            # ancho, largo, grosor
dorso.rotation_euler = (0, math.radians(52), 0)  # el grosor apunta hacia afuera del cuerpo
dorso.data.materials.append(guante); shade_smooth(dorso)
bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)

fy = [0.022, 0.004, -0.014, -0.03]  # índice, medio, anular, meñique
fr = [0.0098, 0.0102, 0.0096, 0.0086]
for i, y in enumerate(fy):
    pts = [P(40, 0.034, y - 0.01),               # dentro del dorso
           P(25, R + fr[i] + 0.004, y),          # nudillo
           P(-20, R + fr[i] + 0.001, y),         # falange 1: baja por la derecha
           P(-90, R + fr[i], y),                 # falange 2: por debajo
           P(-140, R + fr[i] - 0.001, y)]        # punta: asoma a la izquierda
    chain("Dedo%d" % i, pts, [fr[i] * 1.1, fr[i] * 1.15, fr[i], fr[i] * 0.97, fr[i] * 0.88])
# pulgar: sale del lado izquierdo del dorso y se apoya encima, apuntando adelante
chain("Pulgar", [P(55, 0.032, -0.05), P(80, R + 0.013, -0.035), P(100, R + 0.011, -0.012),
                 P(114, R + 0.009, 0.006), P(122, R + 0.008, 0.018)],
      [0.013, 0.012, 0.0105, 0.0092, 0.0082])
# muñeca: del dorso hacia adentro de la manga
chain("Muneca", [P(35, 0.034, -0.04), (0.033, -0.09, -0.006)], [(0.024, 0.02), (0.025, 0.021)])

# ---- Manga de la chamarra: del puño hacia el codo (sale de cuadro abajo a la derecha)
sv = [(0.036, -0.085, -0.008), (0.06, -0.2, -0.05), (0.11, -0.42, -0.13)]
skin_object("Manga", sv, [(0, 1), (1, 2)], [(0.036, 0.033), (0.045, 0.041), (0.052, 0.048)], manga, 2)
# puño elástico de la manga: un tramo corto, más grueso y oscuro, en la muñeca
skin_object("Puno", [(0.034, -0.078, -0.006), (0.04, -0.1, -0.014)], [(0, 1)],
            [(0.034, 0.031), (0.036, 0.033)], puno, 2)

for o in list(bpy.data.objects):
    if o.type == 'MESH':
        apply_all(o)
export(os.path.join(AQUI, '..', '..', 'assets', 'models', 'manos_linterna.glb'))

# ---- Vista previa con la misma cámara del juego (FOV vertical 75°)
if "--preview" in sys.argv:
    bpy.ops.object.light_add(type='AREA', location=(-0.1, -0.3, 0.3)); bpy.context.active_object.data.energy = 3
    bpy.ops.object.camera_add(location=(-0.11, -0.28, 0.12), rotation=(math.radians(90), 0, 0))
    cam = bpy.context.active_object; bpy.context.scene.camera = cam
    cam.data.sensor_fit = 'VERTICAL'; cam.data.angle_y = math.radians(75); cam.data.clip_start = 0.01
    sc = bpy.context.scene; sc.render.engine = 'CYCLES'; sc.cycles.device = 'CPU'; sc.cycles.samples = 24
    w = bpy.data.worlds.new('W'); sc.world = w; w.use_nodes = True
    w.node_tree.nodes['Background'].inputs[0].default_value = (0.25, 0.26, 0.28, 1)
    sc.render.resolution_x = 640; sc.render.resolution_y = 360
    sc.render.filepath = '/tmp/manos_prev.png'
    bpy.ops.render.render(write_still=True)
    cam.location = (-0.02, -0.2, 0.06); cam.rotation_euler = (math.radians(80), 0, math.radians(-20))
    sc.render.filepath = '/tmp/manos_prev2.png'; bpy.ops.render.render(write_still=True)
print("OK")
