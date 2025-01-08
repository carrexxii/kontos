#version 460

#ifdef VERTEX /////////////////////////////////////////////

layout(location = 0) in vec2 in_pos;

layout(location = 0) out vec4 out_colour;
layout(location = 1) out vec2 out_uv;

void main()
{
    gl_Position = vec4(in_pos, 1, 1);
}

#endif
///////////////////////////////////////////////////////////
#ifdef FRAGMENT

layout(location = 0) out vec4 out_colour;

void main()
{
    out_colour = vec4(0.5, 0, 0, 1);
}

#endif ////////////////////////////////////////////////////
