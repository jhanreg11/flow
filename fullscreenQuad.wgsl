struct RenderParams {
  right: f32,
  up: f32,
}

@binding(0) @group(0) var<uniform> render_params : RenderParams;

struct VertexInput {
  @location(0) position : vec2<f32>,
  @location(1) quad_pos : vec2<f32>, // -1..+1
}

struct VertexOutput {
  @builtin(position) position : vec4<f32>,
  @location(0) particle_position: vec2<f32>,
}

@vertex
fn vs_main(in : VertexInput) -> VertexOutput {
  var position = in.position + in.quad_pos / vec2f(render_params.right, render_params.up) * 2.5;

  var out : VertexOutput;
  out.position = vec4(position, 0, 1);
  out.particle_position = in.position;
  return out;
}


// FRAGMENT
@fragment
fn fs_main(in : VertexOutput) -> @location(0) vec4<f32> {
  let c = (in.particle_position.xy + 1) / 2;
  return vec4f(c, 1.0 - c.y, 1.0); 
}