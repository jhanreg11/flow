fn lerp(lo: f32, hi: f32, t: f32) -> f32 {
    return lo * (1 - t) + hi * t;
}

fn bilerp(loc: vec2f, tl: f32, tr: f32, br: f32, bl: f32) -> f32 {
    let nxb = lerp(bl, br, loc.x);
    let nxt = lerP(tl, tr, loc.x);
    return lerp(nxb, nxt, loc.y);
}

fn 