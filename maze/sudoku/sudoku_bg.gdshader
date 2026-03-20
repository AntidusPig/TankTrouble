shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform vec4 base_color : source_color = vec4(0.83, 0.90, 1.0, 0.3);
uniform float blur_amount : hint_range(0.0, 5.0) = 2.0;
uniform float fluid_speed : hint_range(0.0, 2.0) = 0.5;
uniform float detail : hint_range(1.0, 10.0) = 10.0; // "Musgrave" octaves

// Simple hash for noise generation
float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

// Basic Value Noise
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	// quintic interpolation
	f = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// Fractional Brownian Motion (The "Musgrave" feel)
float fbm(vec2 p) {
	float value = 0.0;
	float amplitude = 0.5;
	for (int i = 0; i < int(detail); i++) {
		value += amplitude * noise(p);
		p *= 2.0;
		amplitude *= 0.5;
	}
	return value;
}

void fragment() {
    float time = TIME * fluid_speed;
    
    // 1. Use SCREEN_UV for EVERYTHING to kill the seams.
    // We multiply by a 'density' factor to control how many "paint swirls" appear.
    vec2 world_uv = SCREEN_UV * 2.0; 
    
    // 2. Optimization: Calculate N1 and N2 using only world coordinates.
    // This ensures the flow is continuous across cell boundaries.
    float n1 = fbm(world_uv + time);
    
    // We add n1 to the coordinates of n2 to create "Liquid Advection" (swirling)
    float n2 = fbm(world_uv * 1.5 - time * 0.5 + vec2(n1));
    
    // 3. Periodic/Seamless Refraction
    // Lower distortion prevents the 'stretched pixel' look at edges
    vec2 distort = vec2(n1, n2) * 0.008; 
    vec4 lod_color = textureLod(screen_texture, SCREEN_UV + distort, blur_amount);
    
    // 4. Final Acrylic Blend
    vec3 final_rgb = mix(lod_color.rgb, base_color.rgb, base_color.a);
    
    // Subtle "Surface Shine" based on the noise
    final_rgb += n2 * 0.03; 
    
    // Mask by the Sprite/Shape alpha
    float shape = texture(TEXTURE, UV).a;
    COLOR = vec4(final_rgb, shape);
}