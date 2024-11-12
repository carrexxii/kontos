#version 460

#ifdef VERTEX /////////////////////////////////////////////

layout(location = 0) in vec2  in_pos;
layout(location = 1) in uvec4 in_colour;

layout(location = 0) out vec4 out_colour;

void main()
{
    // out_colour  = in_colour;
    out_colour  = vec4(in_pos, 0, 0);
    gl_Position = vec4(in_pos, 0, 1);
}

#endif
///////////////////////////////////////////////////////////
#ifdef FRAGMENT

layout(location = 0) in vec4 in_colour;

layout(location = 0) out vec4 out_colour;

layout(set = 2, binding = 0) uniform sampler2D atlas;

void main()
{
    // out_colour = in_colour / 255;
    out_colour = vec4(texture(atlas, in_colour.xy).r);
}

#endif ////////////////////////////////////////////////////
