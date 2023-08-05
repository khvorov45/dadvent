module dadvent_windows;

import dadvent;
import dadvent_d3d11;
import input;
import microui;

import core.sys.windows.winbase;
import core.sys.windows.winnt;
import core.sys.windows.winuser;
import core.sys.windows.wingdi;
import core.sys.windows.windef;

pragma(lib, "User32");
pragma(lib, "Gdi32");

extern (Windows) int WinMain(HINSTANCE instance) {
    {
        long size = 1 * 1024 * 1024 * 1024;
        void* ptr = allocvmem(size);
        globalMemory.arena = Arena(ptr[0 .. size]);
        void[] buf = alloc(globalMemory.arena.buf.length / 2);
        globalMemory.circularBuffer = CircularBuffer(Arena(buf));
    }

    runTests();

    HWND hwnd;
    {
        wchar[] className = cast(wchar[])"dadventWindowClass";

        WNDCLASSEXW windowClass = {
            cbSize: WNDCLASSEXW.sizeof,
            style: 0,
            lpfnWndProc: &DefWindowProcW,
            cbClsExtra: 0,
            cbWndExtra: 0,
            hInstance: instance,
            hIcon: null,
            hCursor: LoadCursorW(null, IDC_ARROW),
            hbrBackground: cast(HBRUSH)GetStockObject(BLACK_BRUSH),
            lpszMenuName: null,
            lpszClassName: className.ptr,
            hIconSm: null,
        };

        ATOM registerClassResult = RegisterClassExW(&windowClass);
        assert(registerClassResult);

        wchar[] windowName = cast(wchar[])"dadvent";

        hwnd = CreateWindowExW(
            WS_EX_APPWINDOW | WS_EX_NOREDIRECTIONBITMAP,
            className.ptr,
            windowName.ptr,
            WS_OVERLAPPEDWINDOW,
            CW_USEDEFAULT,
            CW_USEDEFAULT,
            CW_USEDEFAULT,
            CW_USEDEFAULT,
            null,
            null,
            instance,
            null,
        );
        assert(hwnd);

        ShowWindow(hwnd, SW_SHOWNORMAL);

        // NOTE(khvorov) Fullscreen from https://devblogs.microsoft.com/oldnewthing/20100412-00/?p=14353
        {
            WINDOWPLACEMENT windowPlacement;
            BOOL GetWindowPlacementResult = GetWindowPlacement(hwnd, &windowPlacement);
            assert(GetWindowPlacementResult);

            MONITORINFO monitorInfo = {cbSize: MONITORINFO.sizeof};
            BOOL GetMonitorInfoResult = GetMonitorInfo(MonitorFromWindow(hwnd, MONITOR_DEFAULTTOPRIMARY), &monitorInfo);
            assert(GetMonitorInfoResult);

            DWORD dwStyle = GetWindowLong(hwnd, GWL_STYLE);
            assert(dwStyle & WS_OVERLAPPEDWINDOW);
            SetWindowLong(hwnd, GWL_STYLE, dwStyle & ~WS_OVERLAPPEDWINDOW);
            SetWindowPos(
                hwnd,
                HWND_TOP,
                monitorInfo.rcMonitor.left, monitorInfo.rcMonitor.top,
                monitorInfo.rcMonitor.right - monitorInfo.rcMonitor.left, monitorInfo.rcMonitor.bottom - monitorInfo.rcMonitor.top,
                SWP_NOOWNERZORDER | SWP_FRAMECHANGED
            );
        }
    }

    D3D11Renderer d3d11Renderer = D3D11Renderer(hwnd);

    mu_Context* muctx = cast(mu_Context*)alloc(mu_Context.sizeof).ptr;
    mu_init(muctx);
    {
        muctx.style.font = &d3d11Renderer.font;
        extern(C) int textWidthProc(mu_Font mufont, const char* text, int textLen) {
            Font* font = cast(Font*)mufont;
            if (textLen == -1) {
                textLen = cast(int)strlen(text);
            }
            int result = textLen * cast(int)font.chWidth;
            return result;
        }
        extern(C) int textHeightProc(mu_Font mufont) {
            Font* font = cast(Font*)mufont;
            int result = cast(int)font.chHeight;
            return result;
        }
        muctx.text_width = &textWidthProc;
        muctx.text_height = &textHeightProc;
    }

    {
        long result = year2022day1(globalInputYear2022day1);
        writeToStdout(fmt(fmt(result), "\n"));
    }

    {
        long[2] result = year2022day2(globalInputYear2022day2);
        writeToStdout(fmt(fmt(result[0]), " ", fmt(result[1]), "\n"));
    }

    {
        long[2] result = year2022day3(globalInputYear2022day3);
        writeToStdout(fmt(fmt(result[0]), " ", fmt(result[1]), "\n"));
    }

    mainloop: for (;;) {
        MSG message;
        if (GetMessageA(&message, hwnd, 0, 0) == -1) {
            break mainloop;
        }

        switch (message.message) {
        case WM_QUIT:
            break mainloop;

        // TODO(khvorov) Pass input to ui

        default:
            TranslateMessage(&message);
            DispatchMessageA(&message);
            break;
        }

        {
            mu_begin(muctx);
            if (mu_begin_window_ex(muctx, "", mu_rect(0, 0, d3d11Renderer.window.width, d3d11Renderer.window.height), MU_OPT_NOTITLE | MU_OPT_NOCLOSE | MU_OPT_NORESIZE)) {
                int[1] widths = [-1];
                mu_layout_row(muctx, widths.length, widths.ptr, -1);
                
                mu_begin_panel_ex(muctx, "Log Output", 0);
                {
                    mu_layout_row(muctx, widths.length, widths.ptr, -1);
                    mu_text(muctx, "log message");
                }
                mu_end_panel(muctx);
                
                mu_end_window(muctx);
            }
            mu_end(muctx);
        }

        for (mu_Command* cmd = null; mu_next_command(muctx, &cmd);) {
            switch (cmd.type) {
            case MU_COMMAND_TEXT: {
                mu_TextCommand* textcmd = cast(mu_TextCommand*)cmd;
                V2 topleft = V2(textcmd.pos);
                Color color = Color(textcmd.color);
                string line = cast(string)textcmd.str.ptr[0 .. strlen(textcmd.str.ptr)];
                d3d11Renderer.pushTextline(line, topleft, color);
            } break;

            case MU_COMMAND_RECT: {
                mu_RectCommand* rectcmd = cast(mu_RectCommand*)cmd;
                V2 topleft = V2(rectcmd.rect.x, rectcmd.rect.y);
                V2 dim = V2(rectcmd.rect.w, rectcmd.rect.h);
                Color color = Color(rectcmd.color);
                d3d11Renderer.pushSolidRect(topleft, dim, color);
            } break;

            case MU_COMMAND_ICON: {
                mu_IconCommand* iconcmd = cast(mu_IconCommand*)cmd;
                V2 topleft = V2(iconcmd.rect.x, iconcmd.rect.y);
                Color color = Color(iconcmd.color);
                // TODO(khvorov) Align the icon?
                switch (iconcmd.id) {
                case MU_ICON_CLOSE: d3d11Renderer.pushGlyph('x', topleft, color); break;
                case MU_ICON_CHECK: d3d11Renderer.pushGlyph('~', topleft, color); break;
                case MU_ICON_COLLAPSED: d3d11Renderer.pushGlyph('_', topleft, color); break;
                case MU_ICON_EXPANDED: d3d11Renderer.pushGlyph('o', topleft, color); break;
                default: assert(!"unreachable"); break;
                }
            } break;

            case MU_COMMAND_CLIP: {
                // TODO(khvorov) Implement
            } break;
            default: assert(!"unreachable"); break;
            }
        }

        d3d11Renderer.draw();
    }

    d3d11Renderer.destroy();
    return 0;
}

void writeToStdout(string msg) {

    DWORD written = 0;
    BOOL writeFileResult = WriteFile(cast(HANDLE)STD_OUTPUT_HANDLE, msg.ptr, cast(uint)msg.length, &written, null);
    if (writeFileResult) {
        assert(written == msg.length);
    }

    string msg0 = tempNullTerm(msg);
    OutputDebugStringA(msg0.ptr);
}

void* allocvmem(long size) {
    void* ptr = null;

    ptr = VirtualAlloc(null, size, MEM_RESERVE | MEM_COMMIT, PAGE_READWRITE);
    assert(ptr);

    return ptr;
}

string readEntireFile(string path) {
    string content = "";
    char* ptr = cast(char*)globalMemory.arena.freeptr;
    long size = 0;

    string path0 = tempNullTerm(path);

    HANDLE handle = CreateFileA(
        path0.ptr,
        GENERIC_READ,
        FILE_SHARE_DELETE | FILE_SHARE_READ | FILE_SHARE_WRITE,
        null,
        OPEN_EXISTING,
        FILE_ATTRIBUTE_NORMAL,
        null,
    );
    assert(handle != INVALID_HANDLE_VALUE);
    scope (exit)
        CloseHandle(handle);

    DWORD bytesRead = 0;
    BOOL readFileResult = ReadFile(handle, ptr, cast(uint)globalMemory.arena.freesize, &bytesRead, null);
    assert(readFileResult);
    size = bytesRead;

    globalMemory.arena.used = globalMemory.arena.used + size;

    content = cast(string)ptr[0 .. size];
    return content;
}
