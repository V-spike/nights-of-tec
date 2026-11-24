// Follaje de los pinos: verde oscuro con variación por árbol y balanceo con el viento.
shader_type spatial;
render_mode cull_disabled, diffuse_lambert_wrap;

uniform vec3 color_a : source_color = vec3(0.035, 0.07, 0.045);
uniform vec3 color_b : source_color = vec3(0.07, 0.10, 0.06);
uniform float wind_strength = 0.12;
uniform float wind_speed = 0.9;

varying float tree_hash;

float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;          // posición de este árbol
	tree_hash = hash(origin.xz);
	float h = clamp(VERTEX.y / 6.0, 0.0, 1.0);   // más alto = se mueve más
	float t = TIME * wind_speed + tree_hash * 6.28;
	VERTEX.x += sin(t) * wind_strength * h * h;
	VERTEX.z += cos(t * 0.7) * wind_strength * 0.6 * h * h;
}

void fragment() {
	vec3 c = mix(color_a, color_b, tree_hash);
	c *= mix(0.6, 1.0, UV.y);                    // más oscuro hacia dentro de la rama
	ALBEDO = c;
	ROUGHNESS = 0.95;
	BACKLIGHT = vec3(0.03, 0.05, 0.03);
	if (!FRONT_FACING) { NORMAL = -NORMAL; }
}
