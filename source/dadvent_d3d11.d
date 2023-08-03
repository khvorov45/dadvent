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

    extern (C) alias DXGIGetDebugInterfaceType = HRESULT function(IID*, void**);
    this(void* hwnd_) {
        window.hwnd = cast(HWND)hwnd_;

        // NOTE(khvorov) D3D11 device and context
        {
            D3D_FEATURE_LEVEL[1] levels = [D3D_FEATURE_LEVEL_11_0];

            uint flags = 0;
            debug flags = D3D11_CREATE_DEVICE_DEBUG;

            const uint D3D11_SDK_VERSION = 7;
            // dfmt off
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
            // dfmt on

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
            HRESULT QueryInterfaceResult =
                device.lpVtbl.QueryInterface(device, &IID_IDXGIDevice, cast(void**)&dxgiDevice);
            assert(QueryInterfaceResult == 0);

            IDXGIAdapter* dxgiAdapter;
            HRESULT GetAdapterResult = dxgiDevice.lpVtbl.GetAdapter(dxgiDevice, &dxgiAdapter);
            assert(GetAdapterResult == 0);

            IDXGIFactory2* dxgiFactory;
            HRESULT GetParentResult =
                dxgiAdapter.lpVtbl.GetParent(dxgiAdapter, &IID_IDXGIFactory2, cast(void**)&dxgiFactory);
            assert(GetParentResult == 0);

            DXGI_SWAP_CHAIN_DESC1 desc = {
                Format: DXGI_FORMAT_R8G8B8A8_UNORM,
                SampleDesc: {Count: 1},
                BufferUsage: DXGI_USAGE_RENDER_TARGET_OUTPUT,
                BufferCount: 2,
                Scaling: DXGI_SCALING_NONE,
                SwapEffect: DXGI_SWAP_EFFECT_FLIP_DISCARD,
            };

            // dfmt off
            HRESULT CreateSwapChainForHwndResult = dxgiFactory.lpVtbl.CreateSwapChainForHwnd(
                This: dxgiFactory,
                pDevice: cast(IUnknown*)device,
                hWnd: window.hwnd,
                pDesc: &desc,
                pFullscreenDesc: null,
                pRestrictToOutput: null,
                ppSwapChain: &swapchain
            );
            // dfmt on
            assert(CreateSwapChainForHwndResult == 0);

            const uint DXGI_MWA_NO_ALT_ENTER = 1 << 1;
            HRESULT MakeWindowAssociationResult =
                dxgiFactory.lpVtbl.MakeWindowAssociation(dxgiFactory, window.hwnd, DXGI_MWA_NO_ALT_ENTER);
            assert(MakeWindowAssociationResult == 0);

            dxgiDevice.lpVtbl.Release(dxgiDevice);
            dxgiAdapter.lpVtbl.Release(dxgiAdapter);
            dxgiFactory.lpVtbl.Release(dxgiFactory);
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

            // dfmt off
            D3D11_INPUT_ELEMENT_DESC[1] desc = [
                { "POSITION", 0, DXGI_FORMAT_R32G32_FLOAT, 0, 0, D3D11_INPUT_PER_VERTEX_DATA, 0 }
            ];
            // dfmt on

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

            // TODO(khvorov) Do we need maxdepth even if we are not using depth?
            D3D11_VIEWPORT viewport = {
                Width: window.width,
                Height: window.height,
            };

            float[4] color = [0.1, 0.1, 0.1, 1];
            context.lpVtbl.ClearRenderTargetView(context, rtview, &color[0]);

            context.lpVtbl.IASetInputLayout(context, layout);
            context.lpVtbl.IASetPrimitiveTopology(context, D3D11_PRIMITIVE_TOPOLOGY_TRIANGLESTRIP);
            context.lpVtbl.VSSetShader(context, vshader, null, 0);
            context.lpVtbl.RSSetViewports(context, 1, &viewport);
            context.lpVtbl.RSSetState(context, rasterizer);
            context.lpVtbl.PSSetShader(context, pshader, null, 0);
            context.lpVtbl.OMSetRenderTargets(context, 1, &rtview, null);

            context.lpVtbl.Draw(context, 4, 0);

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
