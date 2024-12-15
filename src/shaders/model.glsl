#version 460

#ifdef VERTEX /////////////////////////////////////////////

layout(location = 0) in vec3 in_pos;
layout(location = 1) in vec2 in_uv;
layout(location = 2) in vec3 in_normal;

layout(location = 0) out vec2 out_uv;
layout(location = 1) out vec3 out_normal;

layout(set = 1, binding = 0) uniform Camera {
	mat4 proj;
	mat4 view;
} camera;

void main()
{
    out_uv      = in_uv;
    out_normal  = in_normal;
    gl_Position = camera.proj * camera.view * vec4(in_pos, 1);
}

#endif
///////////////////////////////////////////////////////////
#ifdef FRAGMENT

layout(location = 0) in vec2 in_uv;
layout(location = 1) in vec3 in_normal;

layout(location = 0) out vec4 out_colour;

layout(set = 2, binding = 0) uniform sampler2D diffuse;

void main()
{
    out_colour = texture(diffuse, in_uv);
    // out_colour = vec4(in_uv, 1, 1);
    // out_colour = vec4(in_normal, 1);
}

#endif ////////////////////////////////////////////////////
