#version 460

#ifdef VERTEX /////////////////////////////////////////////

layout(location = 0) in vec3 in_pos;
layout(location = 1) in vec2 in_uv;
layout(location = 2) in vec3 in_normal;

layout(location = 0) out vec2 out_uv;
layout(location = 1) out vec3 out_normal;

void main()
{
    out_uv      = in_uv;
    out_normal  = in_normal;
    gl_Position = vec4(in_pos, 1);
}

#endif
///////////////////////////////////////////////////////////
#ifdef FRAGMENT

layout(location = 0) in vec2 in_uv;
layout(location = 1) in vec3 in_normal;

layout(location = 0) out vec4 out_colour;

void main()
{
    out_colour = vec4(in_normal, 1.0);
}

#endif ////////////////////////////////////////////////////
