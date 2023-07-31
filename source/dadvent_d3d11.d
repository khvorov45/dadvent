module dadvent_d3d11;

import sysd3d11;

pragma(lib, "d3d11");
pragma(lib, "dxguid");

struct D3D11Renderer {
    ID3D11Device* device;
    ID3D11DeviceContext* context;
    IDXGISwapChain1* swapchain;

    extern (C) alias DXGIGetDebugInterfaceType = HRESULT function(IID*, void**);
    this(void* hwnd) {

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
                hWnd: cast(HWND)hwnd,
                pDesc: &desc,
                pFullscreenDesc: null,
                pRestrictToOutput: null,
                ppSwapChain: &swapchain
            );
            // dfmt on
            assert(CreateSwapChainForHwndResult == 0);

            const uint DXGI_MWA_NO_ALT_ENTER = 1 << 1;
            HRESULT MakeWindowAssociationResult =
                dxgiFactory.lpVtbl.MakeWindowAssociation(dxgiFactory, cast(HWND)hwnd, DXGI_MWA_NO_ALT_ENTER);
            assert(MakeWindowAssociationResult == 0);

            dxgiDevice.lpVtbl.Release(dxgiDevice);
            dxgiAdapter.lpVtbl.Release(dxgiAdapter);
            dxgiFactory.lpVtbl.Release(dxgiFactory);
        }
    }

    void destroy() {
        device.lpVtbl.Release(device);
        context.lpVtbl.Release(context);
        swapchain.lpVtbl.Release(swapchain);
    }
}
