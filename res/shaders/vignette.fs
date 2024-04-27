#version 330

// Input vertex attributes (from vertex shader)
in vec2 fragTexCoord;
in vec4 fragColor;

// Input uniform values
uniform sampler2D texture0;
uniform vec4 colDiffuse;

float vignetteRadius = 0.7;  // Adjusts the radius of the vignette
float vignetteSoftness = 0.1;  // Adjusts the smoothness of the transition

// Output fragment color
out vec4 finalColor;

// Main function
void main() {
    // Sample the texture color at the current texture coordinate
    vec4 color = texture(texture0, fragTexCoord) * colDiffuse;

    // Calculate the distance from the center of the texture
    vec2 center = vec2(0.5, 0.5);  // Center of the vignette
    float dist = length(fragTexCoord - center);

    // Calculate the vignette effect using a smoothstep function for smooth transition
    float vignette = mix(0.1, 1, smoothstep(vignetteRadius, vignetteRadius - vignetteSoftness, dist));

    // Apply the vignette effect to the color
    finalColor = vec4(color.rgb * vignette, color.a);
}
