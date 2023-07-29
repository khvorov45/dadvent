module dadvent_windows;

import dadvent;
import input;

import core.sys.windows.winbase;
import core.sys.windows.winnt;
import core.sys.windows.winuser;
import core.sys.windows.wingdi;
import core.sys.windows.windef;

pragma(lib, "User32.lib");
pragma(lib, "Gdi32.lib");

extern (Windows) int WinMain(void* instance) {
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
            hCursor: LoadCursorA(null, cast(char*)32512),
            hbrBackground: cast(HBRUSH)GetStockObject(BLACK_BRUSH),
            lpszMenuName: null,
            lpszClassName: className.ptr,
            hIconSm: null,
        };

        ATOM registerClassResult = RegisterClassExW(&windowClass);
        assert(registerClassResult);

        wchar[] windowName = cast(wchar[])"dadvent";

        hwnd = CreateWindowExW(
            WS_EX_APPWINDOW,
            className.ptr,
            windowName.ptr,
            WS_OVERLAPPEDWINDOW,
            CW_USEDEFAULT,
            CW_USEDEFAULT,
            500,
            500,
            null,
            null,
            instance,
            null,
        );
        assert(hwnd);

        ShowWindow(hwnd, SW_SHOWNORMAL);
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

        default:
            TranslateMessage(&message);
            DispatchMessageA(&message);
            break;
        }
    }

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
