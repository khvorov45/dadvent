module dadvent_d3d11;

import sysd3d11;

pragma(lib, "d3d11");

struct D3D11Renderer {
    ID3D11Device* device;
    ID3D11DeviceContext* context;
}

// TODO(khvorov) Make renderer a ref?
void initD3D11Context(D3D11Renderer* renderer, long width, long height) {

    // NOTE(khvorov) D3D11 device and context
    {
        D3D_FEATURE_LEVEL[1] levels = [D3D_FEATURE_LEVEL_11_0];

        // dfmt off
        HRESULT D3D11CreateDeviceResult = D3D11CreateDevice(
            pAdapter: null,
            DriverType: D3D_DRIVER_TYPE_HARDWARE,
            Software: null,
            Flags: D3D11_CREATE_DEVICE_DEBUG, // TODO(khvorov) Debug guard
            pFeatureLevels: levels.ptr,
            FeatureLevels: levels.length,
            SDKVersion: 7,
            ppDevice: &renderer.device,
            pFeatureLevel: null,
            ppImmediateContext: &renderer.context,
        );
        // dfmt on

        assert(D3D11CreateDeviceResult == 0);
    }

    IDXGIDevice* dxgiDevice;

    IDXGIAdapter* dxgiAdapter;

    IDXGIFactory2* dxgiFactory;

    DXGI_SWAP_CHAIN_DESC1 desc = {
        Width: cast(uint)width,
        Height: cast(uint)height,
        Format: DXGI_FORMAT_R8G8B8A8_UNORM,
        SampleDesc: {Count: 1},
        BufferUsage: DXGI_USAGE_RENDER_TARGET_OUTPUT,
        BufferCount: 2,
        Scaling: DXGI_SCALING_NONE,
        SwapEffect: DXGI_SWAP_EFFECT_FLIP_DISCARD,
    };

    // HRESULT CreateSwapChainForHwndResult = CreateSwapChainForHwnd(
    //     pDevice: 0,
    //     hWnd: 0,
    //     pDesc: 0,
    //     pFullscreenDesc: 0,
    //     pRestrictToOutput: 0,
    //     ppSwapChain: 0
    // );
}
