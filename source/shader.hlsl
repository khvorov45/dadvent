struct VSInput {
    float2 pos : POSITION;
};

struct PSInput {
    float4 pos : SV_POSITION;
};

PSInput vs(VSInput input) {
    PSInput output;
    output.pos = float4(input.pos, 0, 1);
    return output;
}

float4 ps(PSInput input) : SV_TARGET {
    float4 color = {1, 0.5, 0.25, 1};
    return color;
}