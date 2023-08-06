struct VSInput {
    uint vertexIndex: SV_VertexID;
    float2 topleft: TOPLEFT;
    float2 dim: DIM;
    float2 textopleft: TEXTOPLEFT;
    float2 texdim: TEXDIM;
    float4 color: COLOR;
};

struct PSInput {
    float4 pos : SV_POSITION;
    float2 uv : TEXCOORD;
    float4 color : COLOR;
};

cbuffer cbuffer0 : register(b0) {
    float2 cbuffer0_texdim;
}

cbuffer cbuffer1 : register(b1) {
    float2 cbuffer1_vpdim;
}

sampler sampler0 : register(s0);

Texture2D<float4> texture0 : register(t0);

PSInput vs(VSInput input) {
    float2 botright = input.topleft + input.dim;
    float2 texbotright = input.textopleft + input.texdim;

    float2 vertices[4];
    vertices[0] = input.topleft;
    vertices[1] = float2(botright.x, input.topleft.y);
    vertices[2] = float2(input.topleft.x, botright.y);
    vertices[3] = botright;

    float2 vertex = vertices[input.vertexIndex] / cbuffer1_vpdim * 2 - 1;
    vertex.y *= -1;

    float2 uvs[4];
    uvs[0] = input.textopleft;
    uvs[1] = float2(texbotright.x, input.textopleft.y);
    uvs[2] = float2(input.textopleft.x, texbotright.y);
    uvs[3] = texbotright;

    float2 uv = uvs[input.vertexIndex] / cbuffer0_texdim;

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