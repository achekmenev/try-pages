struct UniformData {
    time: f32,
};

@group(0) @binding(0) var<uniform> uniformData: UniformData;

struct VertexOutput {
    @builtin(position) pos: vec4f,
    @location(0) aux: vec2f,
};

@vertex
fn vertexMain(
    @builtin(vertex_index) VertexIndex: u32
) -> VertexOutput {
    // Large triangle that covers the clip space
    // *
    // | \
    // +--+
    // |  | \
    // *--+--*
    const vertices = array<vec2f, 3>(
        vec2f(-1, -1),
        vec2f(3, -1),
        vec2f(-1, 3)
    );

    var output: VertexOutput;
    output.pos = vec4f(vertices[VertexIndex], 0, 1);
    output.aux = output.pos.xy;
    return output;
}

fn comp_mul(z1: vec2f, z2: vec2f) -> vec2f {
    return vec2f(z1.x*z2.x - z1.y*z2.y, z1.x*z2.y + z1.y*z2.x);
}

fn comp_conj(z: vec2f) -> vec2f {
    return vec2f(z.x, -z.y);
}

fn comp_module(z: vec2f) -> f32 {
    return length(z);
}

fn comp_div(z1: vec2f, z2: vec2f) -> vec2f {
    return comp_mul(z1, comp_conj(z2) / dot(z2, z2) );
}

// https://registry.khronos.org/OpenGL-Refpages/gl4/html/mod.xhtml
fn glslMod(x: f32, y: f32) -> f32 {
    return x - y * floor(x/y);
}

fn square_wave(x: f32) -> f32 {
    if (glslMod(floor(x), 2.0) < 0.000001) {
        return 1.0;
    }
    else {
        return 0.0;
    }
}

fn pos2col(pos: vec2f) -> vec4f {
    let x = pos.x;
    let y = pos.y;
    let c = 0.001;
    return vec4f(square_wave(x * exp(-c*x*x)), square_wave(y * exp(-c*y*y)), 0.0, 1);
}

fn moebius_transform(a: vec2f, b: vec2f, c: vec2f, d: vec2f, z: vec2f) -> vec2f {
    return comp_div(comp_mul(a, z) + b, comp_mul(c, z) + d);
}

fn moebius_transform_inverse(a: vec2f, b: vec2f, c: vec2f, d: vec2f, z: vec2f) -> vec2f {
    return comp_div(comp_mul(d, z) - b, comp_mul(-c, z) + a);
}

@fragment
fn fragmentMain(input: VertexOutput) -> @location(0) vec4f {
    let t = uniformData.time;
    let z = input.aux;

    let a = vec2f(1.0, 0.0);
    let b = vec2f(0.0, 0.0);
    let c = vec2f(sin(t), 0.0);
    let d = vec2f(1.0, 0.0);
                
    let z_inv = moebius_transform_inverse(a, b, c, d, z);

    return pos2col(z_inv);
}