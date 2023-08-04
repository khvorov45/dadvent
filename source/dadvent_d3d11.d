module dadvent_d3d11;

import sysd3d11;
import shader_vs;
import shader_ps;

pragma(lib, "d3d11");
pragma(lib, "dxguid");

struct D3D11Renderer {
    struct Window {
        HWND hwnd;
        int width;
        int height;
    }
    Window window;

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

    struct V2 {
        float x;
        float y;
    }
    struct Color {
        float r;
        float g;
        float b;
        float a;
    }
    struct VSInput {
        V2 topleft;
        V2 botright;
        V2 textopleft;
        V2 texbotright;
        Color color;
    }
    ID3D11Buffer* rectBuffer;

    struct ConstBufferViewport {
        V2 vpdim;
        byte[8] pad;
    }
    ID3D11Buffer* constBufferViewport;

    struct ConstBufferTexdim {
        V2 texdim;
        byte[8] pad;
    }
    ID3D11Buffer* constBufferTexdim;

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
                HRESULT QueryInterfaceResult =
                    device.lpVtbl.QueryInterface(device, &IID_ID3D11InfoQueue, cast(void**)&info);
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

        // NOTE(khvorov) Constant buffer texdim
        {
            D3D11_BUFFER_DESC desc = {
                ByteWidth: ConstBufferViewport.sizeof,
                Usage: D3D11_USAGE_IMMUTABLE,
                BindFlags: D3D11_BIND_CONSTANT_BUFFER,
            };
            ConstBufferTexdim data = {texdim: {2, 2}};
            D3D11_SUBRESOURCE_DATA initial = {&data};
            HRESULT CreateBufferResult = device.lpVtbl.CreateBuffer(device, &desc, &initial, &constBufferTexdim);
            assert(CreateBufferResult == 0);
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
            VSInput[2] data = [
                {{10, 10}, {20, 20}, {0, 0}, {2, 2}, {1, 1, 1, 1}},
                {{50, 50}, {80, 80}, {0, 0}, {2, 2}, {1, 0, 0, 1}},
            ];

            D3D11_BUFFER_DESC desc = {
                ByteWidth: data.sizeof,
                Usage: D3D11_USAGE_DYNAMIC,
                BindFlags: D3D11_BIND_VERTEX_BUFFER,
                CPUAccessFlags: D3D11_CPU_ACCESS_WRITE,
            };

            D3D11_SUBRESOURCE_DATA initial = {data.ptr};
            HRESULT CreateBufferResult = device.lpVtbl.CreateBuffer(device, &desc, &initial, &rectBuffer);
            assert(CreateBufferResult == 0);
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
                { "BOTRIGHT", 0, DXGI_FORMAT_R32G32_FLOAT, 0, VSInput.botright.offsetof, D3D11_INPUT_PER_INSTANCE_DATA, 1 },
                { "TEXTOPLEFT", 0, DXGI_FORMAT_R32G32_FLOAT, 0, VSInput.textopleft.offsetof, D3D11_INPUT_PER_INSTANCE_DATA, 1 },
                { "TEXBOTRIGHT", 0, DXGI_FORMAT_R32G32_FLOAT, 0, VSInput.texbotright.offsetof, D3D11_INPUT_PER_INSTANCE_DATA, 1 },
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
            D3D11_TEXTURE2D_DESC desc = {
                Width: 2,
                Height: 2,
                MipLevels: 1,
                ArraySize: 1,
                Format: DXGI_FORMAT_A8_UNORM,
                SampleDesc: {Count: 1},
                Usage: D3D11_USAGE_IMMUTABLE,
                BindFlags: D3D11_BIND_SHADER_RESOURCE,
            };

            byte[4] pixels = cast(byte[4])[10, 100, 200, 255];
            D3D11_SUBRESOURCE_DATA initial = {pSysMem: pixels.ptr, SysMemPitch: 2};

            ID3D11Texture2D* texture;
            HRESULT CreateTexture2DResult = device.lpVtbl.CreateTexture2D(device, &desc, &initial, &texture);
            assert(CreateTexture2DResult == 0);
            HRESULT CreateShaderResourceViewResult = device.lpVtbl.CreateShaderResourceView(device, cast(ID3D11Resource*)texture, null, &textureView);
            assert(CreateShaderResourceViewResult == 0);
            texture.lpVtbl.Release(texture);
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
    }

    void destroy() {
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
        rectBuffer.lpVtbl.Release(rectBuffer);
        constBufferViewport.lpVtbl.Release(constBufferViewport);
        textureView.lpVtbl.Release(textureView);
        constBufferTexdim.lpVtbl.Release(constBufferTexdim);
        sampler.lpVtbl.Release(sampler);
        blend.lpVtbl.Release(blend);
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
        }

        if (rtview) {
            assert(window.width != 0 && window.height != 0);

            D3D11_VIEWPORT viewport = {
                Width: window.width,
                Height: window.height,
            };

            float[4] color = [0.1, 0.1, 0.1, 1];
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
                ID3D11Buffer*[2] buffers = [constBufferTexdim, constBufferViewport];
                context.lpVtbl.VSSetConstantBuffers(context, 0, buffers.length, buffers.ptr);
            }

            {
                ID3D11Buffer*[1] buffers = [rectBuffer];
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
            context.lpVtbl.DrawInstanced(context, 4, 2, 0, 0);

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
