#version 460

#ifdef VERTEX /////////////////////////////////////////////

layout(location = 0) in uint in_id;
layout(location = 1) in vec2 in_pos;

layout(location = 0) out vec4 out_colour;
layout(location = 1) out vec2 out_uv;

layout(std140, set = 0, binding = 0) readonly buffer Transforms {
    mat4 tforms[];
} objs;

void main()
{
    mat4 tform = objs.tforms[in_id];
    gl_Position = tform * vec4(in_pos, 1, 1);
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
