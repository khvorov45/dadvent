struct VSInput {
    uint vertexIndex: SV_VertexID;
    float2 topleft: TOPLEFT;
    float2 botright: BOTRIGHT;
    float2 textopleft: TEXTOPLEFT;
    float2 texbotright: TEXBOTRIGHT;
    float4 color: COLOR;
};

struct PSInput {
    float4 pos : SV_POSITION;
    float2 uv : TEXCOORD;
    float4 color : COLOR;
};

cbuffer cbuffer0 : register(b0) {
    float2 texdim;
}

cbuffer cbuffer1 : register(b1) {
    float2 vpdim;
}

sampler sampler0 : register(s0);

Texture2D<float4> texture0 : register(t0);

PSInput vs(VSInput input) {
    float2 vertices[4];
    vertices[0] = input.topleft;
    vertices[1] = float2(input.botright.x, input.topleft.y);
    vertices[2] = float2(input.topleft.x, input.botright.y);
    vertices[3] = input.botright;

    float2 vertex = vertices[input.vertexIndex] / vpdim * 2 - 1;
    vertex.y *= -1;

    float2 uvs[4];
    uvs[0] = input.textopleft;
    uvs[1] = float2(input.texbotright.x, input.textopleft.y);
    uvs[2] = float2(input.textopleft.x, input.texbotright.y);
    uvs[3] = input.texbotright;

    float2 uv = uvs[input.vertexIndex] / texdim;

    PSInput output;
    output.pos = float4(vertex, 0, 1);
    output.uv = uv;
    output.color = input.color;
    return output;
}

float4 ps(PSInput input) : SV_TARGET {
    float4 tex = texture0.Sample(sampler0, input.uv);
    float4 color = input.color;
    color.a *= tex.a;
    return color;
}