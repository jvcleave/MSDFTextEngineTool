#include <metal_stdlib>
using namespace metal;

struct MSDFGlyphInstance
{
    float4 screenRect;
    float4 atlasUVRect;
    float4 color;
};

struct MSDFUniforms
{
    float2 viewportSize;
    float distanceRange;
    float padding;
};

struct VertexOut
{
    float4 position [[position]];
    float2 uv;
    float4 color;
};

inline float msdfMedian3(float r, float g, float b)
{
    return max(min(r, g), min(max(r, g), b));
}

vertex VertexOut msdf_vertex(
    uint vertexId [[vertex_id]],
    uint instanceId [[instance_id]],
    const device MSDFGlyphInstance *instances [[buffer(0)]],
    constant MSDFUniforms &u [[buffer(1)]]
)
{
    float2 positions[6];
    positions[0] = float2(0.0, 0.0);
    positions[1] = float2(1.0, 0.0);
    positions[2] = float2(0.0, 1.0);
    positions[3] = float2(1.0, 0.0);
    positions[4] = float2(1.0, 1.0);
    positions[5] = float2(0.0, 1.0);

    MSDFGlyphInstance inst = instances[instanceId];
    float2 q = positions[vertexId];
    float2 px = float2(
        mix(inst.screenRect.x, inst.screenRect.z, q.x),
        mix(inst.screenRect.y, inst.screenRect.w, q.y)
    );
    float2 ndc = float2(
        (px.x / u.viewportSize.x) * 2.0 - 1.0,
        1.0 - (px.y / u.viewportSize.y) * 2.0
    );

    VertexOut out;
    out.position = float4(ndc, 0.0, 1.0);
    out.uv = float2(
        mix(inst.atlasUVRect.x, inst.atlasUVRect.z, q.x),
        mix(inst.atlasUVRect.y, inst.atlasUVRect.w, q.y)
    );
    out.color = inst.color;
    return out;
}

fragment float4 msdf_fragment(
    VertexOut in [[stage_in]],
    texture2d<float, access::sample> atlas [[texture(0)]],
    sampler samp [[sampler(0)]]
)
{
    float3 msdf = atlas.sample(samp, in.uv).rgb;
    float signedDistance = msdfMedian3(msdf.r, msdf.g, msdf.b) - 0.5;
    float smoothing = abs(dfdx(signedDistance)) + abs(dfdy(signedDistance));
    float alpha = smoothstep(-max(smoothing, 0.0001), max(smoothing, 0.0001), signedDistance);
    return float4(in.color.rgb, in.color.a * alpha);
}
