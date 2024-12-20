#version 460

#ifdef VERTEX /////////////////////////////////////////////

layout(location = 0) out vec2 out_uv;

layout(set = 1, binding = 0) uniform Camera {
	mat4 proj;
	mat4 view;
} camera;

vec3 verts[6] = {
    vec3(0, 0, 0), vec3(1, 0, 0), vec3(0, 1, 0),
    vec3(0, 1, 0), vec3(1, 0, 0), vec3(1, 1, 0),
};

void main()
{
    out_uv = vec2(0, 0);
    vec4 pos = vec4(verts[gl_VertexIndex % 6] + verts[gl_VertexIndex % 6]*gl_VertexIndex, 1);
    gl_Position = camera.proj * camera.view * pos;
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
