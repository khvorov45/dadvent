struct VSInput {
    uint vertexIndex: SV_VertexID;
};

struct PSInput {
    float4 pos : SV_POSITION;
};

PSInput vs(VSInput input) {
    float2 vertices[4];
    vertices[0] = float2(-1,  1);
    vertices[1] = float2( 1,  1);
    vertices[2] = float2(-1, -1);
    vertices[3] = float2( 1, -1);
    float2 vertex = vertices[input.vertexIndex];

    PSInput output;
    output.pos = float4(vertex, 0, 1);
    return output;
}

float4 ps(PSInput input) : SV_TARGET {
    float4 color = {1, 0.5, 0.25, 1};
    return color;
}