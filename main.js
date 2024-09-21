const renderRes = await fetch('./fullscreenQuad.wgsl');
const renderShaders = await renderRes.text();
const simRes = await fetch('./simulate.wgsl');
const computeShaders = await simRes.text();

const canvas = document.querySelector("canvas");
canvas.style.width = "100vw";
canvas.style.height = "100vh";
canvas.width = canvas.offsetWidth;
canvas.height = canvas.offsetHeight;

if (!navigator.gpu) {
  throw new Error("WebGPU not supported on this browser.");
}
const adapter = await navigator.gpu.requestAdapter();
if (!adapter) {
  throw new Error("No appropriate GPUAdapter found.");
}
const device = await adapter.requestDevice();
const context = canvas.getContext('webgpu');
const format = navigator.gpu.getPreferredCanvasFormat();
context.configure({
  device,
  format
});


const simulationParams = {
  simulate: true,
  delta_t: .01,
  delta_iter: .0004,
  magnitude: .1
};

const NUM_PARTICLES = 5000;
const PARTICLE_BYTES = 
2 * 4 + // position
2 * 4 + // velocity
0;

const particlesBuffer = device.createBuffer({
  size: NUM_PARTICLES * PARTICLE_BYTES,
  usage: GPUBufferUsage.VERTEX | GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_DST,
});
const particlesData = new Float32Array(NUM_PARTICLES * PARTICLE_BYTES / 4);
for (let i = 0; i < particlesData.length; i++) {
  particlesData[i] = i % 4 < 2 ? Math.random() * 2 - 1 : 0;
}
device.queue.writeBuffer(particlesBuffer, 0, particlesData);

const bindGroupLayout = device.createBindGroupLayout({
  label: "Render Bind Group Layout",
  entries: [{
    binding: 0,
    visibility:  GPUShaderStage.VERTEX,
    buffer: {}
  }]
});
const pipelineLayout = device.createPipelineLayout({
  label: "render pipeline layout",
  bindGroupLayouts: [ bindGroupLayout ]
});

const renderPipeline = device.createRenderPipeline({
  layout: pipelineLayout,
  vertex: {
    module: device.createShaderModule({
      code: renderShaders,
    }),
    entryPoint: 'vs_main',
    buffers: [
      {
        // instanced particles buffer
        arrayStride: PARTICLE_BYTES,
        stepMode: 'instance',
        attributes: [
          {
            // position
            shaderLocation: 0,
            offset: 0,
            format: 'float32x2',
          },
        ],
      },
      {
        // quad vertex buffer
        arrayStride: 2 * 4, // vec2<f32>
        stepMode: 'vertex',
        attributes: [
          {
            // vertex positions
            shaderLocation: 1,
            offset: 0,
            format: 'float32x2',
          },
        ],
      },
    ],
  },
  fragment: {
    module: device.createShaderModule({
      code: renderShaders,
    }),
    entryPoint: 'fs_main',
    targets: [
      {
        format: format,
        blend: {
          color: {
            srcFactor: 'src-alpha',
            dstFactor: 'one',
            operation: 'add',
          },
          alpha: {
            srcFactor: 'zero',
            dstFactor: 'one',
            operation: 'add',
          },
        },
      },
    ],
  },
  primitive: {
    topology: 'triangle-list',
  },
});

const uniformBufferSize =
  4 + // right : u32A
  4 + // up : u32
  0;
const uniformBuffer = device.createBuffer({
  size: uniformBufferSize,
  usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST,
});
device.queue.writeBuffer(
  uniformBuffer,
  0,
  new Float32Array([
    canvas.offsetWidth,
    canvas.offsetHeight
  ])
);


const uniformBindGroup = device.createBindGroup({
  layout: renderPipeline.getBindGroupLayout(0),
  entries: [
    {
      binding: 0,
      resource: {
        buffer: uniformBuffer,
      },
    },
  ],
});


const vertexData = new Float32Array([
  //   X,    Y,
    -0.8, -0.8, // Triangle 1 (Blue)
     0.8, -0.8,
     0.8,  0.8,
  
    -0.8, -0.8, // Triangle 2 (Red)
     0.8,  0.8,
    -0.8,  0.8,
  ]);

const quadVertexBuffer = device.createBuffer({
  size: vertexData.byteLength, // 6x vec2<f32>
  usage: GPUBufferUsage.VERTEX | GPUBufferUsage.COPY_DST,
});
device.queue.writeBuffer(quadVertexBuffer, 0, vertexData);

const simulationUBOBufferSize =
  1 * 4 + // delta_iter 
  1 * 4 + // delta_t
  1 * 4 + // magnitude
  0;
const simulationUBOBuffer = device.createBuffer({
  size: simulationUBOBufferSize,
  usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST,
});
device.queue.writeBuffer(
  simulationUBOBuffer,
  0,
  new Float32Array([
    simulationParams.simulate ? simulationParams.delta_t : 0.0,
    simulationParams.simulate ? simulationParams.delta_iter : 0.0,
    simulationParams.simulate ? simulationParams.magnitude : 0.0,
  ])
);

const iterBuffer = device.createBuffer({
  size: 4,
  usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_DST,
});
device.queue.writeBuffer(iterBuffer, 0, new Float32Array([0]));

const computePipeline = device.createComputePipeline({
  layout: 'auto',
  compute: {
    module: device.createShaderModule({
      code: computeShaders,
    }),
    entryPoint: 'simulate_step',
  },
});
const computeBindGroup = device.createBindGroup({
  layout: computePipeline.getBindGroupLayout(0),
  entries: [
    {
      binding: 0,
      resource: {
        buffer: simulationUBOBuffer,
      },
    },
    {
      binding: 1,
      resource: {
        buffer: particlesBuffer,
        offset: 0,
        size: NUM_PARTICLES * PARTICLE_BYTES
      },
    },
    {
      binding: 2,
      resource: {
        buffer: iterBuffer,
      }
    }
  ],
});

function writeFps(curr, last) {
  document.getElementById('FPS').innerHTML = Math.round(1 / (curr - last) * 1000);
}

let last = performance.now();
function frame() {
  const commandEncoder = device.createCommandEncoder();
  {
    const passEncoder = commandEncoder.beginComputePass();
    passEncoder.setPipeline(computePipeline);
    passEncoder.setBindGroup(0, computeBindGroup);
    passEncoder.dispatchWorkgroups(Math.ceil(NUM_PARTICLES / 8));
    passEncoder.end();
  }
  {
    const passEncoder = commandEncoder.beginRenderPass({
      colorAttachments: [
        {
          view: context.getCurrentTexture().createView(), 
          loadOp: 'clear',
          clearValue: { r: 0.0, g: 0.0, b: 0.0, a: 1.0 },
          storeOp: 'store',
        },
      ],
    });
    passEncoder.setPipeline(renderPipeline);
    passEncoder.setBindGroup(0, uniformBindGroup);
    passEncoder.setVertexBuffer(0, particlesBuffer);
    passEncoder.setVertexBuffer(1, quadVertexBuffer);
    passEncoder.draw(6, NUM_PARTICLES);
    passEncoder.end();
  }

  device.queue.submit([commandEncoder.finish()]);
  const curr = performance.now();
  writeFps(curr, last);
  last = curr;
  requestAnimationFrame(frame);
}
requestAnimationFrame(frame);