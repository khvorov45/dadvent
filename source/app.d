void year2022day1() {
    string input = getInput(__FUNCTION__);
    LineRange lines = LineRange(input);
    long thisSum = 0;
    long maxSum = 0;
    foreach (line; lines) {
        if (line.length > 0) {
            long number = parseInt(line);
            thisSum += number;
        } else {
            maxSum = max(maxSum, thisSum);
            thisSum = 0;
        }
    }
    writeToStdout(fmt(fmt(maxSum), "\n"));
}

void year2022day2() {
    string input = getInput(__FUNCTION__);
}

void year2022day3() {
    string input = getInput(__FUNCTION__);
}

T max(T)(T v1, T v2) => v1 > v2 ? v1 : v2;

struct Arena {
    void* base;
    long size;
    long used;
    void* freeptr() => base + used;
    long freesize() => size - used;
    void changeUsed(long by) => used += by, assert(used <= size), assert(used >= 0);
}

Arena globalArena_;
Arena* globalArena;

long parseInt(string str) {
    long result = 0;
    long curpow10 = 1;
    foreach_reverse (ch; str) {
        assert(ch <= '9' && ch >= '0');
        long digit = ch - '0';
        long coef = digit * curpow10;
        result += coef;
        curpow10 *= 10;
    }
    return result;
}

unittest {
    assert(parseInt("0") == 0);
    assert(parseInt("123") == 123);
}

struct LineRange {
    string input;
    string line;
    long lineEndLen;
    long offset() => line.ptr - input.ptr;
    bool empty() => offset == input.length;
    string front() => line;

    void popFront() {
        string unprocessed = input[offset + line.length + lineEndLen .. input.length];
        long size = 0;
        bool lineEndDetected = false;
        foreach (ind, ch; unprocessed) {
            if (ch == '\n' || ch == '\r') {
                lineEndDetected = true;
                break;
            }
            size += 1;
        }
        line = unprocessed[0 .. size];
        lineEndLen = lineEndDetected;
        if (unprocessed.length > size + 1 && unprocessed[size] == '\r' && unprocessed[size + 1] == '\n') {
            lineEndLen = 2;
        }
    }

    this(string input_) {
        input = input_;
        line = input[0 .. 0];
        popFront();
    }
}

unittest {
    string testInput = "";
    LineRange range = LineRange(testInput);
    assert(range.empty);
}

unittest {
    string[4] testInputs = ["1234", "1234\n", "1234\r", "1234\r\n"];
    foreach (testInput; testInputs) {
        LineRange range = LineRange(testInput);
        assert(!range.empty);
        assert(range.front == "1234");
        range.popFront();
        assert(range.empty);
    }
}

unittest {
    string[3] testInputs = ["1234\n543", "1234\r543", "1234\r\n543"];
    foreach (testInput; testInputs) {
        LineRange range = LineRange(testInput);
        assert(!range.empty);
        assert(range.front == "1234");
        range.popFront();
        assert(!range.empty);
        assert(range.front == "543");
        range.popFront();
        assert(range.empty);
    }
}

unittest {
    string[1] testInputs = ["1234\n\n"];
    foreach (testInput; testInputs) {
        LineRange range = LineRange(testInput);
        assert(!range.empty);
        assert(range.front == "1234");
        range.popFront();
        assert(!range.empty);
        assert(range.front == "");
        range.popFront();
        assert(range.empty);
    }
}

string getInput(string functionName) {
    string justName = functionName[__MODULE__.length + 1 .. functionName.length];
    string inputPath = fmt("input/", justName, ".txt");
    string content = readEntireFile(inputPath);
    return content;
}

string fmt(long number) {
    assert(number >= 0);
    long maxpow10 = 1;
    while (number / maxpow10 >= 10) {
        maxpow10 *= 10;
    }

    char* ptr = cast(char*) globalArena.freeptr;
    long len = 0;
    long curnumber = number;
    for (long curpow10 = maxpow10; curpow10; curpow10 /= 10) {
        long digit = curnumber / curpow10;
        assert(digit >= 0 && digit <= 9);
        curnumber -= digit * curpow10;

        char ch = cast(char)((cast(char) digit) + '0');
        ptr[len] = ch;
        len += 1;
    }

    string result = cast(string) ptr[0 .. len];
    return result;
}

unittest {
    assert(fmt(0) == "0");
    assert(fmt(5) == "5");
    assert(fmt(1234) == "1234");
}

string fmt(string[] arr...) {
    char* ptr = cast(char*) globalArena.freeptr;
    long len = 0;
    foreach (arg; arr) {
        import core.stdc.string;

        assert(arg.length <= globalArena.freesize);
        memcpy(globalArena.freeptr, arg.ptr, arg.length);

        len += arg.length;
        globalArena.used += arg.length;
    }
    string result = cast(string) ptr[0 .. len];
    return result;
}

bool strstarts(string str, string prefix) {
    if (str.length < prefix.length) {
        return false;
    }
    string strshorter = str[0 .. prefix.length];
    bool result = strshorter == prefix;
    return result;
}

bool callFunctionByName(string name) {
    bool foundMatch = false;
    static foreach (member; __traits(allMembers, mixin(__MODULE__))) {
        static if (__traits(isStaticFunction, mixin(member))) {
            static if (strstarts(member.stringof, "\"year")) {
                mixin(
                    "if (name == ", member.stringof, ") 
                    { writeToStdout(\"exec ", member, "\n\"); ", member, "(); foundMatch = true; }"
                );
            }
        }
    }
    return foundMatch;
}

void runTests() {
    static foreach (test; __traits(getUnitTests, __traits(parent, main))) {
        test();
    }
}

extern (C) int main(int argc, char** argv) {
    globalArena = &globalArena_;
    globalArena.size = 1 * 1024 * 1024 * 1024;
    globalArena.base = allocvmem(globalArena.size);

    runTests();

    if (argc <= 1) {
        writeToStdout("provide function names to run (like year2022day1)\n");
        return 0;
    }

    foreach (carg; argv[1 .. argc]) {
        import core.stdc.string;

        string arg = cast(string) carg[0 .. strlen(carg)];
        if (!callFunctionByName(arg)) {
            writeToStdout(fmt("function ", arg, " not found\n"));
        }
    }

    return 0;
}

void writeToStdout(string msg) {
    version (linux) {
        import core.sys.posix.unistd;

        write(STDOUT_FILENO, msg.ptr, msg.length);
    }

    version (Windows) {
        import core.sys.windows.winbase;
        import core.sys.windows.windef;

        DWORD written = 0;
        assert(WriteFile(cast(HANDLE) STD_OUTPUT_HANDLE, msg.ptr, cast(uint) msg.length, &written, null));
        assert(written == msg.length);
    }
}

void* allocvmem(long size) {
    void* ptr = null;

    version (linux) {
        import core.sys.posix.sys.mman;

        ptr = mmap(null, size, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANON, 0, 0);
        assert(ptr != MAP_FAILED);
    }

    version (Windows) {
        import core.sys.windows.winbase;
        import core.sys.windows.winnt;

        ptr = VirtualAlloc(null, size, MEM_RESERVE | MEM_COMMIT, PAGE_READWRITE);
        assert(ptr);
    }

    return ptr;
}

string readEntireFile(string path) {
    string content = "";
    char* ptr = cast(char*) globalArena.freeptr;
    long size = 0;

    version (linux) {
        import core.sys.posix.fcntl;
        import core.sys.posix.unistd;

        int fd = open(cast(char*) path.ptr, O_RDONLY);
        assert(fd != -1, "could not open file");
        scope (exit)
            close(fd);

        ssize_t readRes = read(fd, ptr, globalArena.freesize);
        assert(readRes != -1, "could not read file");

        globalArena.changeUsed(readRes);
        size = readRes;
    }

    version (Windows) {
        import core.sys.windows.winbase;
        import core.sys.windows.winnt;

        HANDLE handle = CreateFileA(
            path.ptr,
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
        assert(ReadFile(handle, ptr, cast(uint) globalArena.freesize, &bytesRead, null));
        size = bytesRead;
    }

    content = cast(string) ptr[0 .. size];
    return content;
}
