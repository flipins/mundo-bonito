shader_type spatial;
render_mode cull_disabled;

uniform vec3 color : source_color;
uniform vec3 color2 : source_color;
uniform sampler2D noise;
uniform float noiseScale = 20.0;

// --- NUEVOS CONTROLES DE VIENTO ---
uniform float wind_speed = 2.0;
uniform float wind_strength = 0.15;

varying vec3 worldPos;

void vertex() {
    worldPos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    
    // Calculamos un movimiento suave basado en la posición y el tiempo
    float wind = sin(worldPos.x * 0.5 + TIME * wind_speed) * sin(worldPos.z * 0.5 + TIME * wind_speed);
    
    // Movemos las puntas, manteniendo la raíz fija con (1.0 - UV.y)
    VERTEX.x += wind * wind_strength * (1.0 - UV.y);
}

void fragment() {
    vec3 noiseLevel = texture(noise, worldPos.xz / noiseScale).rgb;
    ALBEDO = mix(color, color2, 1.0 - UV.y) * mix(color, color2, noiseLevel.r);
    if (!FRONT_FACING) {
        NORMAL = -NORMAL;
    }
}