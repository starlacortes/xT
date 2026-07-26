import SceneKit

enum BodyHeatMapShader {
    static let maxZones = 64
    static let maxTaps  = 4

    static let surfaceModifier: String = """
    #pragma arguments
    float u_currentTime;
    float4x4 u_invViewMatrix;
    texture2d<float> u_zoneTex;
    texture2d<float> u_zoneMetaTex;
    texture2d<float> u_tapTex;

    #pragma body

    float4 worldPos4 = u_invViewMatrix * float4(_surface.position, 1.0);
    float3 worldPos  = worldPos4.xyz / worldPos4.w;
    float3 worldNrm  = normalize((u_invViewMatrix * float4(_surface.normal, 0.0)).xyz);

    float3 albedo      = _surface.diffuse.rgb;
    float totalRed     = 0.0;
    float totalWhite   = 0.0;
    float totalOverlap = 0.0;
    float avoidMask    = 0.0;
    float recommendedMask = 0.0;

    // ---- Heat map from stored zone data ----
    for (int i = 0; i < 64; i++) {
        float4 zd = u_zoneTex.read(uint2(i, 0));
        float4 md = u_zoneMetaTex.read(uint2(i, 0));

        float3 zonePos    = zd.xyz;
        float  zoneRadius = zd.w;
        if (zoneRadius <= 0.0) { continue; }

        float whiteRadius = md.x;
        float zoneCount   = md.y;
        int   flags       = int(round(md.z));
        bool isAvoided    = (flags & 1) != 0;
        bool isSelected   = (flags & 2) != 0;
        bool isPreferred  = (flags & 4) != 0;
        bool isRecommended = (flags & 8) != 0;

        float dist     = distance(worldPos, zonePos);
        float outerRad = zoneRadius * 1.6;

        float3 toZone  = zonePos - worldPos;
        float  zNdot   = dot(worldNrm, normalize(toZone));
        float  fadeBack = smoothstep(-0.08, 0.08, zNdot);

        if (isRecommended && zoneCount <= 0.0 && !isSelected) {
            float recOuter = zoneRadius * 2.2;
            float recGrad = (1.0 - smoothstep(zoneRadius * 0.6, recOuter, dist)) * fadeBack;
            recommendedMask = max(recommendedMask, recGrad * 0.22);
            continue;
        }

        if (isAvoided) {
            avoidMask = max(avoidMask, smoothstep(outerRad, zoneRadius, dist) * fadeBack);
            continue;
        }
        if (isPreferred) {
            float ringA = 1.0 - smoothstep(0.0, 0.018, abs(dist - zoneRadius));
            if (ringA > 0.0) { totalRed += ringA * 0.12; }
            continue;
        }
        if (dist < outerRad) {
            float redContrib = (1.0 - smoothstep(zoneRadius, outerRad, dist)) * fadeBack;
            totalRed += redContrib;
            if (redContrib > 0.28) { totalOverlap += fadeBack; }
            if (whiteRadius > 0.0 && dist < whiteRadius) {
                totalWhite += (1.0 - smoothstep(0.0, whiteRadius, dist)) * fadeBack;
            }
        }
        if (isSelected) {
            float odist = abs(dist - zoneRadius);
            float oa = (1.0 - smoothstep(0.0, 0.020, odist)
                        * (1.0 - smoothstep(outerRad, outerRad + 0.035, dist))) * fadeBack;
            if (oa > 0.0) { albedo = mix(albedo, float3(1.0, 0.35, 0.56), oa * 0.7); }
        }
    }

    totalRed      = clamp(totalRed, 0.0, 1.0);
    totalWhite    = clamp(totalWhite, 0.0, 1.0);
    float overlapWhite = (totalOverlap >= 2.0) ? 1.0 : 0.0;

    albedo = mix(albedo, float3(1.0, 0.18, 0.15), totalRed * 0.85);
    albedo = mix(albedo, float3(1.0, 0.95, 0.88), max(totalWhite, overlapWhite) * 0.92);
    albedo = mix(albedo, float3(0.45, 0.44, 0.50), avoidMask * 0.40);
    albedo = mix(albedo, float3(0.88, 0.86, 0.92), recommendedMask);

    // ---- Unified tap glow (persistent dot + expanding ripple) ----
    float3 tapAccum  = float3(0.0, 0.0, 0.0);
    float  alphaAccum = 0.0;

    for (int t = 0; t < 4; t++) {
        float4 td = u_tapTex.read(uint2(t, 0));
        float startTime = td.w;
        if (startTime == 0.0) { continue; }

        bool isPersistent = (startTime < 0.0);
        float3 tapCenter = td.xyz;
        float  d = distance(worldPos, tapCenter);

        float dotR   = 0.045;
        float dotA   = 0.0;
        float3 dotCol = float3(0.94, 0.06, 0.04);

        if (isPersistent) {
            float patchR     = 0.04;
            float innerR     = patchR * 0.35;
            float patchEdge  = 1.0 - smoothstep(innerR, patchR, d);
            float3 patchCol   = float3(0.82, 0.12, 0.08);
            float  patchA     = patchEdge * 0.78;
            tapAccum   = mix(tapAccum, patchCol, patchA);
            alphaAccum = max(alphaAccum, patchA);
            continue;
        }

        float3 local  = worldPos - tapCenter;
        float  gridX  = abs(fract(local.x * 42.0) - 0.5) * 2.0;
        float  gridY  = abs(fract(local.y * 42.0) - 0.5) * 2.0;
        float  lineX  = 1.0 - smoothstep(0.04, 0.06, abs(gridX - 0.5));
        float  lineY  = 1.0 - smoothstep(0.04, 0.06, abs(gridY - 0.5));
        float  mesh   = max(lineX, lineY);
        float  meshBlend = 0.45 + 0.55 * mesh;

        float elapsed = u_currentTime - startTime;
        float animEnd = 0.7;

        float rippleR = 0.0;
        float3 rippleCol = float3(0.0, 0.0, 0.0);

        if (elapsed > 0.0 && elapsed < animEnd) {
            float speed  = 1.2;
            float front  = speed * elapsed;
            float inner  = front * 0.88;
            float outer  = front * 1.40;

            float inside   = 1.0 - smoothstep(0.0, outer, d);
            float whitePart = 1.0 - smoothstep(inner, outer, d);

            float3 color = mix(float3(0.94, 0.08, 0.05),
                               float3(1.0, 0.98, 0.94),
                               whitePart);
            float fade = 1.0 - smoothstep(animEnd * 0.45, animEnd, elapsed);
            rippleR   = inside * fade * meshBlend;
            rippleCol = color;
        }

        float3 combined = mix(float3(0.0, 0.0, 0.0), rippleCol, rippleR);
        combined += dotCol * dotA * (1.0 - rippleR);
        float totalA = max(dotA, rippleR * 0.75);

        tapAccum  = mix(tapAccum, combined, totalA);
        alphaAccum = max(alphaAccum, totalA);
    }

    albedo = mix(albedo, tapAccum, alphaAccum);

    _surface.diffuse.rgb = albedo;
    """
}
