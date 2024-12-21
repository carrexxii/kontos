#version 460

#ifdef VERTEX /////////////////////////////////////////////

const vec3 verts[6] = {
    vec3(0, 0, 0), vec3(1, 0, 0), vec3(0, 1, 0),
    vec3(0, 1, 0), vec3(1, 0, 0), vec3(1, 1, 0),
};

layout(location = 0) out vec2 out_uv;

layout(set = 1, binding = 0) uniform Camera {
    mat4 proj;
    mat4 view;
} camera;

layout(set = 0, binding = 0) readonly buffer Map {
    uint w, h;
    uint tiles[];
} map;

void main()
{
    int i = gl_VertexIndex;
    out_uv = vec2(map.tiles[gl_VertexIndex / 6])*0.1;

    vec3 pos = verts[i % 6] + vec3(i / 6 % map.w, i / (6*map.w), 1);
    gl_Position = camera.proj * camera.view * vec4(pos, 1);
}

#endif
///////////////////////////////////////////////////////////
#ifdef FRAGMENT

layout(location = 0) in vec2 in_uv;

layout(location = 0) out vec4 out_colour;

void main()
{
    out_colour = vec4(in_uv, 1, 1);
}

#endif ////////////////////////////////////////////////////
