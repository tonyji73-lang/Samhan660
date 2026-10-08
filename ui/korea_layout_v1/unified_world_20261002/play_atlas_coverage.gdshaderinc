// Display-only offshore join. Preserve original coasts, islands and rivers.
float play_atlas_coverage(vec2 native) {
	// The western edge of the old square lies in open sea below the mainland.
	// A broad offshore transition avoids a visible rectangular water patch.
	float west_width = mix(24.0,300.0,smoothstep(210.0,340.0,native.y));
	float west = smoothstep(0.0,west_width,native.x);
	float south = smoothstep(0.0,180.0,1254.0-native.y);
	// Jeju and its surrounding coastal water remain fully original.
	float jeju = 1.0-smoothstep(75.0,135.0,length(native-vec2(535.0,1098.0)));
	south = max(south,jeju);
	float north = smoothstep(0.0,24.0,native.y);
	float east = 1.0-smoothstep(1000.0,1080.0,native.x);
	return west*south*north*east;
}
