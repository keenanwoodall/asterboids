#version 330

// Input vertex attributes (from vertex shader)
in vec2 fragTexCoord;
in vec4 fragColor;

// Input uniform values
uniform sampler2D texture0;
uniform vec4 colDiffuse;

// Output fragment color
out vec4 finalColor;

// Constants for render dimensions
const float renderWidth = 1920.0 / 4.0;
const float renderHeight = 1080.0 / 4.0;

// Gaussian function for brightness adjustment
float gaussian1D(float x, float mean, float stddev) {
    float normalization = 1.0 / (stddev * sqrt(2.0 * 3.1415926535));
    float exponent = -0.5 * pow((x - mean) / stddev, 2.0);
    return normalization * exp(exponent);
}

// Reduce curvature strength to avoid excessive distortion
const float curvatureStrength = 0.03;

// Main function
void main() {
    // Introduce subtle curvature distortion
    vec2 uv = fragTexCoord;
    float distortion = curvatureStrength * (uv.x - 0.5) * (uv.y - 0.5);

    // Adjust the texture coordinates with minimal distortion
    vec2 distortedUV = uv + vec2(distortion, 0.0);

    // Clamp UV coordinates to prevent wrapping issues
    distortedUV = clamp(distortedUV, vec2(0.0, 0.0), vec2(1.0, 1.0));

    // Retrieve color from the texture using corrected coordinates
    vec4 input_color = texture(texture0, distortedUV) * colDiffuse;

    // Apply Gaussian peak for brightness adjustment
    float brightnessAdjustment = gaussian1D(fract(uv.y * renderHeight * .75), 0.5, 0.3);

    // Set the final color with adjusted brightness and distortion
    finalColor = vec4(clamp(input_color.rgb * brightnessAdjustment, 0, 1), 1.0);
}
