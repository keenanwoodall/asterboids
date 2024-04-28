#version 330

// Input vertex attributes (from vertex shader)
in vec2 fragTexCoord;
in vec4 fragColor;

// Input uniform values
uniform sampler2D texture0;
uniform vec4 colDiffuse;

// Output fragment color
out vec4 finalColor;

void main() {
    vec4 input_color = texture(texture0, fragTexCoord) * colDiffuse;
    vec2 uv = fragTexCoord;

    uv *= 1 - uv.yx;

    float v = uv.x * uv.y * 30.0;

    v = pow(v, 0.2);

    finalColor = input_color * vec4(v, v, v, 1);
}
