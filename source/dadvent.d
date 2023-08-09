module dadvent;

struct Year2022Day1Result {
    int* calories;
    int* itemCounts;
    int* sums;
    int elfCount;
    int maxSum;
}

long year2022day1(string input, ref Arena arena, ref Arena scratch) {
    LineRange lines = LineRange(input);
    int thisSum = 0;
    int maxSum = 0;

    // TODO(khvorov) Fill the arrays with appropriate data and copy the results to the arena.
    // These arrays should probably be "dynamic" as we need to keep track of how many elements we filled
    int[] caloriesScratch = scratch.alloc!(int)(scratch.buf.length / 3);
    int[] itemCountsScratch = scratch.alloc!(int)(scratch.buf.length / 3);
    int[] sumsScratch = scratch.alloc!(int)(scratch.freesize);
    foreach (line; lines) {
        if (line.length > 0) {
            long number = parseInt(line);
            thisSum += number;
        } else {
            maxSum = max(maxSum, thisSum);
            thisSum = 0;
        }
    }
    return maxSum;
}

long[2] year2022day2(string input) {
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

    long[2] result = [scorePart1, scorePart2];
    return result;
}

long[2] year2022day3(string input) {
    LineRange lines = LineRange(input);

    const long maxPriority = 52;
    bool[maxPriority + 1][3] groupLinePriorities;
    long curGroupLineIndex = 0;

    long sharedItemsPrioritySum = 0;
    long badgePrioritySum = 0;
    foreach (line; lines) {
        assert(line.length % 2 == 0);
        long perCompartment = line.length / 2;
        string comp1 = line[0 .. perCompartment];
        string comp2 = line[perCompartment .. line.length];

        bool[maxPriority + 1] comp1Priorities;
        bool[maxPriority + 1] comp2Priorities;
        for (long ind = 0; ind < perCompartment; ind++) {
            char comp1Item = comp1[ind];
            char comp2Item = comp2[ind];

            long getpriority(char ch) {
                assert((ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z'));
                long result = ch >= 'a' ? ch - 'a' + 1 : ch - 'A' + 27;
                return result;
            }

            long comp1ItemPriority = getpriority(comp1Item);
            long comp2ItemPriority = getpriority(comp2Item);

            comp1Priorities[comp1ItemPriority] = true;
            comp2Priorities[comp2ItemPriority] = true;

            groupLinePriorities[curGroupLineIndex][comp1ItemPriority] = true;
            groupLinePriorities[curGroupLineIndex][comp2ItemPriority] = true;
        }

        bool foundShared = false;
        for (long priority = 1; priority <= maxPriority; priority++) {
            bool incomp1 = comp1Priorities[priority];
            bool incomp2 = comp2Priorities[priority];
            if (incomp1 && incomp2) {
                assert(!foundShared);
                foundShared = true;
                sharedItemsPrioritySum += priority;
            }
        }
        assert(foundShared);

        if (curGroupLineIndex == 2) {
            import core.stdc.string : memset;

            bool foundBadge = false;
            for (long priority = 1; priority <= maxPriority; priority++) {
                bool g0 = groupLinePriorities[0][priority];
                bool g1 = groupLinePriorities[1][priority];
                bool g2 = groupLinePriorities[2][priority];
                if (g0 && g1 && g2) {
                    assert(!foundBadge);
                    foundBadge = true;
                    badgePrioritySum += priority;
                }
            }
            assert(foundBadge);

            curGroupLineIndex = 0;
            for (long i = 0; i < groupLinePriorities.length; i++) {
                bool[] arr = groupLinePriorities[i];
                memset(arr.ptr, 0, arr.length * arr[0].sizeof);
            }
        } else {
            curGroupLineIndex += 1;
        }
    }

    long[2] result = [sharedItemsPrioritySum, badgePrioritySum];
    return result;
}

T max(T)(T v1, T v2) => v1 > v2 ? v1 : v2;
T min(T)(T v1, T v2) => v1 < v2 ? v1 : v2;
bool isPowerOf2(long val) => val > 0 && ((val & (val - 1)) == 0);

long getAlignOffset(ulong ptr, long alignment) {
    assert(isPowerOf2(alignment));
    ulong mask = alignment - 1;
    ulong ptrMasked = ptr & mask;
    ulong offset = 0;
    if (ptrMasked) {
        offset = alignment - ptrMasked;
    }
    return offset;
}

long getAlignOffset(void* ptr, long alignment) {
    long result = getAlignOffset(cast(ulong)ptr, alignment);
    return result;
}

struct Arena {
    void[] buf;

    long used_;
    @property used() => used_;
    @property void used(long newUsed) {
        assert(newUsed >= 0);
        assert(newUsed <= buf.length);
        used_ = newUsed;
    }

    void* freeptr() => buf.ptr + used;
    long freesize() => buf.length - used;

    void alignto(long alignment) {
        long offset = getAlignOffset(freeptr, alignment);
        used = used + offset;
    }

    void[] alloc(long size, long alignment = 1) {
        assert(size >= 0);
        alignto(alignment);
        long newUsed = used + size;
        void[] result = buf[used .. newUsed];
        used = newUsed;
        return result;
    }

    T[] alloc(T)(long size, long alignment = T.alignof) {
        assert(isPowerOf2(alignment));
        long wholeSize = size & (~(alignment - 1));
        void[] voidbuf = alloc(wholeSize, alignment);

        // NOTE(khvorov) D compiler is bad and does not insert whatever internal function it needs into the executable to make this work automatically
        // So I have to implement the cast manually
        To[] arrcast(To, From)(From[] v1) {
            ulong length = v1.length * From.sizeof / To.sizeof;
            To[] result = (cast(To*)v1.ptr)[0..length];
            return result;
        }

        T[] result = arrcast!(T)(voidbuf);
        return result;
    }
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

struct StringBuilder {
    Arena arena;
    char* ptr;

    this(Arena arena_) {
        arena = arena_;
        ptr = cast(char*)arena.freeptr;
    }

    ref StringBuilder fmt(long number) {
        assert(number >= 0);
        long maxpow10 = 1;
        long digitCount = 1;
        while (number / maxpow10 >= 10) {
            maxpow10 *= 10;
            digitCount += 1;
        }

        char[] buf = cast(char[])arena.alloc(digitCount);
        long curnumber = number;
        long curDigitInd = 0;
        for (long curpow10 = maxpow10; curpow10; curpow10 /= 10) {
            long digit = curnumber / curpow10;
            assert(digit >= 0 && digit <= 9);
            curnumber -= digit * curpow10;

            char ch = cast(char)((cast(char)digit) + '0');
            buf[curDigitInd] = ch;
            curDigitInd += 1;
        }

        return this;
    }

    ref StringBuilder fmt(long[] arr) {
        foreach(ind, val; arr) {fmt(val); if (ind < arr.length - 1) fmt(" ");}
        return this;
    }

    ref StringBuilder fmt(string[] arr...) {
        foreach (arg; arr) {
            import core.stdc.string;
            char[] thisArg = cast(char[])arena.alloc(arg.length);
            memcpy(thisArg.ptr, arg.ptr, arg.length);
        }
        return this;
    }

    string end() {
        long len = cast(char*)arena.freeptr - ptr;
        string result = cast(string)ptr[0..len];
        return result;
    }

    string endNull() {
        char* endptr = cast(char*)arena.alloc(1);
        endptr[0] = '\0';
        long len = endptr - ptr;
        string result = cast(string)ptr[0..len];
        return result;
    }
}

bool strstarts(string str, string prefix) {
    if (str.length < prefix.length) {
        return false;
    }
    string strshorter = str[0 .. prefix.length];
    bool result = strshorter == prefix;
    return result;
}

void runTests() {
    {
        assert(isPowerOf2(1));
        assert(isPowerOf2(2));
        assert(isPowerOf2(4));
        assert(isPowerOf2(1024));

        assert(!isPowerOf2(3));
        assert(!isPowerOf2(31));
        assert(!isPowerOf2(21336));
    }

    {
        assert(getAlignOffset(7, 1) == 0);
        assert(getAlignOffset(16, 1) == 0);
        assert(getAlignOffset(23, 1) == 0);
        assert(getAlignOffset(1235, 1) == 0);

        assert(getAlignOffset(11, 2) == 1);
        assert(getAlignOffset(12, 2) == 0);
        assert(getAlignOffset(13, 2) == 1);

        assert(getAlignOffset(15, 8) == 1);
    }

    {
        char[64] buf;
        Arena arena = Arena(buf);
        void[] a1 = arena.alloc(10);
        assert(a1.ptr == buf.ptr);
        assert(a1.length == 10);
        assert(arena.buf == buf);
        assert(arena.freeptr == arena.buf.ptr + 10);
        assert(arena.freesize == 54);

        void[] a2 = arena.alloc(20);
        assert(a2.ptr == buf.ptr + 10);
        assert(a2.length == 20);
        assert(arena.buf == buf);
        assert(arena.freeptr == arena.buf.ptr + 30);
        assert(arena.freesize == 34);

        arena.used_ = 0;
        void[] _ = arena.alloc(1);
        assert(getAlignOffset(arena.freeptr, 4) > 0);
        void[] a3 = arena.alloc(10, 4);
        assert(getAlignOffset(a3.ptr, 4) == 0);
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
        char[64] buf;
        Arena arena = Arena(buf);
        assert(StringBuilder(arena).fmt(0).fmt(5).fmt(1234).end() == "051234");
        arena.used = 0;
        assert(StringBuilder(arena).fmt(123).end() == "123");
        assert(buf[3] == '2');
        arena.used = 0;
        assert(StringBuilder(arena).fmt(123).endNull() == "123");
        assert(buf[3] == '\0');
    }

    {
        char[64] buf;
        Arena arena = Arena(buf);
        long[3] arr = [0L, 1L, 2L];
        assert(StringBuilder(arena).fmt(arr).end() == "0 1 2");
    }

    {
        char[64] buf;
        Arena arena = Arena(buf);
        assert(StringBuilder(arena).fmt("1", "22", "333").end() == "122333");
    }
}

// NOTE(khvorov) The below is from the D runtime.
// Runtime should be disabled with -betterC
// but the call to this function is generated anyway which results in a link error.

extern (C) void[]* _memset128ii(void[]* p, void[] value, size_t count) {
    void[]* pstart = p;
    void[]* ptop;

    for (ptop = &p[count]; p < ptop; p++)
        *p = value;
    return pstart;
}

extern (C) float* _memsetFloat(float* p, float value, size_t count) {
    float* pstart = p;
    float* ptop;

    for (ptop = &p[count]; p < ptop; p++)
        *p = value;
    return pstart;
}
