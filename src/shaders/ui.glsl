#version 460

#ifdef VERTEX /////////////////////////////////////////////

layout(location = 0) in vec2  in_pos;
layout(location = 1) in vec2  in_uv;
layout(location = 2) in uvec4 in_colour;

layout(location = 0) out vec4 out_colour;
layout(location = 1) out vec2 out_uv;

layout(set = 1, binding = 0) uniform Camera {
	mat4 proj;
} camera;

void main()
{
    out_colour  = vec4(in_colour) / 255;
    out_uv      = in_uv;
    gl_Position = camera.proj * vec4(in_pos, 0, 1);
}

#endif
///////////////////////////////////////////////////////////
#ifdef FRAGMENT

layout(location = 0) in vec4 in_colour;
layout(location = 1) in vec2 in_uv;

layout(location = 0) out vec4 out_colour;

layout(set = 2, binding = 0) uniform sampler2D atlas;

void main()
{
    out_colour = in_colour * texture(atlas, in_uv).aaaa;
}

#endif ////////////////////////////////////////////////////
