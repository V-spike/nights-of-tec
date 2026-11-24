// Viñeta de cámara: oscurece las orillas, agrega grano de película y,
// con peligro, tiñe de rojo y separa un poco los colores (aberración).
// Los valores los mueve scripts/systems/danger_fx.gd en cada cuadro.
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float intensity : hint_range(0.0, 1.5) = 0.3;   // qué tanto se cierra la viñeta
uniform float red_amount : hint_range(0.0, 1.0) = 0.0;  // tinte rojo en las orillas
uniform float grain : hint_range(0.0, 0.3) = 0.04;      // grano de película
uniform float aberration : hint_range(0.0, 0.02) = 0.0; // separación de colores
uniform float desaturate : hint_range(0.0, 1.0) = 0.0;  // quita color con el miedo

float rand(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 d = uv - 0.5;
	d.x *= SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x; // corrige la proporción 16:9
	float r = length(d);

	// Aberración cromática: rojo y azul se desplazan hacia afuera
	vec2 dir = normalize(uv - 0.5 + 1e-5) * aberration * r;
	vec3 col;
	col.r = texture(screen_tex, uv + dir).r;
	col.g = texture(screen_tex, uv).g;
	col.b = texture(screen_tex, uv - dir).b;

	// Pierde color con el miedo
	float gray = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(col, vec3(gray), desaturate);

	// Viñeta: 0 en el centro, 1 en las esquinas
	float inner = 0.62 - intensity * 0.42;
	float v = smoothstep(inner, inner + 0.5, r);
	vec3 edge = mix(vec3(0.0), vec3(0.22, 0.0, 0.0), red_amount);
	col = mix(col, edge, v * clamp(0.55 + intensity * 0.5, 0.0, 1.0));

	// Grano animado
	float n = rand(uv * vec2(1920.0, 1080.0) + fract(TIME * 7.13)) - 0.5;
	col += n * grain;

	COLOR = vec4(col, 1.0);
}
