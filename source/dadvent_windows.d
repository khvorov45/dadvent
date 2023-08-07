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

    enum SolutionID {
        Year2022Day1,
        Year2022Day2,
        Year2022Day3,
    }
    string[SolutionID.max + 1] SolutionIDStrings;
    static foreach (ind; SolutionID.min..SolutionID.max + 1) {SolutionIDStrings[ind] = __traits(allMembers, SolutionID)[ind];}
    struct State {
        SolutionID activeSolution = SolutionID.Year2022Day1;
    }
    State state;

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
        ushort loword(ulong l) => cast(ushort)l;
        ushort hiword(ulong l) => cast(ushort)(l >>> 16);
        short getWheelDelta(WPARAM wparam) => cast(SHORT)hiword(wparam);

        case WM_QUIT:
            break mainloop;

        case WM_MOUSEMOVE: mu_input_mousemove(muctx, loword(message.lParam), hiword(message.lParam)); break;
        case WM_LBUTTONDOWN: mu_input_mousedown(muctx, loword(message.lParam), hiword(message.lParam), MU_MOUSE_LEFT); break;
        case WM_LBUTTONUP: mu_input_mouseup(muctx, loword(message.lParam), hiword(message.lParam), MU_MOUSE_LEFT); break;
        case WM_MOUSEWHEEL: mu_input_scroll(muctx, 0, -getWheelDelta(message.wParam)); break;

        case WM_KEYDOWN: {
            switch (message.wParam) {
            case VK_UP: {
                if (state.activeSolution == SolutionID.init) {
                    state.activeSolution = SolutionID.max;
                } else {
                    state.activeSolution -= 1;
                }
            } break;
            case VK_DOWN: {
                if (state.activeSolution == SolutionID.max) {
                    state.activeSolution = SolutionID.init;
                } else {
                    state.activeSolution += 1;
                }
            } break;
            default: break;
            }
        } break;

        default:
            TranslateMessage(&message);
            DispatchMessageA(&message);
            break;
        }

        // TODO(khvorov) It takes microui 1 frame to catch up to last input.
        {
            mu_begin(muctx);
            if (mu_begin_window_ex(muctx, "", mu_rect(0, 0, d3d11Renderer.window.width, d3d11Renderer.window.height), MU_OPT_NOTITLE | MU_OPT_NOCLOSE | MU_OPT_NORESIZE)) {
                {
                    int[2] widths = [200, -1];
                    mu_layout_row(muctx, widths.length, widths.ptr, -1);
                }

                mu_begin_panel_ex(muctx, "SolutionSelector", 0);
                {
                    {
                        int[1] widths = [-1];
                        mu_layout_row(muctx, widths.length, widths.ptr, 20);
                    }

                    static foreach (ind; SolutionID.min..SolutionID.max + 1) {{
                        mu_Color[3] oldColors = muctx.style.colors[MU_COLOR_BUTTON..MU_COLOR_BUTTONFOCUS + 1];
                        if (state.activeSolution == mixin("SolutionID." ~ __traits(allMembers, SolutionID)[ind])) {
                            for (int ind = MU_COLOR_BUTTON; ind <= MU_COLOR_BUTTONFOCUS; ind++) {
                                muctx.style.colors[ind].r += 25;
                            }
                        }
                        if (mu_button_ex(muctx, __traits(allMembers, SolutionID)[ind], 0, MU_OPT_ALIGNCENTER)) {
                            state.activeSolution = mixin("SolutionID." ~ __traits(allMembers, SolutionID)[ind]);
                        }
                        muctx.style.colors[MU_COLOR_BUTTON..MU_COLOR_BUTTONFOCUS + 1] = oldColors;
                    }}
                }
                mu_end_panel(muctx);

                mu_begin_panel_ex(muctx, "Solution", 0);
                {
                    {
                        int[1] widths = [-1];
                        mu_layout_row(muctx, widths.length, widths.ptr, -1);
                    }
                    mu_text(muctx, SolutionIDStrings[state.activeSolution].ptr);
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
                Rect rect = Rect(rectcmd.rect);
                Color color = Color(rectcmd.color);
                d3d11Renderer.pushSolidRect(rect, color);
            } break;

            case MU_COMMAND_ICON: {
                mu_IconCommand* iconcmd = cast(mu_IconCommand*)cmd;
                Rect iconRect = Rect(iconcmd.rect);
                Color color = Color(iconcmd.color);

                V2 glyphRectDim = V2(d3d11Renderer.font.chWidth, d3d11Renderer.font.chHeight);
                V2 dimdiff = iconRect.dim - glyphRectDim;
                V2 alignOffset = dimdiff * 0.5;
                V2 topleftAligned = iconRect.topleft + alignOffset;

                switch (iconcmd.id) {
                case MU_ICON_CLOSE: d3d11Renderer.pushGlyph('x', topleftAligned, color); break;
                case MU_ICON_CHECK: d3d11Renderer.pushGlyph('~', topleftAligned, color); break;
                case MU_ICON_COLLAPSED: d3d11Renderer.pushGlyph('_', topleftAligned, color); break;
                case MU_ICON_EXPANDED: d3d11Renderer.pushGlyph('o', topleftAligned, color); break;
                default: assert(!"unreachable"); break;
                }
            } break;

            case MU_COMMAND_CLIP: {
                mu_ClipCommand* clipcmd = cast(mu_ClipCommand*)cmd;
                Rect rect = Rect(clipcmd.rect);
                d3d11Renderer.clipRect = rect;
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
