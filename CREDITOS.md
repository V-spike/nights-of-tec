# Créditos y licencias de recursos — Nights of Tec v1.1

Todos los recursos externos son **libres** y permiten uso en proyectos escolares y comerciales.

## Texturas PBR (ambientCG — licencia CC0, dominio público)
Fuente: https://ambientcg.com

| Carpeta en el proyecto | Material original |
|---|---|
| `assets/textures/pbr/piso_terrazo` | Terrazzo003 |
| `assets/textures/pbr/pared_yeso` | PaintedPlaster017 |
| `assets/textures/pbr/techo_plafon` | OfficeCeiling005 |
| `assets/textures/pbr/pasto` | Grass004 |
| `assets/textures/pbr/banqueta` | PavingStones070 |
| `assets/textures/pbr/corteza` | Bark012 |
| `assets/textures/pbr/concreto` | Concrete034 |

## Cielo (Poly Haven — licencia CC0)
- `assets/sky/moonless_golf_2k.hdr`: "Moonless Golf" HDRI, https://polyhaven.com

## Fuentes
- **Special Elite** (Astigmatic): Apache License 2.0. `assets/fonts/SpecialElite-Regular.ttf`
- **Barlow Condensed** (Jeremy Tribby): SIL Open Font License 1.1. `assets/fonts/BarlowCondensed-*.ttf`

## Sonidos generados por código (propios del equipo)
Los archivos nuevos de `assets/audio/` (música del menú, ambiente, latido, respiración, zumbido y chispa de lámparas, sonidos de interfaz, aguijón y pasos) se **sintetizaron con Python** usando `tools/generar_audio.py`. No usan muestras de terceros.

## Modelos 3D generados por código (propios del equipo)
- `assets/models/manos_linterna.glb` y `assets/models/nina.glb` se generaron con Blender (módulo `bpy`) usando los scripts de `tools/blender/`.
- Los pinos del exterior se generan en tiempo real con `scripts/level/exterior_trees.gd`.

## Motor y herramientas
- Godot Engine 4.7.2: licencia MIT, https://godotengine.org
- Blender: GPL (el contenido creado con Blender es del autor).
