fn permute(x: vec4f) -> vec4f {return ((x*34.0)+1.0)*x % 289.0;}
fn permuteF(x: f32) -> f32 {return floor(((x*34.0)+1.0)*x % 289.0);}
fn taylorInvSqrt(r: vec4f) -> vec4f {return 1.79284291400159 - 0.85373472095314 * r;}
fn taylorInvSqrtF(r: f32) -> f32 {return 1.79284291400159 - 0.85373472095314 * r;}

fn lessThan(x: vec4f, y: vec4f) -> vec4f {
  var out = vec4f(0, 0, 0, 0);
  if (x.x < y.x) {
    out.x = 1;
  }
  if (x.y < y.y) {
    out.y = 1;
  }
  if (x.z < y.z) {
    out.z = 1;
  }
  if (x.w < y.w) {
    out.w = 1;
  }

  return x;
}

fn grad4(j: f32, ip: vec4f) -> vec4f{
  var ones = vec4f(1.0, 1.0, 1.0, -1.0);
  var p = vec4f(floor(fract(j * ip.xyz) * 7.0) * ip.z - 1.0, 0);
  p.w = 1.5 - dot(abs(p.xyz), ones.xyz);
  var s = vec4(lessThan(p, vec4(0.0)));
  p = vec4f(vec3f(p.xyz + (s.xyz*2.0 - 1.0) * s.www), p.w);

  return p;
}

fn snoise(v: vec4f) -> f32 {
  var C = vec2( 0.138196601125010504,  // (5 - sqrt(5))/20  G4
                        0.309016994374947451); // (sqrt(5) - 1)/4   F4
// First corner
  var i  = floor(v + dot(v, C.yyyy) );
  var x0 = v -   i + dot(i, C.xxxx);

// Other corners

// Rank sorting originally contributed by Bill Licea-Kane, AMD (formerly ATI)
  var i0 = vec4f(0, 0, 0, 0);

  var isX = step( x0.yzw, x0.xxx );
  var isYZ = step( x0.zww, x0.yyz );
//  i0.x = dot( isX, vec3( 1.0 ) );
  i0.x = isX.x + isX.y + isX.z;
  i0.y = 1.0 - isX.x;
  i0.z = 1.0 - isX.y;
  i0.w = 1.0 - isX.z;

//  i0.y += dot( isYZ.xy, vec2( 1.0 ) );
  i0.y = i0.y + isYZ.x + isYZ.y;
  i0.z = i0.z + 1.0 - isYZ.x;
  i0.w = i0.w + 1.0 - isYZ.y;

  i0.z = i0.z + isYZ.z;
  i0.w += i0.w + 1.0 - isYZ.z;

  // i0 now contains the unique values 0,1,2,3 in each channel
  var i3 = clamp( i0, vec4f(0.0), vec4f(1.0));
  var i2 = clamp( i0-1.0, vec4f(0.0), vec4f(1.0));
  var i1 = clamp( i0-2.0, vec4f(0.0), vec4f(1.0));

  //  x0 = x0 - 0.0 + 0.0 * C 
  var x1 = x0 - i1 + 1.0 * C.xxxx;
  var x2 = x0 - i2 + 2.0 * C.xxxx;
  var x3 = x0 - i3 + 3.0 * C.xxxx;
  var x4 = x0 - 1.0 + 4.0 * C.xxxx;

// Permutations
  i = i % 289.0; 
  var j0 = permuteF( permuteF( permuteF( permuteF(i.w) + i.z) + i.y) + i.x);
  var j1 = permute( permute( permute( permute (
             i.w + vec4(i1.w, i2.w, i3.w, 1.0 ))
           + i.z + vec4(i1.z, i2.z, i3.z, 1.0 ))
           + i.y + vec4(i1.y, i2.y, i3.y, 1.0 ))
           + i.x + vec4(i1.x, i2.x, i3.x, 1.0 ));
// Gradients
// ( 7*7*6 points uniformly over a cube, mapped onto a 4-octahedron.)
// 7*7*6 = 294, which is close to the ring size 17*17 = 289.

  var ip = vec4(1.0/294.0, 1.0/49.0, 1.0/7.0, 0.0) ;

  var p0 = grad4(j0,   ip);
  var p1 = grad4(j1.x, ip);
  var p2 = grad4(j1.y, ip);
  var p3 = grad4(j1.z, ip);
  var p4 = grad4(j1.w, ip);

// Normalise gradients
  var norm = taylorInvSqrt(vec4(dot(p0,p0), dot(p1,p1), dot(p2, p2), dot(p3,p3)));
  p0 = p0 * norm.x;
  p1 = p1 * norm.y;
  p2 = p2 * norm.z;
  p3 = p3 * norm.w;
  p4 = p4 * taylorInvSqrtF(dot(p4,p4));

// Mix contributions from the five corners
  var m0 = max(0.6 - vec3(dot(x0,x0), dot(x1,x1), dot(x2,x2)), vec3f(0.0));
  var m1 = max(0.6 - vec2(dot(x3,x3), dot(x4,x4)            ), vec2f(0.0));
  m0 = m0 * m0;
  m1 = m1 * m1;
  return 49.0 * ( dot(m0*m0, vec3( dot( p0, x0 ), dot( p1, x1 ), dot( p2, x2 )))
               + dot(m1*m1, vec2( dot( p3, x3 ), dot( p4, x4 ) ) ) ) ;

}

/* discontinuous pseudorandom uniformly distributed in [-0.5, +0.5]^3 */
fn random3(c: vec3f) -> vec3f {
	var j = 4096.0*sin(dot(c,vec3(17.0, 59.4, 15.0)));
	var r = vec3f(fract(512.0*j),  fract(512.0*.125*j), fract(512.0*.125*.125*j));
	return r-0.5;
}


/* 3d simplex noise */
fn simplex3d(p: vec3f) -> f32 {
  /* skew constants for 3d simplex functions */
  var F3 =  0.3333333;
  var G3 =  0.1666667;
	 /* 1. find current tetrahedron T and it's four vertices */
	 /* s, s+i1, s+i2, s+1.0 - absolute skewed (integer) coordinates of T vertices */
	 /* x, x1, x2, x3 - unskewed coordinates of p relative to each of T vertices*/
	 
	 /* calculate s and x */
	 var s = floor(p + dot(p, vec3(F3)));
	 var x = p - s + dot(s, vec3(G3));
	 
	 /* calculate i1 and i2 */
	 var e = step(vec3(0.0), x - x.yzx);
	 var i1 = e*(1.0 - e.zxy);
	 var i2 = 1.0 - e.zxy*(1.0 - e);
	 	
	 /* x1, x2, x3 */
	 var x1 = x - i1 + G3;
	 var x2 = x - i2 + 2.0*G3;
	 var x3 = x - 1.0 + 3.0*G3;
	 
	 /* 2. find four surflets and store them in d */
   var w = vec4f(0, 0, 0, 0);
   var d = vec4f(0, 0, 0, 0);
	 
	 /* calculate surflet weights */
	 w.x = dot(x, x);
	 w.y = dot(x1, x1);
	 w.z = dot(x2, x2);
	 w.w = dot(x3, x3);
	 
	 /* w fades from 0.6 at the center of the surflet to 0.0 at the margin */
	 w = max(0.6 - w, vec4f(0, 0, 0, 0));
	 
	 /* calculate surflet components */
	 d.x = dot(random3(s), x);
	 d.y = dot(random3(s + i1), x1);
	 d.z = dot(random3(s + i2), x2);
	 d.w = dot(random3(s + 1.0), x3);
	 
	 /* multiply d by w^4 */
	 w = w * w * w * w;
	 d = w * d;
	 
	 /* 3. return the sum of the four surflets */
	 return dot(d, vec4f(52, 52, 52, 52));
}


struct SimulationParams {
  delta_t : f32,
  delta_iter: f32,
  magnitude : f32
}

struct Particle {
  position : vec2<f32>,
  velocity : vec2<f32>,
}

struct Particles {
  particles: array<Particle>
}

struct Iter {
  val: f32
}

@binding(0) @group(0) var<uniform> sim_params : SimulationParams;
@binding(1) @group(0) var<storage, read_write> data : Particles;
@binding(2) @group(0) var<storage, read_write> iter : Iter;

@compute @workgroup_size(8)
fn simulate_step(@builtin(global_invocation_id) global_invocation_id: vec3<u32>) {
  let idx = global_invocation_id.x;
  var particle = data.particles[idx];

  let theta = simplex3d(vec3f(particle.position, iter.val) * 2) *  2 * 3.14159;
  particle.velocity = particle.velocity + sim_params.magnitude * vec2f(cos(theta), sin(theta));
  particle.velocity = clamp(particle.velocity, vec2f(-.05), vec2f(.05));
  particle.position = particle.position + sim_params.delta_t * particle.velocity;

  if (particle.position.x >= 1.0) {
    particle.position.x = -1.0 + particle.position.x % 1;
  }
  if (particle.position.y >= 1.0) {
    particle.position.y = -1.0 + particle.position.y % 1;
  }

  if (particle.position.x <= -1.0) {
    particle.position.x = 1.0 + particle.position.x % 1;
  }
  if (particle.position.y <= -1.0) {
    particle.position.y = 1.0 + particle.position.y % 1;
  }

  iter.val = iter.val + sim_params.delta_iter;
  data.particles[idx] = particle;
}
