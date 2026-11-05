import { useEffect, useRef } from "react";

/**
 * A sheet of dots, seen head-on, that a few wandering strands lift towards the viewer into soft
 * folds like a drape of silk. Lifted cloth catches the light, the valleys fall into darkness.
 * The dot colour drifts slowly through a palette, so the whole drape keeps changing hue.
 * The pointer brushes dots aside and turns the view a little; clicks send a ripple across.
 */
export type SpectralDrapeProps = {
  /** Colours the dots drift through, one after another. */
  palette?: string[];
  /** Colour the crests reach. */
  highlight?: string;
  /** Seconds for one trip through the palette. */
  cycle?: number;
  /** Dots per area; 1 is a dot every ~5.6 CSS pixels. */
  density?: number;
  dotSize?: number;
  strands?: number;
  amplitude?: number;
  frequency?: number;
  thickness?: number;
  depth?: number;
  softness?: number;
  intensity?: number;
  colorShift?: number;
  tilt?: number;
  turn?: number;
  roll?: number;
  zoom?: number;
  flow?: number;
  speed?: number;
  interactive?: boolean;
  brush?: number;
  brushRadius?: number;
  parallax?: number;
  clickRipples?: boolean;
  seed?: number;
  /** How far lifted cloth slides upward; bunches the rows into bright fold lines. */
  shear?: number;
  /** Camera distance; lower is closer and more dramatic. */
  focal?: number;
  dpr?: number;
  className?: string;
};

const VERT = /* glsl */ `#version 300 es
precision highp float;
in vec2 aUV;
uniform float uTime, uFlow, uAspect, uAmp, uFreq, uThick, uDepth, uStrands, uSeed, uZoom;
uniform float uShear, uFocal;
uniform float uPx, uBrush, uBrushR, uCycle, uColorShift;
uniform mat3 uRot;
uniform vec2 uMouse;
uniform vec4 uRipples[8];
uniform vec3 uPal[6];
uniform int uPalN;
uniform vec3 uHi;
out vec3 vColor;
out float vAlpha;

float hash(float n) { return fract(sin(n * 127.1 + 311.7) * 43758.5453); }

// Each strand is a soft ridge that wanders across the sheet; their soft union is the lift.
float field(vec2 p, float t) {
  float keep = 1.0;
  for (int k = 0; k < 12; k++) {
    if (float(k) >= uStrands) break;
    float fk = float(k) * 1.37 + uSeed * 7.31;
    float ph = hash(fk) * 6.2832;
    float ph2 = hash(fk + 2.0) * 6.2832;
    float sp = 0.16 + 0.14 * hash(fk + 3.0);
    float slope = (hash(fk + 4.0) - 0.5) * 0.9;
    float base = -1.15 + 2.3 * (float(k) + 0.5) / uStrands + (hash(fk + 9.0) - 0.5) * 0.35;
    float c = base + slope * p.x
      + uAmp * 0.42 * sin(p.x * uFreq * (0.55 + 0.35 * hash(fk + 1.0)) + ph + t * sp)
      + uAmp * 0.13 * sin(p.x * uFreq * (1.6 + 0.6 * hash(fk + 6.0)) + ph2 - t * sp * 1.3);
    float w = uThick * 0.3 * (0.65 + 0.7 * hash(fk + 5.0))
      * (0.7 + 0.45 * sin(p.x * 0.9 + ph2 + t * 0.23));
    float d = (p.y - c) / max(w, 0.02);
    float lift = 0.5 + 0.5 * sin(p.x * (0.7 + 0.5 * hash(fk + 7.0)) + ph * 1.9 + t * 0.19);
    keep *= 1.0 - exp(-d * d) * lift;
  }
  return 1.0 - keep;
}

vec3 palette(float x) {
  float n = float(uPalN);
  float s = fract(x) * n;
  int i = int(floor(s));
  float f = smoothstep(0.0, 1.0, fract(s));
  return mix(uPal[i], uPal[(i + 1) % uPalN], f);
}

void main() {
  float t = uFlow;
  vec3 P = vec3(aUV.x * uAspect, aUV.y, 0.0);
  float H = field(P.xy, t);

  // Flanks flutter a little, like cloth edges in a draught.
  float flank = smoothstep(0.12, 0.45, H) * (1.0 - smoothstep(0.55, 0.95, H));
  float ruffle = sin(P.x * 23.0 + P.y * 5.0 + t * 2.4) * 0.5 + sin(P.x * 41.0 - t * 3.1) * 0.25;

  // Click ripples travel across the sheet and lift what they pass.
  float ring = 0.0;
  for (int i = 0; i < 8; i++) {
    vec4 rp = uRipples[i];
    if (rp.z <= 0.0) continue;
    float age = uTime - rp.z;
    if (age < 0.0 || age > 2.4) continue;
    float rd = length(P.xy - rp.xy * vec2(uAspect, 1.0));
    float band = exp(-pow((rd - age * 1.4) / 0.14, 2.0));
    ring += band * (1.0 - age / 2.4);
  }

  P.z = uDepth * (0.7 * H + 0.016 * ruffle * flank) + ring * 0.08;
  P.y += uDepth * uShear * (H + 0.012 * ruffle * flank);
  P = uRot * P;

  float focal = uFocal;
  float s = focal / (focal - P.z);
  vec2 sp = P.xy * s * uZoom;

  // The pointer brushes dots aside.
  vec2 m = uMouse * vec2(uAspect, 1.0);
  vec2 dm = sp - m;
  float md = length(dm);
  float r = uBrushR * 1.6;
  float push = exp(-(md * md) / (r * r)) * uBrush;
  sp += (md > 1e-4 ? dm / md : vec2(0.0)) * push * 0.075;

  sp.x /= uAspect;
  gl_Position = vec4(sp, 0.0, 1.0);

  float vis = smoothstep(0.1, 0.72, H);
  float crest = smoothstep(0.62, 1.0, H);
  float drift = uTime / uCycle;
  vec3 base = palette(drift + aUV.x * 0.24 + aUV.y * 0.1);
  vec3 col = mix(base * 1.15, uHi, crest * 0.55);
  col = mix(col, base, uColorShift * flank * 0.6);
  vColor = col;
  vAlpha = vis * (0.42 + 0.58 * crest) * (0.75 + (s - 1.0) * 1.3) + ring * 0.6 * (0.3 + vis);
  gl_PointSize = uPx * s * (1.0 + ring * 0.4);
}`;

const FRAG = /* glsl */ `#version 300 es
precision highp float;
in vec3 vColor;
in float vAlpha;
uniform float uSoft, uIntensity;
out vec4 outColor;
void main() {
  vec2 c = gl_PointCoord * 2.0 - 1.0;
  float d = length(c);
  if (d > 1.0) discard;
  float a = 1.0 - smoothstep(1.0 - max(uSoft, 0.05) * 0.9, 1.0, d);
  float k = clamp(a * vAlpha * uIntensity, 0.0, 1.0);
  outColor = vec4(vColor * k, k);
}`;

/** Electric indigo → violet → magenta → sunset orange, and back through violet. */
export const DRAPE_PALETTE = ["#5B4BFF", "#9A45FF", "#F0479B", "#FF8A50", "#C24DFF"];

function hexToRgb(hex: string): [number, number, number] {
  const h = hex.replace("#", "");
  const n = parseInt(h.length === 3 ? h.replace(/./g, "$&$&") : h, 16);
  return [((n >> 16) & 255) / 255, ((n >> 8) & 255) / 255, (n & 255) / 255];
}

/** Ry(turn) · Rx(tilt) · Rz(roll), column-major. */
function rotation(tilt: number, turn: number, roll: number): Float32Array {
  const r = Math.PI / 180;
  const [a, b, c] = [tilt * r, turn * r, roll * r];
  const cx = Math.cos(a), sx = Math.sin(a);
  const cy = Math.cos(b), sy = Math.sin(b);
  const cz = Math.cos(c), sz = Math.sin(c);
  const Rz = [cz, sz, 0, -sz, cz, 0, 0, 0, 1];
  const Rx = [1, 0, 0, 0, cx, sx, 0, -sx, cx];
  const Ry = [cy, 0, -sy, 0, 1, 0, sy, 0, cy];
  const mul = (A: number[], B: number[]) => {
    const o = new Array(9).fill(0);
    for (let col = 0; col < 3; col++)
      for (let row = 0; row < 3; row++)
        for (let k = 0; k < 3; k++) o[col * 3 + row] += A[k * 3 + row] * B[col * 3 + k];
    return o;
  };
  return new Float32Array(mul(Ry, mul(Rx, Rz)));
}

export default function SpectralDrape(props: SpectralDrapeProps) {
  const {
    density = 1,
    dpr = 2,
    className = "",
  } = props;
  const ref = useRef<HTMLCanvasElement>(null);
  const live = useRef(props);
  live.current = props;

  useEffect(() => {
    const canvas = ref.current!;
    const gl = canvas.getContext("webgl2", { premultipliedAlpha: true, antialias: false, alpha: true });
    if (!gl) return;
    const reduce = matchMedia("(prefers-reduced-motion: reduce)").matches;

    const compile = (type: number, src: string) => {
      const s = gl.createShader(type)!;
      gl.shaderSource(s, src);
      gl.compileShader(s);
      if (!gl.getShaderParameter(s, gl.COMPILE_STATUS)) console.error(gl.getShaderInfoLog(s));
      return s;
    };
    const prog = gl.createProgram()!;
    gl.attachShader(prog, compile(gl.VERTEX_SHADER, VERT));
    gl.attachShader(prog, compile(gl.FRAGMENT_SHADER, FRAG));
    gl.linkProgram(prog);
    gl.useProgram(prog);

    const names = [
      "uTime", "uFlow", "uAspect", "uAmp", "uFreq", "uThick", "uDepth", "uStrands", "uSeed", "uZoom",
      "uPx", "uBrush", "uBrushR", "uCycle", "uColorShift", "uRot", "uMouse", "uRipples", "uPal",
      "uPalN", "uHi", "uSoft", "uIntensity", "uShear", "uFocal",
    ] as const;
    const U = Object.fromEntries(names.map((n) => [n, gl.getUniformLocation(prog, n)])) as Record<
      (typeof names)[number],
      WebGLUniformLocation | null
    >;

    const buf = gl.createBuffer();
    const loc = gl.getAttribLocation(prog, "aUV");
    let count = 0;
    let cols = 0;
    let rows = 0;
    let spacing = 6;
    /** One dot every `spacing` CSS pixels, a little past the edges so lifted folds can spill in. */
    const buildGrid = (cssW: number, cssH: number) => {
      spacing = 5.6 / Math.sqrt(Math.max(0.2, density));
      const over = 1.04;
      const c = Math.max(20, Math.round((cssW * over) / spacing));
      const r = Math.max(12, Math.round((cssH * over) / spacing));
      if (c === cols && r === rows) return;
      cols = c;
      rows = r;
      const uv = new Float32Array(c * r * 2);
      let i = 0;
      for (let y = 0; y < r; y++)
        for (let x = 0; x < c; x++) {
          uv[i++] = ((x / (c - 1)) * 2 - 1) * over;
          uv[i++] = ((y / (r - 1)) * 2 - 1) * over;
        }
      gl.bindBuffer(gl.ARRAY_BUFFER, buf);
      gl.bufferData(gl.ARRAY_BUFFER, uv, gl.STATIC_DRAW);
      gl.enableVertexAttribArray(loc);
      gl.vertexAttribPointer(loc, 2, gl.FLOAT, false, 0, 0);
      count = c * r;
    };

    gl.enable(gl.BLEND);
    gl.blendFunc(gl.ONE, gl.ONE);
    gl.clearColor(0, 0, 0, 0);

    let w = 1, h = 1, scale = 1;
    const resize = () => {
      const rect = canvas.getBoundingClientRect();
      scale = Math.min(window.devicePixelRatio || 1, dpr);
      w = Math.max(1, Math.round(rect.width * scale));
      h = Math.max(1, Math.round(rect.height * scale));
      canvas.width = w;
      canvas.height = h;
      gl.viewport(0, 0, w, h);
      buildGrid(rect.width, rect.height);
    };
    resize();
    const ro = new ResizeObserver(resize);
    ro.observe(canvas);

    const mouse = { x: 9, y: 9, tx: 9, ty: 9, px: 0, py: 0, tpx: 0, tpy: 0 };
    const ripples = new Float32Array(8 * 4);
    let rippleIdx = 0;
    const toClip = (e: PointerEvent) => {
      const rect = canvas.getBoundingClientRect();
      return [
        ((e.clientX - rect.left) / rect.width) * 2 - 1,
        1 - ((e.clientY - rect.top) / rect.height) * 2,
      ] as const;
    };
    const onMove = (e: PointerEvent) => {
      if (live.current.interactive === false) return;
      const [x, y] = toClip(e);
      const inside = Math.abs(x) <= 1 && Math.abs(y) <= 1;
      mouse.tx = inside ? x : 9;
      mouse.ty = inside ? y : 9;
      mouse.tpx = Math.max(-1, Math.min(1, x));
      mouse.tpy = Math.max(-1, Math.min(1, y));
    };
    const onLeave = () => {
      mouse.tx = mouse.ty = 9;
      mouse.tpx = mouse.tpy = 0;
    };
    const onDown = (e: PointerEvent) => {
      if (live.current.clickRipples === false) return;
      const [x, y] = toClip(e);
      if (Math.abs(x) > 1 || Math.abs(y) > 1) return;
      ripples.set([x, y, clock(), 0], rippleIdx * 4);
      rippleIdx = (rippleIdx + 1) % 8;
    };
    window.addEventListener("pointermove", onMove, { passive: true });
    document.documentElement.addEventListener("pointerleave", onLeave);
    window.addEventListener("pointerdown", onDown, { passive: true });

    let visible = true;
    const io = new IntersectionObserver(([e]) => (visible = e.isIntersecting));
    io.observe(canvas);

    const t0 = performance.now();
    const clock = () => (performance.now() - t0) / 1000;
    let flow = 7.3; // start mid-motion, not from a symmetric pose
    let last = clock();
    let raf = 0;
    // ?tick keeps rendering in a hidden tab (for screenshots while tuning).
    const tick = new URLSearchParams(location.search).has("tick");

    const frame = () => {
      raf = tick ? window.setTimeout(frame, 16) : requestAnimationFrame(frame);
      if (!tick && (!visible || document.hidden)) {
        last = clock();
        return;
      }
      const p = live.current;
      const speed = p.speed ?? 1;
      const t = clock();
      const dt = Math.min(0.05, t - last);
      last = t;
      if (!reduce) flow += dt * (p.flow ?? 1) * speed * 0.55;

      const k = 1 - Math.exp(-dt * 7);
      const jump = (a: number, b: number) => Math.abs(a - b) > 4;
      mouse.x = jump(mouse.tx, mouse.x) ? mouse.tx : mouse.x + (mouse.tx - mouse.x) * k;
      mouse.y = jump(mouse.ty, mouse.y) ? mouse.ty : mouse.y + (mouse.ty - mouse.y) * k;
      const kp = 1 - Math.exp(-dt * 1.8);
      mouse.px += (mouse.tpx - mouse.px) * kp;
      mouse.py += (mouse.tpy - mouse.py) * kp;

      const palette = (p.palette ?? DRAPE_PALETTE).slice(0, 6);
      const pal = palette.flatMap(hexToRgb);
      gl.uniform3fv(U.uPal, new Float32Array([...pal, ...new Array(18 - pal.length).fill(0)]));
      gl.uniform1i(U.uPalN, palette.length);
      gl.uniform3fv(U.uHi, hexToRgb(p.highlight ?? "#F1E8FF"));
      gl.uniform1f(U.uTime, t * speed);
      gl.uniform1f(U.uFlow, flow);
      gl.uniform1f(U.uAspect, w / h);
      gl.uniform1f(U.uAmp, p.amplitude ?? 1);
      gl.uniform1f(U.uFreq, p.frequency ?? 1);
      gl.uniform1f(U.uThick, p.thickness ?? 0.7);
      gl.uniform1f(U.uDepth, p.depth ?? 1);
      gl.uniform1f(U.uStrands, Math.max(1, Math.min(12, p.strands ?? 10)));
      gl.uniform1f(U.uSeed, p.seed ?? 3);
      gl.uniform1f(U.uZoom, p.zoom ?? 1);
      gl.uniform1f(U.uPx, spacing * scale * 0.36 * (p.dotSize ?? 1));
      gl.uniform1f(U.uBrush, p.interactive === false ? 0 : (p.brush ?? 1));
      gl.uniform1f(U.uBrushR, p.brushRadius ?? 0.2);
      gl.uniform1f(U.uCycle, Math.max(1, p.cycle ?? 42));
      gl.uniform1f(U.uColorShift, p.colorShift ?? 0.3);
      gl.uniform1f(U.uSoft, p.softness ?? 0.6);
      gl.uniform1f(U.uShear, p.shear ?? 0.3);
      gl.uniform1f(U.uFocal, p.focal ?? 1.8);
      gl.uniform1f(U.uIntensity, p.intensity ?? 1);
      const par = p.parallax ?? 1;
      gl.uniformMatrix3fv(
        U.uRot,
        false,
        rotation((p.tilt ?? 0) - mouse.py * 5 * par, (p.turn ?? 0) + mouse.px * 7 * par, p.roll ?? 0),
      );
      gl.uniform2f(U.uMouse, mouse.x, mouse.y);
      gl.uniform4fv(U.uRipples, ripples);

      gl.clear(gl.COLOR_BUFFER_BIT);
      gl.drawArrays(gl.POINTS, 0, count);
    };
    frame();

    return () => {
      cancelAnimationFrame(raf);
      clearTimeout(raf);
      ro.disconnect();
      io.disconnect();
      window.removeEventListener("pointermove", onMove);
      document.documentElement.removeEventListener("pointerleave", onLeave);
      window.removeEventListener("pointerdown", onDown);
      gl.getExtension("WEBGL_lose_context")?.loseContext();
    };
  }, [density, dpr]);

  return <canvas ref={ref} className={`block h-full w-full ${className}`} aria-hidden />;
}
