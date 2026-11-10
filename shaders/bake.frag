#version 440
// =====================================================================
// bake.frag - runs ONCE per body at startup (ShaderEffectSource live:false)
// Renders an equirectangular surface map from 3D procedural math.
// Output channels:
//   Ash Twin        (2): rgb = rock/spire albedo,           a = rock height (sand drawn in planet.frag)
//   Ember Twin      (3): rgb = canyon/mesa albedo,          a = 3D height
//   Timber Hearth   (4): rgb = crater/forest/geyser albedo, a = 3D height
//   Attlerock       (5): rgb = lunar regolith/crater albedo,a = 3D height
//   Brittle Hollow  (6): rgb = crust/canyon/glacier albedo, a = 3D height & collapse
//   Hollow's Lantern(7): rgb = volcano/lava caldera albedo, a = 3D cone height
//   Giant's Deep    (8): rgb = ocean/cloud/storm albedo,    a = height (unchanged)
//   Dark Bramble    (9): r = plate, g = tone, b = vine,     a = height
//   Interloper     (10): rgb = stone nose / ice albedo,     a = height
// =====================================================================

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 bakeParams; // x = bodyType, y = seed
};

const float PI  = 3.14159265;
const float TAU = 6.2831853;

const float EM_CHASM_W   = 0.17;   // Ember: chasm half-width (0.17 ~ 10 deg either side of the equator)
const float EM_WALL_W    = 0.05;   // Ember: chasm wall slope width
const float EM_PLATE_FREQ = 1.1;   // Ember: plate size (lower = bigger plates)
const float ASH_SPIRE_FREQ = 5.0;  // Ash: spire spacing

vec3 uvToDir(vec2 uv) {
    float lon = (uv.x - 0.5) * TAU;
    float lat = (uv.y - 0.5) * PI;
    return vec3(cos(lat) * cos(lon), sin(lat), cos(lat) * sin(lon));
}

vec3 hash33(vec3 p3) {
    p3 = fract(p3 * vec3(.1031, .1030, .0973));
    p3 += dot(p3, p3.yxz + 33.33);
    return fract((p3.xxy + p3.yxx) * p3.zyx);
}

float hash13(vec3 p3) {
    p3 = fract(p3 * .1031);
    p3 += dot(p3, p3.zyx + 31.32);
    return fract((p3.x + p3.y) * p3.z);
}

float gnoise(vec3 p) {
    vec3 i = floor(p);
    vec3 f = fract(p);
    vec3 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);

    float v000 = dot(hash33(i + vec3(0.0, 0.0, 0.0)) * 2.0 - 1.0, f - vec3(0.0, 0.0, 0.0));
    float v100 = dot(hash33(i + vec3(1.0, 0.0, 0.0)) * 2.0 - 1.0, f - vec3(1.0, 0.0, 0.0));
    float v010 = dot(hash33(i + vec3(0.0, 1.0, 0.0)) * 2.0 - 1.0, f - vec3(0.0, 1.0, 0.0));
    float v110 = dot(hash33(i + vec3(1.0, 1.0, 0.0)) * 2.0 - 1.0, f - vec3(1.0, 1.0, 0.0));
    float v001 = dot(hash33(i + vec3(0.0, 0.0, 1.0)) * 2.0 - 1.0, f - vec3(0.0, 0.0, 1.0));
    float v101 = dot(hash33(i + vec3(1.0, 0.0, 1.0)) * 2.0 - 1.0, f - vec3(1.0, 0.0, 1.0));
    float v011 = dot(hash33(i + vec3(0.0, 1.0, 1.0)) * 2.0 - 1.0, f - vec3(0.0, 1.0, 1.0));
    float v111 = dot(hash33(i + vec3(1.0, 1.0, 1.0)) * 2.0 - 1.0, f - vec3(1.0, 1.0, 1.0));

    return mix(mix(mix(v000, v100, u.x), mix(v010, v110, u.x), u.y),
               mix(mix(v001, v101, u.x), mix(v011, v111, u.x), u.y), u.z);
}

const mat3 ROT = mat3( 0.00,  0.80,  0.60,
                      -0.80,  0.36, -0.48,
                      -0.60, -0.48,  0.64);

float fbm(vec3 p, int oct) {
    float v = 0.0;
    float a = 0.5;
    float s = 0.0;
    for (int i = 0; i < oct; i++) {
        v += a * gnoise(p);
        s += a;
        p = ROT * p * 2.02 + vec3(1.7, 9.2, 3.3);
        a *= 0.5;
    }
    return 0.5 + 0.5 * clamp(v / s * 2.2, -1.0, 1.0);
}

float ridgedFbm(vec3 p, int oct) {
    float v = 0.0;
    float a = 0.5;
    float s = 0.0;
    float w = 1.0;
    for (int i = 0; i < oct; i++) {
        float n = 1.0 - abs(gnoise(p) * 2.0);
        n = n * n * w;
        w = clamp(n * 1.8, 0.2, 1.0);
        v += n * a;
        s += a;
        p = ROT * p * 2.15 + vec3(2.3, 5.1, 8.7);
        a *= 0.5;
    }
    return clamp(v / s, 0.0, 1.0);
}

struct Vor {
    float f1;
    float f2;
    vec3  c;
    vec3  id;
};

Vor voronoi(vec3 p) {
    vec3 ip = floor(p);
    vec3 fp = fract(p);
    Vor r;
    r.f1 = 8.0;
    r.f2 = 8.0;
    r.c  = vec3(0.0);
    r.id = vec3(0.0);
    for (int k = -1; k <= 1; k++) {
        for (int j = -1; j <= 1; j++) {
            for (int i = -1; i <= 1; i++) {
                vec3 g = vec3(float(i), float(j), float(k));
                vec3 o = hash33(ip + g);
                vec3 d = g + o - fp;
                float dd = dot(d, d);
                if (dd < r.f1) {
                    r.f2 = r.f1;
                    r.f1 = dd;
                    r.c  = d;
                    r.id = ip + g;
                } else if (dd < r.f2) {
                    r.f2 = dd;
                }
            }
        }
    }
    r.f1 = sqrt(r.f1);
    r.f2 = sqrt(r.f2);
    return r;
}

// =====================================================================
// 3. EMBER TWIN
// =====================================================================
vec4 bakeEmberTwin(vec3 d, vec3 so) {
    vec3 w = vec3(fbm(d * 2.0 + so, 3), fbm(d * 2.0 + so + vec3(4.0), 3), fbm(d * 2.0 + so + vec3(8.0), 3)) - 0.5;
    vec3 pw = normalize(d + w * 0.10);

    // ---- THE chasm: one great circle = Ember's equator = the plane Ash Twin orbits in, so the sand column always lands in it ----
    vec3 cn = vec3(0.0, 1.0, 0.0);
    float wob = fbm(pw * 4.0 + so + vec3(3.0), 3) - 0.5;
    float cd = abs(dot(pw, cn) + 0.10 * wob);                       // ~ distance from the chasm centre line
    float cw = EM_CHASM_W * (0.80 + 0.45 * fbm(pw * 3.0 + so + vec3(6.0), 2));
    float inC = 1.0 - smoothstep(cw, cw + EM_WALL_W, cd);           // 1 inside the chasm, 0 on the plates
    float deep = 1.0 - smoothstep(0.0, cw, cd);                     // deepest along the centre line

    // ---- plates: a few big slabs, hairline cracks only (never low enough to catch sand early) ----
    Vor sv = voronoi(pw * EM_PLATE_FREQ + so);
    float seam = 1.0 - smoothstep(0.0, 0.05, sv.f2 - sv.f1);
    float tierR = floor(hash13(sv.id) * 3.0) / 2.0;
    float strata = fbm(vec3(pw.x * 4.0, pw.y * 16.0, pw.z * 4.0) + so, 3);
    float terrace = floor(strata * 4.0) / 4.0;
    float lump = fbm(pw * 8.0 + so + vec3(15.0), 3);
    Vor dm = voronoi(d * 16.0 + so + vec3(21.0));
    float dAct = step(0.40, hash13(dm.id));
    float pit = (1.0 - smoothstep(0.10, 0.30, dm.f1)) * dAct;
    float lip = exp(-pow((dm.f1 - 0.32) * 9.0, 2.0)) * dAct;
    float top = 0.66 + 0.12 * tierR + 0.03 * terrace + 0.04 * lump - 0.05 * pit + 0.012 * lip - 0.06 * seam;

    // chimneys and a broken lip along the chasm rim
    vec3 c0 = normalize(vec3( 0.55,  0.70,  0.45));
    vec3 c1 = normalize(vec3(-0.60, -0.50,  0.62));
    vec3 c2 = normalize(vec3( 0.75, -0.30, -0.58));
    vec3 c3 = normalize(vec3(-0.30,  0.35, -0.88));
    float sp = 0.26 * exp(-pow(acos(clamp(dot(pw, c0), -1.0, 1.0)) / 0.060, 2.0))
             + 0.22 * exp(-pow(acos(clamp(dot(pw, c1), -1.0, 1.0)) / 0.075, 2.0))
             + 0.22 * exp(-pow(acos(clamp(dot(pw, c2), -1.0, 1.0)) / 0.055, 2.0))
             + 0.18 * exp(-pow(acos(clamp(dot(pw, c3), -1.0, 1.0)) / 0.085, 2.0));
    float rimLip = exp(-pow((cd - (cw + EM_WALL_W)) * 14.0, 2.0)) * (0.5 + 0.5 * ridgedFbm(pw * 12.0 + so, 2));
    top = min(top + (sp + 0.07 * rimLip) * (0.7 + 0.5 * ridgedFbm(pw * 14.0 + so, 2)), 1.0);

    // chasm floor: 0.10 .. 0.32, lowest along the centre; this is what the sand fills first
    float floorH = 0.10 + 0.14 * (1.0 - deep) + 0.08 * fbm(pw * 7.0 + so + vec3(9.0), 3);
    float h = mix(top, floorH, inC);

    // ---- albedo ----
    vec3 rockLo = vec3(0.62, 0.21, 0.12);
    vec3 rockHi = vec3(0.95, 0.46, 0.24);
    vec3 col = mix(rockLo, rockHi, 0.20 + 0.80 * smoothstep(0.0, 1.0, tierR * 0.5 + terrace * 0.8 + lump * 0.35));
    col *= 1.0 - 0.45 * pit;
    col *= 1.0 - 0.35 * seam;
    col = mix(col, vec3(0.99, 0.62, 0.38), clamp(sp * 1.6, 0.0, 1.0) * (1.0 - pit));
    // chasm walls: banded, cooler and darker; floor: dark violet-brown
    float wallBand = 0.5 + 0.5 * sin(h * 70.0 + 3.0 * lump);
    vec3 wallCol = mix(vec3(0.34, 0.14, 0.12), vec3(0.52, 0.22, 0.17), wallBand);
    vec3 floorCol = mix(vec3(0.30, 0.14, 0.17), vec3(0.42, 0.18, 0.14), smoothstep(0.1, 0.3, h));
    col = mix(col, wallCol, inC * smoothstep(0.30, 0.55, h));
    col = mix(col, floorCol, inC * (1.0 - smoothstep(0.30, 0.45, h)));

    // dark Nomai lattice window on a plate next to the chasm
    vec3 lc = normalize(vec3(0.30, 0.50, 0.81));
    float la = acos(clamp(dot(pw, lc), -1.0, 1.0));
    vec3 lq = pw * 46.0;
    float lat = min(abs(fract(lq.x + lq.z) - 0.5), abs(fract(lq.x - lq.z) - 0.5));
    float latM = (1.0 - smoothstep(0.13, 0.15, la)) * (1.0 - smoothstep(0.07, 0.15, lat)) * (1.0 - inC);
    col = mix(col, vec3(0.05, 0.03, 0.04), latM * 0.9);

    return vec4(col, clamp(h, 0.0, 1.0));
}

// =====================================================================
// 2. ASH TWIN - a rocky, cratered core (pale spires, ring of towers, a
//    brass gear emblem) that is buried under sand at the start of the
//    loop. a = rock height; planet.frag decides what is still under the
//    sand with the same sand level it uses for the silhouette.
// =====================================================================
vec4 bakeAshTwin(vec3 d, vec3 so) {
    vec3 w = vec3(fbm(d * 2.5 + so, 3), fbm(d * 2.5 + so + vec3(4.0), 3), fbm(d * 2.5 + so + vec3(8.0), 3)) - 0.5;
    vec3 pw = normalize(d + w * 0.12);

    float broad = fbm(pw * 3.0 + so, 4);
    float rough = ridgedFbm(pw * 7.0 + so + vec3(11.0), 3);

    // impact craters
    Vor cr = voronoi(d * 4.6 + so + vec3(5.0));
    float cAct = step(0.45, hash13(cr.id));
    float bowl = (1.0 - smoothstep(0.06, 0.30, cr.f1)) * cAct;
    float rimC = exp(-pow((cr.f1 - 0.31) * 8.0, 2.0)) * cAct;

    float h = 0.43 + 0.08 * broad + 0.05 * rough - 0.20 * bowl + 0.045 * rimC;

    // pale spires near both poles (cones; sand buries them at the start of the loop)
    float polar = smoothstep(0.55, 0.82, abs(d.y));
    Vor sp = voronoi(d * ASH_SPIRE_FREQ + so + vec3(31.0));
    float spAct = step(0.45, hash13(sp.id));
    float prof = pow(1.0 - smoothstep(0.0, 0.62, sp.f1), 0.95);   // blunter, fatter spires
    float spireH = (0.22 + 0.24 * hash13(sp.id + vec3(2.0))) * prof * spAct * polar;

    // ring of squat towers around the equator
    float lon = atan(d.z, d.x);
    float tow = step(0.62, cos(lon * 6.0 + 0.4)) * (1.0 - smoothstep(0.10, 0.22, abs(d.y)));
    float towH = 0.20 * tow * (0.7 + 0.3 * ridgedFbm(d * 9.0 + so, 2));

    h = min(h + spireH + towH, 1.12);

    vec3 rockA = vec3(0.46, 0.38, 0.32);
    vec3 rockB = vec3(0.66, 0.55, 0.43);
    vec3 col = mix(rockA, rockB, smoothstep(0.2, 0.8, broad + 0.4 * rough));
    col *= 1.0 - 0.35 * bowl;
    col = mix(col, vec3(0.30, 0.34, 0.42), 0.35 * smoothstep(0.55, 0.95, rough));        // cool blue-grey streaks
    vec3 bone = vec3(0.86, 0.80, 0.68);
    col = mix(col, bone, clamp((spireH + towH) * 2.6, 0.0, 1.0));

    // brass gear emblem (flat albedo) on the -x side
    vec3 gc = normalize(vec3(-1.0, -0.12, 0.30));
    vec3 gx = normalize(cross(gc, vec3(0.0, 1.0, 0.0)));
    vec3 gy = cross(gc, gx);
    float facing = step(0.0, dot(pw, gc));
    vec2 lp = vec2(dot(pw, gx), dot(pw, gy));
    float gr = length(lp);
    float ga = atan(lp.y, lp.x);
    float teethR = 0.085 + 0.016 * step(0.0, sin(ga * 10.0));
    float gear = (1.0 - smoothstep(teethR - 0.006, teethR, gr)) * (1.0 - (1.0 - smoothstep(0.036, 0.042, gr)));
    gear *= facing;
    col = mix(col, vec3(0.88, 0.58, 0.18), gear);

    return vec4(col, clamp(h, 0.0, 1.2));
}

// =====================================================================
// 4. TIMBER HEARTH
// =====================================================================
float thAng(vec3 a, vec3 b) {
    return acos(clamp(dot(a, b), -1.0, 1.0));
}

float thMassif(vec3 p, vec3 c, float sig, float amp, vec3 so) {
    float a = thAng(p, c) * (1.0 + 0.45 * (fbm(p * 6.0 + so + vec3(3.0), 3) - 0.5));
    float body = exp(-pow(a / sig, 2.0));
    float crag = ridgedFbm(p * 8.0 + so + vec3(17.0), 4);
    return amp * body * (0.28 + 0.72 * crag) * smoothstep(0.02, 0.16, body);
}

float thForest(vec3 p, vec3 c, float rad, float edge) {
    return 1.0 - smoothstep(0.55, 1.0, thAng(p, c) / rad + edge);
}

vec4 bakeTimberHearth(vec3 d, vec3 so) {
    vec3 cA = normalize(vec3( 0.62,  0.22,  0.74));
    vec3 cB = normalize(vec3( 0.95, -0.05,  0.25));
    const float RA = 0.38;
    const float RB = 0.17;

    vec3 w = vec3(fbm(d * 1.8 + so + vec3(3.1, 0.0, 0.0), 3),
                  fbm(d * 1.8 + so + vec3(0.0, 7.7, 0.0), 3),
                  fbm(d * 1.8 + so + vec3(0.0, 0.0, 11.3), 3)) - 0.5;
    vec3 pw = normalize(d + w * 0.30);

    float roll  = fbm(pw * 2.2 + so, 5);
    float det   = fbm(pw * 14.0 + so, 3) - 0.5;
    float edgeN = fbm(pw * 5.0 + so + vec3(8.0), 3) - 0.5;
    float big   = fbm(pw * 1.3 + so + vec3(40.0), 3);

    float xa = thAng(pw, cA) / RA + edgeN * 0.18;
    float xb = thAng(pw, cB) / RB + edgeN * 0.22;
    float floorA = 1.0 - smoothstep(0.84, 1.00, xa);
    float floorB = 1.0 - smoothstep(0.80, 1.00, xb);
    float rimA = exp(-pow((xa - 1.05) * 6.0, 2.0));
    float rimB = exp(-pow((xb - 1.06) * 6.0, 2.0));
    float craterMask = max(floorA, floorB);
    float rimMask = clamp(max(rimA, rimB), 0.0, 1.0);

    float mt = thMassif(pw, normalize(vec3(-0.28,  0.50,  0.82)), 0.25, 0.55, so)
             + thMassif(pw, normalize(vec3(-0.70, -0.30,  0.65)), 0.21, 0.48, so)
             + thMassif(pw, normalize(vec3( 0.30, -0.62,  0.73)), 0.19, 0.42, so)
             + thMassif(pw, normalize(vec3( 0.55,  0.45, -0.70)), 0.22, 0.50, so)
             + thMassif(pw, normalize(vec3(-0.50,  0.20, -0.84)), 0.20, 0.45, so);
    float mtMask = smoothstep(0.03, 0.12, mt);
    float crag = ridgedFbm(pw * 11.0 + so + vec3(5.0), 3);

    vec3 vT = vec3(-1.0, -0.25, 0.20);
    vec3 tR = normalize(vT - dot(vT, cA) * cA);
    vec3 nR = normalize(cross(cA, tR));
    float u = atan(dot(pw, tR), dot(pw, cA));
    float meander = 0.15 * sin(u * 5.5 + 1.0) + 0.35 * (fbm(pw * 3.5 + so + vec3(60.0), 3) - 0.5);
    float rd = abs(dot(pw, nR) + meander * 0.7);
    float hw = 0.024 + 0.008 * sin(u * 5.0);
    float arc = smoothstep(RA * 1.0, RA * 1.25, u) * (1.0 - smoothstep(2.3, 2.8, u));
    float riv = (1.0 - smoothstep(hw * 0.55, hw, rd)) * arc;
    riv *= (1.0 - craterMask) * (1.0 - smoothstep(0.02, 0.10, mt));
    float bank = (1.0 - smoothstep(hw, hw * 2.4, rd)) * arc;

    float fe = edgeN * 0.9;
    float fm = thForest(pw, normalize(vec3(-0.35,  0.78,  0.52)), 0.40, fe);
    fm = max(fm, thForest(pw, normalize(vec3(-0.82,  0.05,  0.57)), 0.32, fe));
    fm = max(fm, thForest(pw, normalize(vec3( 0.10, -0.35,  0.93)), 0.28, fe));
    fm = max(fm, thForest(pw, normalize(vec3( 0.35,  0.70,  0.62)), 0.26, fe));
    fm = max(fm, thForest(pw, normalize(vec3( 0.20,  0.10, -0.97)), 0.40, fe));
    fm *= (1.0 - craterMask) * (1.0 - rimMask * 0.8) * (1.0 - smoothstep(0.02, 0.10, mt));

    Vor tv = voronoi(d * 13.0 + so + vec3(44.0));
    float tProb = 0.012 + 0.988 * fm;
    float tHas = step(1.0 - tProb, hash13(tv.id));
    float cone = pow(max(1.0 - tv.f1 / 0.54, 0.0), 0.8) * tHas;
    cone *= (1.0 - craterMask) * (1.0 - mtMask) * (1.0 - bank);
    float treeH = 0.60 + 0.40 * hash13(tv.id + vec3(3.0));
    Vor ug = voronoi(d * 30.0 + so + vec3(91.0));
    float under = (1.0 - smoothstep(0.15, 0.50, ug.f1)) * fm * (1.0 - cone);

    float hv = 0.20 + 0.16 * roll + 0.03 * det
             - 0.20 * floorA + 0.16 * rimA
             - 0.14 * floorB + 0.12 * rimB
             + 1.2 * mt
             + 0.24 * cone * treeH + 0.03 * under
             - 0.05 * bank;
    float h = 0.36 + 0.64 * clamp(hv, 0.0, 1.0);
    h = mix(h, 0.30, riv);

    vec3 grassA = vec3(0.26, 0.36, 0.12);
    vec3 grassB = vec3(0.35, 0.43, 0.17);
    vec3 land = mix(grassA, grassB, smoothstep(0.30, 0.72, roll));
    land = mix(land, vec3(0.36, 0.37, 0.15), smoothstep(0.50, 0.80, big) * 0.5);
    float dry = smoothstep(0.68, 0.80, fbm(pw * 2.8 + so + vec3(13.0), 4));
    land = mix(land, vec3(0.55, 0.33, 0.24), dry * 0.55);
    land = mix(land, vec3(0.07, 0.16, 0.07), fm * 0.85);

    float rockN = fbm(pw * 10.0 + so + vec3(21.0), 3);
    vec3 craterCol = mix(vec3(0.34, 0.22, 0.15), vec3(0.20, 0.17, 0.15), smoothstep(0.30, 0.70, rockN));
    craterCol *= 0.70 + 0.30 * smoothstep(0.0, 0.9, min(xa, xb * 1.6));
    land = mix(land, craterCol, craterMask);
    land = mix(land, vec3(0.52, 0.45, 0.36), rimMask * 0.65 * (1.0 - mtMask));
    float obs = 1.0 - smoothstep(0.0, 0.30, xb);
    land = mix(land, vec3(0.88, 0.84, 0.76), obs * 0.9);

    vec3 rock = mix(vec3(0.24, 0.23, 0.23), vec3(0.64, 0.62, 0.60), smoothstep(0.20, 0.80, crag));
    float snow = smoothstep(0.26, 0.40, mt + 0.12 * (crag - 0.5));
    land = mix(land, rock, mtMask);
    land = mix(land, vec3(0.95, 0.97, 1.00), snow * mtMask);

    vec3 pine = mix(vec3(0.03, 0.11, 0.05), vec3(0.08, 0.22, 0.09), hash13(tv.id + vec3(7.0)));
    pine *= 0.60 + 0.80 * fbm(d * 46.0 + so + vec3(7.0), 2);
    pine = mix(pine, vec3(0.58, 0.34, 0.13), step(0.975, hash13(tv.id + vec3(5.0))));
    land = mix(land, vec3(0.05, 0.14, 0.07), under * 0.7);
    land = mix(land, pine, smoothstep(0.05, 0.35, cone));

    vec3 water = vec3(0.14, 0.40, 0.60);
    vec3 col = mix(land, water, riv);
    return vec4(col, clamp(h, 0.0, 1.0));
}

// =====================================================================
// 5. ATTLEROCK
// =====================================================================
vec3 atCraterLayer(vec3 p, float freq, float prob, float rMin, float rMax, vec3 so, float seed) {
    Vor v = voronoi(p * freq + so + vec3(seed));
    float act = step(1.0 - prob, hash13(v.id));
    float rad = mix(rMin, rMax, hash13(v.id + vec3(11.0)));
    float x = v.f1 / rad;
    float bowl = (1.0 - smoothstep(0.55, 0.95, x)) * act;
    float rim  = exp(-pow((x - 1.02) * 3.6, 2.0)) * act;
    float dark = act * (1.0 - smoothstep(0.0, 1.1, x));
    return vec3(bowl, rim, dark);
}

vec4 bakeAttlerock(vec3 d, vec3 so) {
    vec3 cA = normalize(vec3( 0.25,  0.42,  0.87));
    vec3 cB = normalize(vec3(-0.60, -0.25,  0.76));
    vec3 nC = normalize(vec3( 0.10, -0.80,  0.59));
    const float RA = 0.62;
    const float RB = 0.42;
    const float CC = 0.84;

    vec3 w = vec3(fbm(d * 2.0 + so + vec3(2.0, 0.0, 0.0), 3),
                  fbm(d * 2.0 + so + vec3(0.0, 5.0, 0.0), 3),
                  fbm(d * 2.0 + so + vec3(0.0, 0.0, 9.0), 3)) - 0.5;
    vec3 pw = normalize(d + w * 0.14);

    float lump  = fbm(d * 1.15 + so + vec3(5.0), 3);
    float mid   = fbm(d * 3.6 + so, 4);
    float grain = fbm(d * 26.0 + so + vec3(3.0), 3);
    float edgeN = fbm(pw * 6.0 + so + vec3(8.0), 3) - 0.5;

    float xa = acos(clamp(dot(pw, cA), -1.0, 1.0)) / RA + edgeN * 0.10;
    float xb = acos(clamp(dot(pw, cB), -1.0, 1.0)) / RB + edgeN * 0.14;
    float floorA = 1.0 - smoothstep(0.84, 1.00, xa);
    float floorB = 1.0 - smoothstep(0.82, 1.00, xb);
    float rimA = exp(-pow((xa - 1.03) * 8.0, 2.0));
    float rimB = exp(-pow((xb - 1.04) * 7.0, 2.0));
    float bigMask = clamp(max(max(floorA, floorB), max(rimA, rimB)), 0.0, 1.0);

    float dC = dot(pw, nC);
    float cut = max(dC - CC, 0.0) / (1.0 - CC);
    float edgeC = smoothstep(0.0, 0.05, cut);

    vec3 l1 = atCraterLayer(pw, 2.6, 0.45, 0.28, 0.44, so, 3.0);
    vec3 l2 = atCraterLayer(pw, 5.5, 0.35, 0.24, 0.40, so, 17.0);
    vec3 l3 = atCraterLayer(pw, 12.0, 0.20, 0.20, 0.34, so, 29.0);
    float keep = (1.0 - bigMask) * (1.0 - edgeC * 0.8);
    float cBowl = (0.14 * l1.x + 0.07 * l2.x + 0.04 * l3.x) * keep;
    float cRim  = (0.06 * l1.y + 0.035 * l2.y + 0.02 * l3.y) * keep;
    float cDark = max(max(l1.z, l2.z), l3.z) * keep;

    Vor tv = voronoi(d * 14.0 + so + vec3(7.0));
    float tAct = step(0.55, hash13(tv.id));
    float cone = pow(max(1.0 - tv.f1 / 0.50, 0.0), 0.9) * tAct * floorA * (1.0 - smoothstep(0.80, 0.92, xa));

    vec3 ruinA = normalize(vec3( 0.20,  0.52,  0.83));
    vec3 ruinB1 = normalize(vec3(-0.55, -0.22, 0.80));
    vec3 ruinB2 = normalize(vec3(-0.66, -0.30, 0.69));
    vec3 ruinB3 = normalize(vec3(-0.50, -0.36, 0.79));
    float ruins = 0.0;
    ruins = max(ruins, 1.0 - smoothstep(0.030, 0.042, acos(clamp(dot(pw, ruinA), -1.0, 1.0))));
    ruins = max(ruins, (1.0 - smoothstep(0.026, 0.036, acos(clamp(dot(pw, ruinB1), -1.0, 1.0)))) * floorB);
    ruins = max(ruins, (1.0 - smoothstep(0.026, 0.036, acos(clamp(dot(pw, ruinB2), -1.0, 1.0)))) * floorB);
    ruins = max(ruins, (1.0 - smoothstep(0.024, 0.034, acos(clamp(dot(pw, ruinB3), -1.0, 1.0)))) * floorB);

    float h = 0.50 + 0.30 * (lump - 0.5) + 0.05 * (mid - 0.5) + 0.012 * (grain - 0.5)
            - 0.16 * floorA + 0.045 * rimA
            - 0.12 * floorB + 0.04 * rimB
            - 0.20 * cut
            - cBowl + cRim
            + 0.10 * cone + 0.025 * ruins;

    float tint = smoothstep(0.30, 0.70, fbm(d * 4.0 + so + vec3(21.0), 4));
    vec3 col = mix(vec3(0.29, 0.265, 0.24), vec3(0.48, 0.435, 0.395), tint);
    col *= 0.90 + 0.20 * grain;
    col = mix(col, col * 0.62, cDark * 0.6);
    col = mix(col, vec3(0.55, 0.52, 0.47), clamp(cRim * 3.0 + rimA * 0.4 + rimB * 0.3, 0.0, 0.45));
    col = mix(col, vec3(0.58, 0.54, 0.49), edgeC * 0.45);

    float soil = fbm(d * 9.0 + so + vec3(33.0), 3);
    vec3 floorACol = mix(vec3(0.36, 0.19, 0.12), vec3(0.26, 0.16, 0.11), smoothstep(0.35, 0.70, soil));
    col = mix(col, floorACol, floorA);
    col = mix(col, vec3(0.20, 0.17, 0.16), floorB * 0.85);
    col = mix(col, mix(vec3(0.04, 0.12, 0.05), vec3(0.09, 0.22, 0.09), hash13(tv.id + vec3(3.0))), smoothstep(0.05, 0.40, cone));
    col = mix(col, vec3(0.86, 0.43, 0.18), ruins);

    return vec4(col, clamp(h, 0.0, 1.0));
}

// =====================================================================
// 6. BRITTLE HOLLOW
// =====================================================================
vec4 bakeBrittleHollow(vec3 d, vec3 so) {
    vec3 w = vec3(fbm(d * 2.4 + so + vec3(1.3, 0.0, 0.0), 3),
                  fbm(d * 2.4 + so + vec3(0.0, 4.7, 0.0), 3),
                  fbm(d * 2.4 + so + vec3(0.0, 0.0, 8.9), 3)) - 0.5;
    vec3 pw = normalize(d + w * 0.20);

    Vor pc = voronoi(pw * 3.5 + so);
    Vor ps = voronoi(pw * 9.0 + so + vec3(19.0));

    float edgeMain = pc.f2 - pc.f1;
    float edgeSub  = ps.f2 - ps.f1;
    float cellHash = hash13(pc.id);
    float subHash  = hash13(ps.id + vec3(5.0));
    vec3  tilt     = hash33(pc.id + vec3(9.0)) * 2.0 - 1.0;

    float polarLat = abs(d.y) + (fbm(pw * 5.0 + so, 3) - 0.5) * 0.14;
    float polarCap = smoothstep(0.66, 0.79, polarLat);

    vec3 b1 = normalize(vec3( 0.86,  0.12,  0.49));
    vec3 b2 = normalize(vec3(-0.68, -0.18,  0.71));
    vec3 b3 = normalize(vec3(-0.18,  0.22, -0.95));

    float a1 = acos(clamp(dot(pw, b1), -1.0, 1.0));
    float a2 = acos(clamp(dot(pw, b2), -1.0, 1.0));
    float a3 = acos(clamp(dot(pw, b3), -1.0, 1.0));

    float breach = max(1.0 - smoothstep(0.32, 0.54, a1),
                   max(1.0 - smoothstep(0.28, 0.48, a2),
                       1.0 - smoothstep(0.30, 0.50, a3)));

    float plateStability = clamp(cellHash * 0.72 + subHash * 0.28 - breach * 0.62 + polarCap * 0.65, 0.0, 1.0);

    float openSeamWidth = mix(0.040, 0.003, smoothstep(0.25, 0.60, plateStability)) * (1.0 - polarCap * 0.9);
    float seamOpenMask  = smoothstep(openSeamWidth, openSeamWidth + 0.024, edgeMain);
    float canyonGroove  = smoothstep(0.0, 0.075, edgeMain) * (0.75 + 0.25 * smoothstep(0.0, 0.04, edgeSub));

    float ridgeSpine = ridgedFbm(pw * 7.2 + so + vec3(11.0), 4);
    float mountainPeak = pow(ridgeSpine, 1.6) * smoothstep(0.06, 0.16, edgeMain);

    Vor mv = voronoi(pw * 6.0 + so + vec3(53.0));
    float massifAct = step(0.52, hash13(mv.id));
    float massifPeak = (1.0 - smoothstep(0.0, 0.36, mv.f1)) * massifAct * (0.6 + 0.4 * ridgeSpine);

    vec3 southObsDir = normalize(vec3(0.18, -0.96, 0.20));
    float distObs    = acos(clamp(dot(d, southObsDir), -1.0, 1.0));
    float obsDome    = (1.0 - smoothstep(0.05, 0.11, distObs)) * 0.32;

    vec3 qTowerDir   = normalize(vec3(-0.74, 0.32, -0.59));
    float distTower  = acos(clamp(dot(d, qTowerDir), -1.0, 1.0));
    float qTowerSpire = (1.0 - smoothstep(0.03, 0.09, distTower)) * 0.38;

    Vor vc = voronoi(d * 9.5 + so + vec3(37.0));
    float craterActive = step(0.66, hash13(vc.id)) * (1.0 - polarCap * 0.85);
    float craterBowl   = (1.0 - smoothstep(0.07, 0.23, vc.f1)) * craterActive;
    float craterRim    = exp(-pow((vc.f1 - 0.25) * 9.0, 2.0)) * craterActive;

    float strata   = fbm(vec3(pw.x * 4.5, pw.y * 24.0, pw.z * 4.5) + so, 3);
    float terraces = floor(strata * 5.0) / 5.0;
    float facet    = dot(tilt, -pc.c) * 0.09;

    float mountainRelief = 0.26 * mountainPeak + 0.24 * massifPeak + obsDome + qTowerSpire + 0.10 * craterRim - 0.12 * craterBowl;
    float solidHeight = 0.42 + 0.10 * cellHash + 0.06 * terraces + facet + mountainRelief;
    solidHeight = mix(0.32, clamp(solidHeight, 0.38, 1.0), canyonGroove);

    float intactAtStart = smoothstep(0.23, 0.28, plateStability) * seamOpenMask;
    float stabilityRamp = smoothstep(0.24, 0.65, plateStability);
    float h = (intactAtStart > 0.5)
            ? mix(0.26, solidHeight, 0.30 + 0.70 * stabilityRamp)
            : (0.20 * plateStability * seamOpenMask);

    vec3 basaltDark  = vec3(0.13, 0.15, 0.28);
    vec3 basaltMid   = vec3(0.21, 0.25, 0.42);
    vec3 basaltPeak  = vec3(0.36, 0.41, 0.60);
    float rockTone = clamp(cellHash * 0.40 + subHash * 0.20 + terraces * 0.30 + mountainPeak * 0.35, 0.0, 1.0);
    vec3 col = mix(basaltDark, basaltMid, smoothstep(0.15, 0.55, rockTone));
    col = mix(col, basaltPeak, smoothstep(0.55, 0.88, rockTone));
    col = mix(vec3(0.08, 0.09, 0.18), col, smoothstep(0.0, 0.06, edgeMain));

    vec3 ochreDark  = vec3(0.50, 0.28, 0.19);
    vec3 ochreLight = vec3(0.78, 0.48, 0.29);
    float rimBand   = exp(-pow((edgeMain - 0.055) * 22.0, 2.0)) * (1.0 - polarCap * 0.9);
    float mesaTop   = smoothstep(0.65, 0.78, terraces) * smoothstep(0.10, 0.18, edgeMain) * (1.0 - polarCap * 0.85);
    float ochreMask = clamp(rimBand * 0.68 + mesaTop * 0.42, 0.0, 1.0);
    col = mix(col, mix(ochreDark, ochreLight, subHash), ochreMask);

    vec3 iceBlue    = vec3(0.55, 0.75, 0.92);
    vec3 snowBright = vec3(0.93, 0.97, 1.00);
    float altSnow   = smoothstep(0.72, 0.86, solidHeight) * (1.0 - craterActive);
    float snowMask  = clamp(smoothstep(0.64, 0.77, polarLat + (ridgeSpine - 0.5) * 0.14) + altSnow * 0.85, 0.0, 1.0);
    col = mix(col, mix(iceBlue, snowBright, smoothstep(0.35, 0.75, ridgeSpine)), snowMask);

    col = mix(col, vec3(0.88, 0.72, 0.38), clamp((obsDome + qTowerSpire) * 2.2, 0.0, 1.0));

    vec3 lavaGlow = vec3(1.00, 0.40, 0.08);
    vec3 scorch   = vec3(0.08, 0.07, 0.12);
    col = mix(col, scorch, clamp(craterBowl * 0.85 + craterRim * 0.35, 0.0, 1.0));
    float lavaVein = craterBowl * smoothstep(0.11, 0.02, vc.f1)
                   + (1.0 - smoothstep(0.0, 0.020, edgeMain)) * (1.0 - smoothstep(0.24, 0.38, plateStability)) * 0.85;
    col = mix(col, lavaGlow, clamp(lavaVein, 0.0, 1.0));

    return vec4(clamp(col, 0.0, 1.0), clamp(h, 0.0, 1.0));
}

// =====================================================================
// 7. HOLLOW'S LANTERN
// =====================================================================
float hlAng(vec3 a, vec3 b) {
    return acos(clamp(dot(a, b), -1.0, 1.0));
}

vec2 hlCone(float x) {
    float body = pow(max(1.0 - x, 0.0), 1.15);
    float cal  = 1.0 - smoothstep(0.12, 0.30, x);
    float dip  = 0.35 + 0.65 * smoothstep(0.08, 0.32, x);
    return vec2(body * dip, cal * step(x, 1.0));
}

vec4 bakeHollowsLantern(vec3 d, vec3 so) {
    vec3 lavaC = normalize(vec3(0.10, 0.05, 0.99));

    vec3 w = vec3(fbm(d * 2.0 + so + vec3(2.0, 0.0, 0.0), 3),
                  fbm(d * 2.0 + so + vec3(0.0, 5.0, 0.0), 3),
                  fbm(d * 2.0 + so + vec3(0.0, 0.0, 9.0), 3)) - 0.5;
    vec3 pw = normalize(d + w * 0.10);
    float edgeN = fbm(pw * 3.0 + so + vec3(4.0), 3) - 0.5;

    float s = -dot(pw, lavaC);
    float dens = smoothstep(-0.10, 0.45, s + edgeN * 0.55);

    Vor vf = voronoi(pw * 1.9 + so + vec3(31.0));
    float act = step(0.07, hash13(vf.id)) * step(0.05, dens);
    float rad = mix(0.60, 0.95, hash13(vf.id + vec3(5.0))) * (0.40 + 0.60 * dens);
    vec2 cn = hlCone(vf.f1 / rad);
    float crag = ridgedFbm(pw * 9.0 + so + vec3(13.0), 4);
    float Hc = mix(0.40, 0.62, hash13(vf.id + vec3(9.0)));
    float slabTilt = dot(hash33(vf.id + vec3(2.0)) * 2.0 - 1.0, vf.c) * 0.08;
    float fissure = (1.0 - smoothstep(0.0, 0.05, vf.f2 - vf.f1)) * act;
    float hDense = (Hc * cn.x * (0.55 + 0.65 * crag) + slabTilt * step(0.001, cn.x)) * act - 0.22 * fissure;
    hDense = max(hDense, 0.0);
    float calDense = cn.y * act;

    vec3 v1 = normalize(vec3( 0.35,  0.55, 0.76));
    vec3 v2 = normalize(vec3( 0.72, -0.15, 0.68));
    vec3 v3 = normalize(vec3(-0.05, -0.72, 0.69));
    vec2 e1 = hlCone(hlAng(pw, v1) / 0.26);
    vec2 e2 = hlCone(hlAng(pw, v2) / 0.22);
    vec2 e3 = hlCone(hlAng(pw, v3) / 0.20);
    float hLone = max(max(0.60 * e1.x, 0.50 * e2.x), 0.42 * e3.x) * (0.70 + 0.45 * crag);
    float calLone = max(max(e1.y, e2.y), e3.y);

    float hCone = max(hDense, hLone);
    float calMask = max(calDense, calLone);

    vec3 ringC = normalize(vec3(-0.28, 0.10, 0.95));
    vec3 tA = normalize(cross(ringC, vec3(0.0, 1.0, 0.0)));
    vec3 tB = cross(ringC, tA);
    float aR = hlAng(pw, ringC);
    float phi = atan(dot(pw, tB), dot(pw, tA));
    float ring = exp(-pow((aR - 0.55 + 0.05 * sin(phi * 3.0)) * 13.0, 2.0));
    ring *= smoothstep(-1.0, -0.55, sin(phi - 0.6)) * smoothstep(0.30, 0.55, ring + 0.3) * (1.0 - dens);

    float lw  = fbm(pw * 3.0 + so + vec3(0.0, 2.0, 7.0), 4);
    float lw2 = fbm(pw * 8.0 + so + vec3(19.0) + w * 2.0, 3);
    float h = 0.30 + 0.02 * (lw2 - 0.5) + hCone + 0.05 * ring;

    vec3 lavaHot = vec3(1.00, 0.68, 0.16);
    vec3 lavaMid = vec3(1.00, 0.40, 0.07);
    vec3 lavaRed = vec3(0.80, 0.16, 0.04);
    vec3 lava = mix(lavaMid, lavaHot, smoothstep(0.35, 0.70, lw2));
    lava = mix(lava, lavaRed, smoothstep(0.55, 0.75, lw) * 0.8);

    float rockMask = smoothstep(0.012, 0.07, hCone);
    vec3 rock = mix(vec3(0.14, 0.10, 0.09), vec3(0.32, 0.23, 0.20), crag);
    rock = mix(rock, vec3(0.50, 0.44, 0.40), smoothstep(0.62, 0.85, crag) * 0.5 * smoothstep(0.10, 0.30, hCone));
    float cracks = smoothstep(0.92, 0.97, ridgedFbm(pw * 14.0 + so + vec3(61.0), 3)) * rockMask * 0.55;

    vec3 col = mix(lava, rock, rockMask);
    col = mix(col, lavaMid, clamp(cracks + fissure * 0.9, 0.0, 1.0));
    col = mix(col, vec3(1.00, 0.86, 0.34), calMask * smoothstep(0.02, 0.10, hCone + 0.05));
    col = mix(col, vec3(0.20, 0.06, 0.04), smoothstep(0.25, 0.60, ring));

    return vec4(col, clamp(h, 0.0, 1.0));
}

// =====================================================================
// 8. GIANT'S DEEP
// =====================================================================
vec4 bakeGiantDeep(vec3 d, vec3 so) {
    vec3 pw = d + vec3(
        fbm(d * 1.5 + so + vec3(1.2, 0.0, 0.0), 3),
        fbm(d * 1.5 + so + vec3(0.0, 3.5, 0.0), 3),
        fbm(d * 1.5 + so + vec3(0.0, 0.0, 6.1), 3)
    ) * 0.35;

    float bands = sin(pw.y * 7.5 + fbm(pw * 2.5 + so, 4) * 2.8) * 0.5 + 0.5;
    float storm = fbm(pw * 4.0 + so + vec3(10.0, 0.0, 5.0), 4);

    vec3 deepOlive = vec3(0.09, 0.16, 0.11);
    vec3 mutedTeal = vec3(0.14, 0.24, 0.19);
    vec3 cloudPale = vec3(0.22, 0.35, 0.27);

    vec3 col = mix(deepOlive, mutedTeal, bands);
    col = mix(col, cloudPale, storm * 0.5);

    float h = 0.5 + 0.2 * storm;
    return vec4(col, clamp(h, 0.0, 1.0));
}

// =====================================================================
// 9. DARK BRAMBLE
// =====================================================================
float bramRidge(vec3 p, int oct) {
    return 1.0 - abs(2.0 * fbm(p, oct) - 1.0);
}

vec2 bramRope(float c, float thr) {
    float q = clamp((c - thr) / (1.0 - thr), 0.0, 1.0);
    float cov = smoothstep(0.0, 0.10, q);
    float hh = sqrt(max(1.0 - (1.0 - q) * (1.0 - q), 0.0));
    return vec2(cov, hh);
}

vec4 bakeBramble(vec3 d, vec3 so) {
    vec3 w = vec3(fbm(d * 2.6 + so + vec3(1.0, 0.0, 0.0), 3),
                  fbm(d * 2.6 + so + vec3(0.0, 5.0, 0.0), 3),
                  fbm(d * 2.6 + so + vec3(0.0, 0.0, 9.0), 3)) - 0.5;

    vec3 vw = d + w * 0.40;

    float c1 = bramRidge(vw * 1.6 + so, 3);
    float c2 = bramRidge(vw * 3.4 + so + vec3(20.0), 3);
    float c3 = bramRidge(vw * 7.5 + so + vec3(40.0), 3);

    vec2 r1 = bramRope(c1, 0.855);
    vec2 r2 = bramRope(c2, 0.915);
    vec2 r3 = bramRope(c3, 0.955);

    float vine = max(r1.x, max(r2.x * 0.95, r3.x * 0.80));
    float vh   = max(r1.y * 0.74, max(r2.y * 0.54, r3.y * 0.36));

    float s1 = 2.0 * fbm(vw * 1.6 + so, 3) - 1.0;
    float al = fbm(vw * 3.4 + so + vec3(77.0), 3);
    float strand = 0.5 + 0.5 * sin(s1 * 70.0 + al * 60.0);
    float fiber  = bramRidge(vw * 55.0 + so + vec3(55.0), 3);
    fiber *= fiber;
    float rope = mix(strand, fiber, 0.45);

    Vor tv = voronoi(vw * 13.0 + so + vec3(70.0));
    float tAct = step(0.62, hash13(tv.id));
    float thorn = pow(max(1.0 - tv.f1 / 0.26, 0.0), 1.5) * tAct * smoothstep(0.15, 0.55, vine);
    vh += thorn * 0.40;

    vec3 pw = d + w * 0.20;
    Vor pc = voronoi(pw * 1.7 + so);
    float alive = step(0.72, hash13(pc.id + vec3(3.0)));
    float edge = pc.f2 - pc.f1;
    float nib = fbm(pw * 6.0 + so + vec3(11.0), 3);
    float plate = alive * smoothstep(0.03, 0.09, edge) * smoothstep(0.30, 0.38, nib);

    vec3 tilt = hash33(pc.id + vec3(9.0)) * 2.0 - 1.0;
    float ph = 0.78 + 0.12 * hash13(pc.id + vec3(9.0)) + dot(tilt, -pc.c) * 0.05
             - (1.0 - smoothstep(0.03, 0.12, edge)) * 0.10;
    float strata = fbm(vec3(pw.x * 3.0, pw.y * 30.0, pw.z * 3.0) + so + vec3(30.0), 4);
    float tone = mix(strata, hash13(pc.id + vec3(1.0)), 0.5);

    vine *= mix(1.0, 0.30, plate);

    float h = mix(vine * vh, ph, plate);
    float g = mix(tone, rope, smoothstep(0.2, 0.6, vine) * (1.0 - plate));
    return vec4(plate, g, vine, clamp(h, 0.0, 1.0));
}

// =====================================================================
// 10. THE INTERLOPER (Accurate Cratered Rock Nose + Glacial Ice Mantle)
// =====================================================================
vec4 bakeInterloper(vec3 d, vec3 so) {
    vec3 noseDir = vec3(1.0, 0.0, 0.0);
    float noseDot = dot(d, noseDir);

    float stoneNoise = fbm(d * 18.0 + so, 4);
    Vor cv = voronoi(d * 7.0 + so);
    float cracks = smoothstep(0.02, 0.08, cv.f2 - cv.f1);
    float rockPebbles = smoothstep(0.2, 0.8, stoneNoise) * (0.8 + 0.2 * cracks);

    float iceTurb = fbm(d * 5.0 + so + vec3(12.0), 3);

    Vor bv = voronoi(d * 4.5 + so + vec3(45.0));
    float isBoulder = step(0.72, hash13(bv.id)) * (1.0 - smoothstep(0.12, 0.32, bv.f1));

    float rockMask = smoothstep(0.05, 0.40, noseDot + (fbm(d * 3.5 + so, 3) - 0.5) * 0.35);
    rockMask = clamp(max(rockMask, isBoulder), 0.0, 1.0);

    vec3 stoneDark  = vec3(0.28, 0.25, 0.22);
    vec3 stoneLight = vec3(0.58, 0.53, 0.48);
    vec3 stoneCol   = mix(stoneDark, stoneLight, rockPebbles);

    vec3 iceDeep  = vec3(0.25, 0.56, 0.68);
    vec3 icePale  = vec3(0.68, 0.86, 0.92);
    vec3 iceFrost = vec3(0.88, 0.96, 0.99);
    vec3 iceCol   = mix(iceDeep, icePale, smoothstep(0.25, 0.75, iceTurb));
    iceCol        = mix(iceCol, iceFrost, smoothstep(0.65, 0.90, iceTurb));

    vec3 finalCol = mix(iceCol, stoneCol, rockMask);
    float h = mix(0.58, 0.46, rockMask);

    return vec4(clamp(finalCol, 0.0, 1.0), h);
}

void main() {
    vec3 d = uvToDir(qt_TexCoord0);
    float type = bakeParams.x;
    float seed = bakeParams.y;
    vec3 so = vec3(seed * 1.37, seed * 2.11, seed * 0.73);

    vec4 o;
    if (type > 9.5) {
        o = bakeInterloper(d, so);
    } else if (type > 8.5) {
        o = bakeBramble(d, so);
    } else if (type > 7.5) {
        o = bakeGiantDeep(d, so);
    } else if (type > 6.5) {
        o = bakeHollowsLantern(d, so);
    } else if (type > 5.5) {
        o = bakeBrittleHollow(d, so);
    } else if (type > 4.5) {
        o = bakeAttlerock(d, so);
    } else if (type > 3.5) {
        o = bakeTimberHearth(d, so);
    } else if (type > 2.5) {
        o = bakeEmberTwin(d, so);
    } else {
        o = bakeAshTwin(d, so);
    }
    fragColor = o;
}
