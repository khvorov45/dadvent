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
    LineRange lines = LineRange(input);
    long scorePart1 = 0;
    long scorePart2 = 0;
    foreach (line; lines) {
        assert(line.length == 3);

        char c1 = line.ptr[0];
        assert(c1 == 'A' || c1 == 'B' || c1 == 'C');

        char c2 = line.ptr[2];
        assert(c2 == 'X' || c2 == 'Y' || c2 == 'Z');

        long choice1 = c1 - 'A';

        long choice2Part1 = c2 - 'X';
        long scoreOutcomePart1 = 0;
        {
            bool draw = choice1 == choice2Part1;
            bool lose1 = ((choice1 + 1) % 3) == choice2Part1;
            bool lose2 = ((choice2Part1 + 1) % 3) == choice1;
            assert(draw || lose1 || lose2);

            if (draw) {
                assert(!lose1 && !lose2);
                scoreOutcomePart1 = 3;
            } else if (lose1) {
                assert(!draw && !lose2);
                scoreOutcomePart1 = 6;
            }
        }

        long scoreOutcomePart2 = (c2 - 'X') * 3;
        long choice2Part2 = 0;
        switch (scoreOutcomePart2) {
        case 0:
            choice2Part2 = (choice1 + 2) % 3;
            break;
        case 3:
            choice2Part2 = choice1;
            break;
        case 6:
            choice2Part2 = (choice1 + 1) % 3;
            break;
        default:
            assert(false, "unreachable");
        }

        scorePart1 += scoreOutcomePart1 + choice2Part1 + 1;
        scorePart2 += scoreOutcomePart2 + choice2Part2 + 1;
    }
    writeToStdout(fmt(fmt(scorePart1), "\n"));
    writeToStdout(fmt(fmt(scorePart2), "\n"));
}

void year2022day3() {
    string input = getInput(__FUNCTION__);
}

T max(T)(T v1, T v2) => v1 > v2 ? v1 : v2;

struct Arena {
    void[] buf;
    void[] free;

    this(void[] buf_) {
        buf = buf_;
        free = buf_;
    }
}

void[] alloc(ref Arena arena, long size) {
    void[] result = arena.free[0 .. size];
    arena.free = arena.free[size .. arena.free.length];
    return result;
}

struct CircularBuffer {
    Arena arena;
    alias arena this;
}

void[] alloc(ref CircularBuffer cb, long size) {
    if (size > cb.free.length) {
        cb.free = cb.buf;
    }
    void[] result = alloc(cb.arena, size);
    return result;
}

struct Memory {
    Arena arena;
    CircularBuffer circularBuffer;
}

Memory globalMemory;

void[] alloc(long size) => alloc(globalMemory.arena, size);
void[] talloc(long size) => alloc(globalMemory.circularBuffer, size);

string tempNullTerm(string str) {
    import core.stdc.string;

    char[] buf = cast(char[]) talloc(str.length + 1);
    memcpy(buf.ptr, str.ptr, str.length);
    buf[str.length] = 0;

    string result = cast(string) buf;
    return result;
}

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

string getInput(string functionName) {
    string justName = functionName[__MODULE__.length + 1 .. functionName.length];
    string inputPath = fmt("input/", justName, ".txt");
    string content = readEntireFile(inputPath);
    return content;
}

string fmt(long number) {
    assert(number >= 0);
    long maxpow10 = 1;
    long digitCount = 1;
    while (number / maxpow10 >= 10) {
        maxpow10 *= 10;
        digitCount += 1;
    }

    char[] buf = cast(char[]) alloc(digitCount);
    long curnumber = number;
    long curDigitInd = 0;
    for (long curpow10 = maxpow10; curpow10; curpow10 /= 10) {
        long digit = curnumber / curpow10;
        assert(digit >= 0 && digit <= 9);
        curnumber -= digit * curpow10;

        char ch = cast(char)((cast(char) digit) + '0');
        buf[curDigitInd] = ch;
        curDigitInd += 1;
    }

    string result = cast(string) buf;
    return result;
}

string fmt(string[] arr...) {
    char* ptr = cast(char*) globalMemory.arena.free.ptr;
    long len = 0;
    foreach (arg; arr) {
        import core.stdc.string;

        char[] thisArg = cast(char[]) alloc(arg.length);
        memcpy(thisArg.ptr, arg.ptr, arg.length);

        len += arg.length;
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

extern (C) int main(int argc, char** argv) {
    {
        long size = 1 * 1024 * 1024 * 1024;
        void* ptr = allocvmem(size);
        globalMemory.arena = Arena(ptr[0 .. size]);
        void[] buf = alloc(globalMemory.arena.buf.length / 2);
        globalMemory.circularBuffer = CircularBuffer(Arena(buf));
    }

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

        string msg0 = tempNullTerm(msg);
        OutputDebugStringA(msg0.ptr);
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
    char* ptr = cast(char*) globalMemory.arena.free.ptr;
    long size = 0;

    string path0 = tempNullTerm(path);

    version (linux) {
        import core.sys.posix.fcntl;
        import core.sys.posix.unistd;

        int fd = open(cast(char*) path0.ptr, O_RDONLY);
        assert(fd != -1, "could not open file");
        scope (exit)
            close(fd);

        ssize_t readRes = read(fd, ptr, globalMemory.arena.free.length);
        assert(readRes != -1, "could not read file");
        size = readRes;
    }

    version (Windows) {
        import core.sys.windows.winbase;
        import core.sys.windows.winnt;

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
        assert(ReadFile(handle, ptr, cast(uint) globalMemory.arena.free.length, &bytesRead, null));
        size = bytesRead;
    }

    globalMemory.arena.free = globalMemory.arena.free[size .. globalMemory.arena.free.length];

    content = cast(string) ptr[0 .. size];
    return content;
}

void runTests() {
    {
        char[64] buf;
        Arena arena = Arena(buf);

        void[] a1 = alloc(arena, 10);
        assert(a1.ptr == buf.ptr);
        assert(a1.length == 10);
        assert(arena.buf == buf);
        assert(arena.free.ptr == arena.buf.ptr + 10);
        assert(arena.free.length == 54);

        void[] a2 = alloc(arena, 20);
        assert(a2.ptr == buf.ptr + 10);
        assert(a2.length == 20);
        assert(arena.buf == buf);
        assert(arena.free.ptr == arena.buf.ptr + 30);
        assert(arena.free.length == 34);
    }

    {
        char[64] buf;
        CircularBuffer cb = CircularBuffer(Arena(buf));
        void[] a1 = alloc(cb, 10);
        void[] a2 = alloc(cb, 64);
        assert(a1.ptr == a2.ptr);
    }

    {
        assert(parseInt("0") == 0);
        assert(parseInt("123") == 123);
    }

    {
        string testInput = "";
        LineRange range = LineRange(testInput);
        assert(range.empty);
    }

    {
        string[4] testInputs = ["1234", "1234\n", "1234\r", "1234\r\n"];
        foreach (testInput; testInputs) {
            LineRange range = LineRange(testInput);
            assert(!range.empty);
            assert(range.front == "1234");
            range.popFront();
            assert(range.empty);
        }
    }

    {
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

    {
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

    {
        string wholeString = cast(string) globalMemory.arena.free.ptr[0 .. 6];
        assert(fmt(0) == "0");
        assert(fmt(5) == "5");
        assert(fmt(1234) == "1234");
        assert(wholeString == "051234");
    }

    {
        assert(fmt("1", "22", "333") == "122333");
    }
}
