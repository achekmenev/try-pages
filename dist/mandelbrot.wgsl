struct UniformData {
  time: f32,
}

;

@group(0) @binding(0)
var<uniform> uniformData: UniformData;

struct VertexOutput {
  @builtin(position) pos: vec4f,
  @location(0) aux: vec2f,
}

;

@vertex
fn vertexMain(@builtin(vertex_index) VertexIndex: u32) -> VertexOutput {
  // Large triangle that covers the clip space
  // *
  // | \
  // +--+
  // |  | \
  // *--+--*
  const vertices = array<vec2f, 3>(vec2f(- 1, - 1), vec2f(3, - 1), vec2f(- 1, 3));

  var output: VertexOutput;
  output.pos = vec4f(vertices[VertexIndex], 0, 1);
  output.aux = output.pos.xy;
  return output;
}

override maxIterations: u32 = 128;

fn comp_mul(z1: vec2f, z2: vec2f) -> vec2f {
  return vec2f(z1.x * z2.x - z1.y * z2.y, z1.x * z2.y + z1.y * z2.x);
}

const escapeRadiusSquare = 4.0;
fn in_set(c: vec2f) -> bool {
  var z = vec2f(0.0);

  for (var i = 0u; i < maxIterations; i++) {
    if (dot(z, z) > escapeRadiusSquare) {
      return false;
    }

    z = comp_mul(z, z) + c;
  }

  return true;
}

struct EscapeInfo {
  iteration: u32,
  distSqr: f32,
}

fn escapeDistSqr(c: vec2f) -> EscapeInfo {
  var z = vec2f(0.0);
  var distSqr = 0.0;

  var i = 0u;
  for (; i < maxIterations; i++) {
    distSqr = dot(z, z);
    if (distSqr > escapeRadiusSquare) {
      break;
    }

    z = comp_mul(z, z) + c;
  }

  return EscapeInfo(i, distSqr);
}

// https://research.google/blog/turbo-an-improved-rainbow-colormap-for-visualization/
// https://gist.github.com/mikhailov-work/0d177465a8151eb6ede1768d51d476c7
fn TurboColormap(x: f32) -> vec3f {
  const kRedVec4 = vec4f(0.13572138, 4.61539260, - 42.66032258, 132.13108234);
  const kGreenVec4 = vec4f(0.09140261, 2.19418839, 4.84296658, - 14.18503333);
  const kBlueVec4 = vec4f(0.10667330, 12.64194608, - 60.58204836, 110.36276771);
  const kRedVec2 = vec2f(- 152.94239396, 59.28637943);
  const kGreenVec2 = vec2f(4.27729857, 2.82956604);
  const kBlueVec2 = vec2f(- 89.90310912, 27.34824973);

  let y = clamp(x, 0.0, 1.0);
  let v4 = vec4f(1.0, y, y * y, y * y * y);
  let v2 = v4.zw * v4.z;
  return vec3f(dot(v4, kRedVec4) + dot(v2, kRedVec2), dot(v4, kGreenVec4) + dot(v2, kGreenVec2), dot(v4, kBlueVec4) + dot(v2, kBlueVec2));
}

@fragment
fn fragmentMain(input: VertexOutput) -> @location(0) vec4f {
  let t = uniformData.time;
  let z = input.aux * 2.0;

  let escapeInfo = escapeDistSqr(z);
  let iter = escapeInfo.iteration;
  let dist = sqrt(escapeInfo.distSqr);

  var color = vec4f(0, 0, 0, 1);
  if (iter < maxIterations) {
    let smoothVal = f32(iter) - log2(log2(dist)) + 4.0;
    let t = smoothVal / f32(maxIterations);

    let finalColor = TurboColormap(t);

    color = vec4f(finalColor, 1.0);
  }

  return color;
}