#version 460

#ifdef VERTEX /////////////////////////////////////////////

layout(location = 0) in uint  in_id;
layout(location = 1) in vec2  in_pos;
layout(location = 2) in uvec4 in_colour;

layout(location = 0) out vec4 out_colour;

layout(std140, set = 0, binding = 0) readonly buffer Transforms {
    mat4 tforms[];
} objs;

layout(set = 1, binding = 0) uniform Camera {
    mat4 proj;
    mat4 view;
} camera;

void main()
{
    out_colour = vec4(in_colour) / 255;

    mat4 tform = objs.tforms[in_id];
    gl_Position = camera.proj * camera.view * tform * vec4(in_pos, 1, 1);
}

#endif
///////////////////////////////////////////////////////////
#ifdef FRAGMENT

layout(location = 0) in vec4 in_colour;

layout(location = 0) out vec4 out_colour;

void main()
{
    out_colour = in_colour;
}

#endif ////////////////////////////////////////////////////
