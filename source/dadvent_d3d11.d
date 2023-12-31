module dadvent_d3d11;

import microui;
import sysd3d11;
import font;
import shader_vs;
import shader_ps;
import dadvent;

pragma(lib, "d3d11");
pragma(lib, "dxguid");

struct V2 {
    float x;
    float y;

    this(float x_, float y_) {
        x = x_;
        y = y_;
    }

    this(int x_, int y_) {
        x = cast(float)x_;
        y = cast(float)y_;
    }

    this(mu_Vec2 muvec2) {
        x = cast(float)muvec2.x;
        y = cast(float)muvec2.y;
    }

    V2 opBinary(string op)(float rhs) {
        V2 result = V2(mixin("x", op, "rhs"), mixin("y", op, "rhs"));
        return result;
    }

    V2 opBinary(string op: "+")(V2 rhs) {
        V2 result = V2(x + rhs.x, y + rhs.y);
        return result;
    }

    V2 opBinary(string op: "-")(V2 rhs) {
        V2 result = V2(x - rhs.x, y - rhs.y);
        return result;
    }

    void opOpAssign(string op: "+")(V2 rhs) { 
        x += rhs.x;
        y += rhs.y;
    }
}

struct Rect {
    V2 topleft;
    V2 dim;
    V2 botright() => topleft + dim;

    this(V2 topleft_, V2 dim_) {
        topleft = topleft_;
        dim = dim_;
    }

    this(mu_Rect murect) {
        topleft = V2(murect.x, murect.y);
        dim = V2(murect.w, murect.h);
    }

    Rect clip(Rect bounds) {
        float leftClippped = max(topleft.x, bounds.topleft.x);
        float rightClippped = min(botright.x, bounds.botright.x);
        float topClippped = max(topleft.y, bounds.topleft.y);
        float botClippped = min(botright.y, bounds.botright.y);

        rightClippped = max(leftClippped, rightClippped);
        botClippped = max(topClippped, botClippped);

        Rect result = Rect(V2(leftClippped, topClippped), V2(rightClippped - leftClippped, botClippped - topClippped));
        return result;
    }
}

struct Color {
    float r = 1;
    float g = 1;
    float b = 1;
    float a = 1;

    this(mu_Color mucol) {
        r = cast(float)mucol.r / 255.0f;
        g = cast(float)mucol.g / 255.0f;
        b = cast(float)mucol.b / 255.0f;
        a = cast(float)mucol.a / 255.0f;
    }
}

struct VSInput {
    V2 topleft;
    V2 dim;
    V2 textopleft;
    V2 texdim;
    Color color;
}

struct Font {
    ID3D11Buffer* constBufferTexdim;
    long chWidth;
    long chHeight;
}

struct D3D11Renderer {
    ID3D11Device* device;
    ID3D11DeviceContext* context;
    IDXGISwapChain1* swapchain;
    ID3D11RenderTargetView* rtview;
    ID3D11VertexShader* vshader;
    ID3D11PixelShader* pshader;
    ID3D11InputLayout* layout;
    ID3D11RasterizerState* rasterizer;
    ID3D11ShaderResourceView* textureView;
    ID3D11SamplerState* sampler;
    ID3D11BlendState* blend;
    Rect clipRect;

    struct Window {
        HWND hwnd;
        int width;
        int height;
    }
    Window window;

    struct Rects {
        ID3D11Buffer* buffer;
        D3D11_MAPPED_SUBRESOURCE mapped;
        long length;
        long capacity;
    }
    Rects rects;

    struct ConstBufferViewport {
        V2 vpdim;
        byte[8] pad;
    }
    ID3D11Buffer* constBufferViewport;

    struct ConstBufferFontTexdim {
        V2 texdim;
        byte[8] pad;
    }
    Font font;

    extern (C) alias DXGIGetDebugInterfaceType = HRESULT function(IID*, void**);
    this(void* hwnd_) {
        window.hwnd = cast(HWND)hwnd_;

        // NOTE(khvorov) D3D11 device and context
        {
            D3D_FEATURE_LEVEL[1] levels = [D3D_FEATURE_LEVEL_11_0];

            uint flags = 0;
            debug flags = D3D11_CREATE_DEVICE_DEBUG;

            const uint D3D11_SDK_VERSION = 7;
            HRESULT D3D11CreateDeviceResult = D3D11CreateDevice(
                pAdapter: null,
                DriverType: D3D_DRIVER_TYPE_HARDWARE,
                Software: null,
                Flags: flags,
                pFeatureLevels: levels.ptr,
                FeatureLevels: levels.length,
                SDKVersion: D3D11_SDK_VERSION,
                ppDevice: &device,
                pFeatureLevel: null,
                ppImmediateContext: &context,
            );

            assert(D3D11CreateDeviceResult == 0);
        }

        // NOTE(khvorov) Enable debug breaks on API errors
        debug {
            {
                ID3D11InfoQueue* info;
                HRESULT QueryInterfaceResult = device.lpVtbl.QueryInterface(device, &IID_ID3D11InfoQueue, cast(void**)&info);
                assert(QueryInterfaceResult == 0);
                assert(info);

                HRESULT SetBreakOnSeverityCorruptionResult = info.lpVtbl.SetBreakOnSeverity(info, D3D11_MESSAGE_SEVERITY_CORRUPTION, true);
                HRESULT SetBreakOnSeverityErrorResult = info.lpVtbl.SetBreakOnSeverity(info, D3D11_MESSAGE_SEVERITY_ERROR, true);
                HRESULT SetBreakOnSeverityWarningResult = info.lpVtbl.SetBreakOnSeverity(info, D3D11_MESSAGE_SEVERITY_WARNING, true);

                assert(SetBreakOnSeverityCorruptionResult == 0);
                assert(SetBreakOnSeverityErrorResult == 0);
                assert(SetBreakOnSeverityWarningResult == 0);

                info.lpVtbl.Release(info);
            }

            HMODULE dxgiDebug = LoadLibraryA("dxgidebug.dll");
            if (dxgiDebug) {
                FARPROC DXGIGetDebugInterfaceAddress = GetProcAddress(dxgiDebug, "DXGIGetDebugInterface");
                assert(DXGIGetDebugInterfaceAddress);
                DXGIGetDebugInterfaceType DXGIGetDebugInterface = cast(DXGIGetDebugInterfaceType)DXGIGetDebugInterfaceAddress;

                IDXGIInfoQueue* info;
                HRESULT DXGIGetDebugInterfaceResult =
                    DXGIGetDebugInterface(&IID_IDXGIInfoQueue, cast(void**)&info);
                assert(DXGIGetDebugInterfaceResult == 0);
                assert(info);

                HRESULT SetBreakOnSeverityCorruptionResult = info.lpVtbl.SetBreakOnSeverity(info, DXGI_DEBUG_ALL, DXGI_INFO_QUEUE_MESSAGE_SEVERITY_CORRUPTION, true);
                HRESULT SetBreakOnSeverityErrorResult = info.lpVtbl.SetBreakOnSeverity(info, DXGI_DEBUG_ALL, DXGI_INFO_QUEUE_MESSAGE_SEVERITY_ERROR, true);
                HRESULT SetBreakOnSeverityWarningResult = info.lpVtbl.SetBreakOnSeverity(info, DXGI_DEBUG_ALL, DXGI_INFO_QUEUE_MESSAGE_SEVERITY_WARNING, true);

                assert(SetBreakOnSeverityCorruptionResult == 0);
                assert(SetBreakOnSeverityErrorResult == 0);
                assert(SetBreakOnSeverityWarningResult == 0);

                info.lpVtbl.Release(info);
            }
        }

        // NOTE(khvorov) Swapchain
        {
            IDXGIDevice* dxgiDevice;
            HRESULT QueryInterfaceResult = device.lpVtbl.QueryInterface(device, &IID_IDXGIDevice, cast(void**)&dxgiDevice);
            assert(QueryInterfaceResult == 0);

            IDXGIAdapter* dxgiAdapter;
            HRESULT GetAdapterResult = dxgiDevice.lpVtbl.GetAdapter(dxgiDevice, &dxgiAdapter);
            assert(GetAdapterResult == 0);

            IDXGIFactory2* dxgiFactory;
            HRESULT GetParentResult = dxgiAdapter.lpVtbl.GetParent(dxgiAdapter, &IID_IDXGIFactory2, cast(void**)&dxgiFactory);
            assert(GetParentResult == 0);

            DXGI_SWAP_CHAIN_DESC1 desc = {
                Format: DXGI_FORMAT_R8G8B8A8_UNORM,
                SampleDesc: {Count: 1},
                BufferUsage: DXGI_USAGE_RENDER_TARGET_OUTPUT,
                BufferCount: 2,
                Scaling: DXGI_SCALING_NONE,
                SwapEffect: DXGI_SWAP_EFFECT_FLIP_DISCARD,
            };

            HRESULT CreateSwapChainForHwndResult = dxgiFactory.lpVtbl.CreateSwapChainForHwnd(
                This: dxgiFactory,
                pDevice: cast(IUnknown*)device,
                hWnd: window.hwnd,
                pDesc: &desc,
                pFullscreenDesc: null,
                pRestrictToOutput: null,
                ppSwapChain: &swapchain
            );
            assert(CreateSwapChainForHwndResult == 0);

            const uint DXGI_MWA_NO_ALT_ENTER = 1 << 1;
            HRESULT MakeWindowAssociationResult = dxgiFactory.lpVtbl.MakeWindowAssociation(dxgiFactory, window.hwnd, DXGI_MWA_NO_ALT_ENTER);
            assert(MakeWindowAssociationResult == 0);

            dxgiDevice.lpVtbl.Release(dxgiDevice);
            dxgiAdapter.lpVtbl.Release(dxgiAdapter);
            dxgiFactory.lpVtbl.Release(dxgiFactory);
        }

        // NOTE(khvorov) Constant buffer viewport
        {
            D3D11_BUFFER_DESC desc = {
                ByteWidth: ConstBufferViewport.sizeof,
                Usage: D3D11_USAGE_DYNAMIC,
                BindFlags: D3D11_BIND_CONSTANT_BUFFER,
                CPUAccessFlags: D3D11_CPU_ACCESS_WRITE,
            };
            HRESULT CreateBufferResult = device.lpVtbl.CreateBuffer(device, &desc, null, &constBufferViewport);
            assert(CreateBufferResult == 0);
        }

        // NOTE(khvorov) Rect buffer
        {
            rects.capacity = 1024 * 1024;
            D3D11_BUFFER_DESC desc = {
                ByteWidth: cast(uint)(VSInput.sizeof * rects.capacity),
                Usage: D3D11_USAGE_DYNAMIC,
                BindFlags: D3D11_BIND_VERTEX_BUFFER,
                CPUAccessFlags: D3D11_CPU_ACCESS_WRITE,
            };
            HRESULT CreateBufferResult = device.lpVtbl.CreateBuffer(device, &desc, null, &rects.buffer);
            assert(CreateBufferResult == 0);
            context.lpVtbl.Map(context, cast(ID3D11Resource*)rects.buffer, 0, D3D11_MAP_WRITE_DISCARD, 0, &rects.mapped);
        }

        // NOTE(khvorov) Shaders
        {
            HRESULT CreateVertexShaderResult = device.lpVtbl.CreateVertexShader(
                device, globalCompiledShader_shader_vs.ptr, globalCompiledShader_shader_vs.length, null, &vshader
            );
            assert(CreateVertexShaderResult == 0);

            HRESULT CreatePixelShaderResult = device.lpVtbl.CreatePixelShader(
                device, globalCompiledShader_shader_ps.ptr, globalCompiledShader_shader_ps.length, null, &pshader
            );
            assert(CreatePixelShaderResult == 0);

            D3D11_INPUT_ELEMENT_DESC[5] desc = [
                { "TOPLEFT", 0, DXGI_FORMAT_R32G32_FLOAT, 0, VSInput.topleft.offsetof, D3D11_INPUT_PER_INSTANCE_DATA, 1 },
                { "DIM", 0, DXGI_FORMAT_R32G32_FLOAT, 0, VSInput.dim.offsetof, D3D11_INPUT_PER_INSTANCE_DATA, 1 },
                { "TEXTOPLEFT", 0, DXGI_FORMAT_R32G32_FLOAT, 0, VSInput.textopleft.offsetof, D3D11_INPUT_PER_INSTANCE_DATA, 1 },
                { "TEXDIM", 0, DXGI_FORMAT_R32G32_FLOAT, 0, VSInput.texdim.offsetof, D3D11_INPUT_PER_INSTANCE_DATA, 1 },
                { "COLOR", 0, DXGI_FORMAT_R32G32B32A32_FLOAT, 0, VSInput.color.offsetof, D3D11_INPUT_PER_INSTANCE_DATA, 1 },
            ];

            HRESULT CreateInputLayoutResult = device.lpVtbl.CreateInputLayout(
                device, desc.ptr, desc.length,
                globalCompiledShader_shader_vs.ptr, globalCompiledShader_shader_vs.length, &layout
            );
            assert(CreateInputLayoutResult == 0);
        }

        // NOTE(khvorov) Rasterizer
        {
            D3D11_RASTERIZER_DESC desc = {
                FillMode: D3D11_FILL_SOLID,
                CullMode: D3D11_CULL_NONE,
            };
            HRESULT CreateRasterizerStateResult = device.lpVtbl.CreateRasterizerState(device, &desc, &rasterizer);
            assert(CreateRasterizerStateResult == 0);
        }

        // NOTE(khvorov) Texture
        {
            const long chCount = 128;
            const long chWidth = 8;
            const long chHeight = 16;
            const long alphaWidth = chCount * chWidth;
            const long alphaPitch = alphaWidth;
            const long alphaHeight = chHeight;
            const long alphaSize = alphaPitch * alphaHeight;
            ubyte[alphaSize] alpha;
            for (ubyte ch = 0; ch < chCount; ch++) {
                ubyte[] chBytes = cast(ubyte[])(globalFontData[ch * 2 .. ch * 2 + 2]);
                foreach (chByteIndex, chByte; chBytes) {
                    for (ubyte offset = 0; offset < 8; offset++) {
                        ubyte mask = cast(ubyte)(1 << offset);
                        if (chByte & mask) {
                            long alphaIndex = ch * chWidth + offset + (chByteIndex * alphaPitch);
                            alpha[alphaIndex] = cast(ubyte)255;
                        }
                    }
                }
            }
            font.chWidth = chWidth;
            font.chHeight = chHeight;

            // NOTE(khvorov) Fill the first character to be used for solid rects
            for (long row = 0; row < chHeight; row++) {
                for (long col = 0; col < chWidth; col++) {
                    long index = row * alphaPitch + col;
                    alpha[index] = 255;
                }
            }

            D3D11_TEXTURE2D_DESC desc = {
                Width: alphaWidth,
                Height: alphaHeight,
                MipLevels: 1,
                ArraySize: 1,
                Format: DXGI_FORMAT_A8_UNORM,
                SampleDesc: {Count: 1},
                Usage: D3D11_USAGE_IMMUTABLE,
                BindFlags: D3D11_BIND_SHADER_RESOURCE,
            };

            D3D11_SUBRESOURCE_DATA initial = {pSysMem: alpha.ptr, SysMemPitch: alphaPitch};

            ID3D11Texture2D* texture;
            HRESULT CreateTexture2DResult = device.lpVtbl.CreateTexture2D(device, &desc, &initial, &texture);
            assert(CreateTexture2DResult == 0);
            HRESULT CreateShaderResourceViewResult = device.lpVtbl.CreateShaderResourceView(device, cast(ID3D11Resource*)texture, null, &textureView);
            assert(CreateShaderResourceViewResult == 0);
            texture.lpVtbl.Release(texture);


            // NOTE(khvorov) Constant buffer texdim
            {
                D3D11_BUFFER_DESC texDesc = {
                    ByteWidth: ConstBufferViewport.sizeof,
                    Usage: D3D11_USAGE_IMMUTABLE,
                    BindFlags: D3D11_BIND_CONSTANT_BUFFER,
                };
                ConstBufferFontTexdim data = {texdim: V2(alphaWidth, alphaHeight)};
                D3D11_SUBRESOURCE_DATA texInitial = {&data};
                HRESULT CreateBufferResult = device.lpVtbl.CreateBuffer(device, &texDesc, &texInitial, &font.constBufferTexdim);
                assert(CreateBufferResult == 0);
            }
        }

        // NOTE(khvorov) Sampler
        {
            D3D11_SAMPLER_DESC desc = {
                Filter: D3D11_FILTER_MIN_MAG_MIP_POINT,
                AddressU: D3D11_TEXTURE_ADDRESS_CLAMP,
                AddressV: D3D11_TEXTURE_ADDRESS_CLAMP,
                AddressW: D3D11_TEXTURE_ADDRESS_CLAMP ,
            };
            HRESULT CreateSamplerStateResult = device.lpVtbl.CreateSamplerState(device, &desc, &sampler);
            assert(CreateSamplerStateResult == 0);
        }

        // NOTE(khvorov) Blend
        {
            D3D11_BLEND_DESC desc = {
                RenderTarget: [{
                    BlendEnable: TRUE,
                    SrcBlend: D3D11_BLEND_SRC_ALPHA,
                    DestBlend: D3D11_BLEND_INV_SRC_ALPHA,
                    BlendOp: D3D11_BLEND_OP_ADD,
                    SrcBlendAlpha: D3D11_BLEND_SRC_ALPHA,
                    DestBlendAlpha: D3D11_BLEND_INV_SRC_ALPHA,
                    BlendOpAlpha: D3D11_BLEND_OP_ADD,
                    RenderTargetWriteMask: D3D11_COLOR_WRITE_ENABLE_ALL,
                }],
            };
            HRESULT CreateBlendStateResult = device.lpVtbl.CreateBlendState(device, &desc, &blend);
            assert(CreateBlendStateResult == 0);
        }

        // NOTE(khvorov) Init the clip rect
        {
            RECT rect;
            BOOL GetClientRectResult = GetClientRect(window.hwnd, &rect);
            assert(GetClientRectResult);
            window.width = rect.right - rect.left;
            window.height = rect.bottom - rect.top;
            clipRect = Rect(V2(0, 0), V2(window.width, window.height));
        }
    }

    ~this() {
        device.lpVtbl.Release(device);
        context.lpVtbl.Release(context);
        swapchain.lpVtbl.Release(swapchain);
        if (rtview) {
            rtview.lpVtbl.Release(rtview);
        }
        vshader.lpVtbl.Release(vshader);
        pshader.lpVtbl.Release(pshader);
        layout.lpVtbl.Release(layout);
        rasterizer.lpVtbl.Release(rasterizer);
        context.lpVtbl.Unmap(context, cast(ID3D11Resource*)rects.buffer, 0);
        rects.buffer.lpVtbl.Release(rects.buffer);
        constBufferViewport.lpVtbl.Release(constBufferViewport);
        textureView.lpVtbl.Release(textureView);
        font.constBufferTexdim.lpVtbl.Release(font.constBufferTexdim);
        sampler.lpVtbl.Release(sampler);
        blend.lpVtbl.Release(blend);
    }

    void pushRect(VSInput data) {
        VSInput* buffer = cast(VSInput*)rects.mapped.pData;
        assert(rects.length >= 0 && rects.length < rects.capacity);
        buffer[rects.length] = data;
        rects.length += 1;
    }

    void pushSolidRect(Rect rect, Color color = Color()) {
        Rect clipped = rect.clip(clipRect);
        VSInput input = {clipped.topleft, clipped.dim, V2(0, 0), V2(font.chWidth, font.chHeight), color};
        pushRect(input);
    }

    void pushGlyph(char ch, V2 topleft, Color color = Color()) {
        Rect beforeClip = Rect(topleft, V2(font.chWidth, font.chHeight));
        Rect clipped = beforeClip.clip(clipRect);
        V2 texTopleftBeforeClip = V2(ch * font.chWidth, 0);
        V2 clipTopleftOffset = clipped.topleft - beforeClip.topleft;
        Rect texAferClip = Rect(texTopleftBeforeClip + clipTopleftOffset, clipped.dim);
        VSInput rect = {clipped.topleft, clipped.dim, texAferClip.topleft, texAferClip.dim, color};
        pushRect(rect);
    }

    void pushTextline(string line, V2 topleft, Color color = Color()) {
        V2 currentTopleft = topleft;
        foreach (ch; line) {
            pushGlyph(ch, currentTopleft, color);
            currentTopleft.x += font.chWidth;
        }
    }

    void draw() {
        {
            RECT rect;
            BOOL GetClientRectResult = GetClientRect(window.hwnd, &rect);
            if (GetClientRectResult) {
                int width = rect.right - rect.left;
                int height = rect.bottom - rect.top;

                if (rtview == null || width != window.width || height != window.height) {
                    if (rtview) {
                        context.lpVtbl.ClearState(context);
                        rtview.lpVtbl.Release(rtview);
                        rtview = null;
                    }

                    if (width != 0 && height != 0) {
                        HRESULT ResizeBuffersResult = swapchain.lpVtbl.ResizeBuffers(swapchain, 0, width, height, DXGI_FORMAT_UNKNOWN, 0);
                        assert(ResizeBuffersResult == 0);

                        ID3D11Texture2D* backbuffer;
                        HRESULT GetBufferResult = swapchain.lpVtbl.GetBuffer(
                            swapchain, 0, &IID_ID3D11Texture2D, cast(void**)&backbuffer
                        );
                        assert(GetBufferResult == 0);
                        assert(backbuffer);

                        HRESULT CreateRenderTargetViewResult = device.lpVtbl.CreateRenderTargetView(
                            device, cast(ID3D11Resource*)backbuffer, null, &rtview
                        );
                        assert(CreateRenderTargetViewResult == 0);
                        assert(rtview);

                        backbuffer.lpVtbl.Release(backbuffer);
                    }

                    window.width = width;
                    window.height = height;
                }
            }
            clipRect = Rect(V2(0, 0), V2(window.width, window.height));
        }

        if (rtview) {
            assert(window.width != 0 && window.height != 0);

            D3D11_VIEWPORT viewport = {
                Width: window.width,
                Height: window.height,
            };

            float[4] color = [0, 0, 0, 0];
            context.lpVtbl.ClearRenderTargetView(context, rtview, &color[0]);

            context.lpVtbl.IASetInputLayout(context, layout);
            context.lpVtbl.IASetPrimitiveTopology(context, D3D11_PRIMITIVE_TOPOLOGY_TRIANGLESTRIP);
            context.lpVtbl.VSSetShader(context, vshader, null, 0);

            {
                D3D11_MAPPED_SUBRESOURCE mapped;
                context.lpVtbl.Map(context, cast(ID3D11Resource*)constBufferViewport, 0, D3D11_MAP_WRITE_DISCARD, 0, &mapped);
                ConstBufferViewport* buffer = cast(ConstBufferViewport*)mapped.pData;
                buffer.vpdim = V2(window.width, window.height);
                context.lpVtbl.Unmap(context, cast(ID3D11Resource*)constBufferViewport, 0);
            }

            {
                ID3D11Buffer*[2] buffers = [font.constBufferTexdim, constBufferViewport];
                context.lpVtbl.VSSetConstantBuffers(context, 0, buffers.length, buffers.ptr);
            }

            {
                context.lpVtbl.Unmap(context, cast(ID3D11Resource*)rects.buffer, 0);
                ID3D11Buffer*[1] buffers = [rects.buffer];
                uint[1] strides = [VSInput.sizeof];
                uint[1] offsets = [0];
                context.lpVtbl.IASetVertexBuffers(context, 0, buffers.length, buffers.ptr, strides.ptr, offsets.ptr);
            }

            context.lpVtbl.RSSetViewports(context, 1, &viewport);
            context.lpVtbl.RSSetState(context, rasterizer);
            context.lpVtbl.PSSetShader(context, pshader, null, 0);

            {
                ID3D11ShaderResourceView*[1] resources = [textureView];
                context.lpVtbl.PSSetShaderResources(context, 0, resources.length, resources.ptr);
            }

            {
                ID3D11SamplerState*[1] samplers = [sampler];
                context.lpVtbl.PSSetSamplers(context, 0, samplers.length, samplers.ptr);
            }

            context.lpVtbl.OMSetRenderTargets(context, 1, &rtview, null);
            context.lpVtbl.OMSetBlendState(context, blend, null, 0xffffffff);

            context.lpVtbl.DrawInstanced(context, 4, cast(uint)rects.length, 0, 0);
            rects.length = 0;
            context.lpVtbl.Map(context, cast(ID3D11Resource*)rects.buffer, 0, D3D11_MAP_WRITE_DISCARD, 0, &rects.mapped);

            HRESULT PresentResult = swapchain.lpVtbl.Present(swapchain, 1, 0);
            const HRESULT DXGI_STATUS_OCCLUDED = 0x087A0001L;
            if (PresentResult == DXGI_STATUS_OCCLUDED) {
                Sleep(10);
            } else {
                assert(PresentResult == 0);
            }
        }
    }
}
