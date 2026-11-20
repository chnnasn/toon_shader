#ifndef LIINO_RAIN_INCLUDED
#define LIINO_RAIN_INCLUDED

// xyz is the showcase character's origin, shared by all its skinned renderers.
float3 _LiinoRainOriginWS;

float3 LiinoRainHash(float2 cell)
{
    float3 h = frac(float3(cell.xyx) * float3(.1031, .1030, .0973));
    h += dot(h, h.yxz + 33.33);
    return frac((h.xxy + h.yzz) * h.zyx);
}

struct LiinoRainSample
{
    float bead;
    float trail;
    float2 slope;
};

// World-metre scale keeps a bead the same size on an earring and a sleeve.
// The highlight and the dark lip come from the slope of the same rounded cap.
float LiinoBead(float2 offset, float2 radius, float pixelWidth, out float2 slope)
{
    float2 q = offset / radius;
    float d = length(q);
    float aa = clamp(pixelWidth / min(radius.x, radius.y), .06, .9);
    float cap = 1 - smoothstep(1 - aa, 1 + aa, d);
    cap *= saturate(min(radius.x, radius.y) * 2 / max(pixelWidth, .0001));
    slope = q * (1.4 / max(1, d)) * cap;
    return cap;
}

LiinoRainSample LiinoRainPlane(float2 p, float pixelWidth, float time,
    float rain, float hair, float silk, float vertical)
{
    LiinoRainSample result;
    // Pinned beads sit at independent positions and grow at different rates.
    float spacing = lerp(.014, .021, hair);
    float2 grid = p / spacing;
    float3 seed = LiinoRainHash(floor(grid));
    float2 offset = (frac(grid) - lerp(.23, .77, seed.xy)) * spacing;
    float growth = frac(time * (.045 + .07 * seed.x) + seed.y);
    float radius = lerp(.00085, .0028, seed.z * seed.z) * lerp(.63, 1.12, growth);
    float amount = smoothstep(.04, .22, growth) * (1 - smoothstep(.91, 1, growth));
    amount *= smoothstep(seed.x - .10, seed.x + .10, rain * lerp(.86, .61, hair));
    result.bead = LiinoBead(offset, radius * float2(1, 1 + vertical * .27), pixelWidth, result.slope);
    result.slope *= amount;
    result.bead *= amount;
    result.trail = 0;
    if (vertical > 0)
    {
        // A moving head and its fading tail share a gently winding channel.
        // Positive phase velocity moves the head towards decreasing world Y.
        float laneWidth = lerp(.042, .057, silk);
        float lane = floor(p.x / laneWidth);
        float3 route = LiinoRainHash(float2(lane, 71.4));
        float bend = sin(p.y * 28 + route.y * 30) + .35 * sin(p.y * 60 + route.x * 19);
        float across = (frac(p.x / laneWidth) - lerp(.22, .78, route.x)) * laneWidth - bend * .0024;
        float period = lerp(.18, .37, route.y);
        float cycle = time * lerp(.32, .70, route.z) + route.x;
        float travel = floor(cycle) + smoothstep(0, 1, frac(cycle));
        float along = (frac(p.y / period + travel + route.y) - .18) * period;
        float runner = smoothstep(route.z * .8 + .03, route.z * .8 + .24, rain);
        runner *= lerp(1, .28, hair);
        float width = lerp(.0011, .0025, route.x);
        float2 headSlope;
        float head = LiinoBead(float2(across, along), width * float2(1.15, 2.25), pixelWidth, headSlope);
        float tail = smoothstep(.001, .006, along) * (1 - smoothstep(.025, period * .67, along));
        float trailWidth = width * lerp(.25, .78, tail);
        float aa = max(.00015, pixelWidth * .65);
        result.trail = (1 - smoothstep(max(0, trailWidth - aa), trailWidth + aa, abs(across)))
                     * tail * runner * saturate(trailWidth * 2 / aa);
        result.slope += headSlope * runner + float2(clamp(across / width, -1, 1) * result.trail, 0);
        result.bead = max(result.bead, head * runner);
    }
    return result;
}

void LiinoRainSurfaceRelative(float3 rel, float3 normal, float3 right, float rain, float hair, float silk,
    out float bead, out float trail, out float3 slope)
{
    float3 up = float3(0, 1, 0);
    right = normalize(float3(right.x + 1e-6, 0, right.z));
    float3 front = cross(right, up);
    float3 p = float3(dot(rel, right), rel.y, dot(rel, front));
    float3 n = float3(dot(normal, right), normal.y, dot(normal, front));
    float3 weight = pow(abs(n), 6);
    weight /= max(dot(weight, 1.0.xxx), .0001);
    float3 footprint = fwidth(p);
    float time = _Time.y;
    LiinoRainSample side = LiinoRainPlane(p.zy + 1.41, max(footprint.z, footprint.y), time, rain, hair, silk, 1);
    LiinoRainSample top = LiinoRainPlane(p.xz + 2.75, max(footprint.x, footprint.z), time, rain, hair, silk, 0);
    LiinoRainSample face = LiinoRainPlane(p.xy, max(footprint.x, footprint.y), time, rain, hair, silk, 1);
    bead = dot(weight, float3(side.bead, top.bead, face.bead));
    trail = dot(weight, float3(side.trail, 0, face.trail));
    slope = right * (top.slope.x * weight.y + face.slope.x * weight.z)
          + up * (side.slope.y * weight.x + face.slope.y * weight.z)
          + front * (side.slope.x * weight.x + top.slope.y * weight.y);
    slope -= normal * dot(normal, slope);
}

void LiinoRainSurface(float3 worldPos, float3 normal, float3 right, float rain, float hair, float silk,
    out float bead, out float trail, out float3 slope)
{
    LiinoRainSurfaceRelative(worldPos - _LiinoRainOriginWS, normal, right, rain, hair, silk, bead, trail, slope);
}
#endif
