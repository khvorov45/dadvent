struct VSInput {
    uint vertexIndex: SV_VertexID;
    float2 topleft: TOPLEFT;
    float2 botright: BOTRIGHT;
};

struct PSInput {
    float4 pos : SV_POSITION;
};

float2 toclip(float2 vert) {
    // TODO(khvorov) Pass in dimensions
    float2 vpdim = float2(500, 500);
    float2 result = vert / vpdim * 2 - 1;
    return result;
}

PSInput vs(VSInput input) {
    float2 vertices[4];
    vertices[0] = toclip(input.topleft);
    vertices[1] = toclip(float2(input.botright.x, input.topleft.y));
    vertices[2] = toclip(float2(input.topleft.x, input.botright.y));
    vertices[3] = toclip(input.botright);
    float2 vertex = vertices[input.vertexIndex];
    vertex.y *= -1;

    PSInput output;
    output.pos = float4(vertex, 0, 1);
    return output;
}

float4 ps(PSInput input) : SV_TARGET {
    float4 color = {1, 0.5, 0.25, 1};
    return color;
}