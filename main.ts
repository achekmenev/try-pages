import { loadText } from '../utils/util.js';
// Load shader code from external file
const shaderCode = await loadText('./moebius.wgsl');

// Search the DOM for the first <canvas> element
const canvas = document.querySelector("canvas");
if (!canvas) throw new Error('Canvas not found');

// Canvas resolution scaling sets the actual pixel resolution. E.g.
// 2.0 for Retina/HiDPI displays (MacBooks, modern phones)
// 1.25, 1.5, etc. for Windows scaling
{
  const devicePixelRatio = window.devicePixelRatio;
  canvas.width = canvas.clientWidth * devicePixelRatio;
  canvas.height = canvas.clientHeight * devicePixelRatio;
}

// WebGPU code starts here

// WebGPU device initialization
async function getDevice(): Promise<GPUDevice> {
  if (!navigator.gpu) throw new Error("WebGPU is not supported on this browser.");
  // https://gpuweb.github.io/gpuweb/#adapter-selection
  const adapter = await navigator.gpu.requestAdapter({
    featureLevel: 'compatibility',
  });
  // Use optional chaining
  const device = await adapter?.requestDevice();
  if (!device) throw new Error('Failed to get device');

  return device;
}

const device = await getDevice();

// Canvas configuration
const context = canvas.getContext("webgpu");
if (!context) throw new Error('Failed to get context');
const canvasFormat = navigator.gpu.getPreferredCanvasFormat();
context.configure({
    device: device,
    format: canvasFormat,
});


// Create the shader that will render the quad.
const quadShaderModule = device.createShaderModule({
    label: "Quad shader",
    code: shaderCode
});
// Create a pipeline that renders the quad.
const quadPipeline = device.createRenderPipeline({
    label: "Quad pipeline",
    layout: "auto",
    vertex: {
        module: quadShaderModule,
        entryPoint: "vertexMain",
    },
    fragment: {
        module: quadShaderModule,
        entryPoint: "fragmentMain",
        targets: [{
            format: canvasFormat
        }]
    },
    primitive: {
        topology: 'triangle-strip',
  },
});

//// Bind group for uniforms
//
// Create a buffer for the uniform values
const uniformBufferSize = 4;  // time is the one 32bit float (4bytes)
const uniformBuffer = device.createBuffer({
    label: 'uniforms for shader',
    size: uniformBufferSize,
    usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST,
});
// Create a typed array to hold the values for the uniforms in JavaScript
const uniformValues = new Float32Array(uniformBufferSize / 4);
// Offsets to the various uniform values in float32 indices
const timeOffset = 0;
const bindGroup = device.createBindGroup({
    label: 'shader bind group',
    layout: quadPipeline.getBindGroupLayout(0),
    entries: [{
        binding: 0,
        resource: { buffer: uniformBuffer }
    }],
});
//
//// Bind group for uniforms

// Render cycle
let time = 0.0;
function update() {
    time += 0.005;
    uniformValues.set([time], timeOffset);

    // copy the values from JavaScript to the GPU
    device.queue.writeBuffer(uniformBuffer, 0, uniformValues);

    // Clear the canvas with a render pass
    const encoder = device.createCommandEncoder();

    const pass = encoder.beginRenderPass({
        colorAttachments: [{
            view: context!.getCurrentTexture().createView(),
            loadOp: "clear",
            clearValue: { r: 0, g: 0, b: 0.4, a: 1.0 },
            storeOp: "store",
        }]
    });

    // Draw the square.
    pass.setPipeline(quadPipeline);
    pass.setBindGroup(0, bindGroup);
    // We draw one (too big for the screen) triangle
    // https://webgpufundamentals.org/webgpu/lessons/webgpu-large-triangle-to-cover-clip-space.html
    pass.draw(3);

    pass.end();

    device.queue.submit([encoder.finish()]);
}
setInterval(update, 10);