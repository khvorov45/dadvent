module dadvent;

import core.stdc.string : memcpy, memset;

import microui;

struct Year2022Day1 {
    int* calories;
    int* itemCounts;
    int* sums;
    int elfCount;
    int[3] maxSums;
    int top3sum;

    this(string input, ref Arena arena, ref Arena scratch) {
        TempMemory _TEMP_ = TempMemory(scratch);

        LineRange lines = LineRange(input);
        int thisSum = 0;
        int thisItemCount = 0;

        DynArr!int caloriesScratch = DynArr!int(scratch, scratch.buf.length / 3);
        DynArr!int itemCountsScratch = DynArr!int(scratch, scratch.buf.length / 3);
        DynArr!int sumsScratch = DynArr!int(scratch, scratch.freesize);
        for (;;) {
            string thisLine = lines.line;
            if (thisLine.length > 0) {
                long number = parseInt(thisLine);
                caloriesScratch.push(cast(int)number);
                thisSum += number;
                thisItemCount += 1;
            }
            lines.popFront();

            if (thisLine.length == 0 || lines.empty) {
                sumsScratch.push(thisSum);
                itemCountsScratch.push(thisItemCount);
                if (thisSum > maxSums[0]) {
                    maxSums[2] = maxSums[1];
                    maxSums[1] = maxSums[0];
                    maxSums[0] = thisSum;
                } else if (thisSum > maxSums[1]) {
                    maxSums[2] = maxSums[1];
                    maxSums[1] = thisSum;
                } else if (thisSum > maxSums[2]) {
                    maxSums[2] = thisSum;
                }
                thisSum = 0;
                thisItemCount = 0;
                if (lines.empty) {
                    break;
                }
            }
        }

        int[] caloriesSlice = caloriesScratch.copy(arena);
        int[] itemCountsSlice = itemCountsScratch.copy(arena);
        int[] sumsSlice = sumsScratch.copy(arena);
        assert(itemCountsSlice.length == sumsSlice.length);

        calories = caloriesSlice.ptr;
        itemCounts = itemCountsSlice.ptr;
        sums = sumsSlice.ptr;
        elfCount = cast(int)sumsSlice.length;
        top3sum = maxSums[0] + maxSums[1] + maxSums[2];
    }
}

struct Year2022Day2 {
    long[2] result;

    this(string input, ref Arena arena, ref Arena scratch) {
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

        result = [scorePart1, scorePart2];
    }
}

struct Year2022Day3 {
    long[2] result;

    this(string input, ref Arena arena, ref Arena scratch) {
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
                    long priority = ch >= 'a' ? ch - 'a' + 1 : ch - 'A' + 27;
                    return priority;
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

        result = [sharedItemsPrioritySum, badgePrioritySum];
    }
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

    long tempCount_;
    @property tempCount() => tempCount_;
    @property void tempCount(long newTempCount) {
        assert(newTempCount >= 0);
        tempCount_ = newTempCount;
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

        T[] result = arrcast!T(voidbuf);
        return result;
    }
}

struct TempMemory {
    long usedAtBegin;
    long tempCountAtBegin;
    Arena* arena;

    this(ref Arena arena_) {
        arena = &arena_;
        usedAtBegin = arena.used;
        tempCountAtBegin = arena.tempCount;
        arena.tempCount = arena.tempCount + 1;
    }

    ~this() {
        assert(arena.used_ >= usedAtBegin);
        assert(arena.tempCount == tempCountAtBegin + 1);
        arena.used = usedAtBegin;
        arena.tempCount = arena.tempCount - 1;
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

struct DynArr(T) {
    T[] buf;
    long len;

    this(ref Arena arena, long bytes) {
        buf = arena.alloc!(T)(bytes);
        len = 0;
    }

    void push(T val) {
        buf[len] = val;
        len += 1;
    }

    T[] copy(ref Arena arena) {
        long bytes = len * T.sizeof;
        T[] result = arena.alloc!T(bytes, T.alignof);
        memcpy(result.ptr, buf.ptr, bytes);
        return result;
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

import std.SumType;
alias Solution = SumType!(Year2022Day1, Year2022Day2, Year2022Day3);

struct State {
    Solution[Solution.Types.length] solutions;
    int activeSolution;

    this(ref Arena arena, ref Arena scratch) {
        {
            import input;
            static foreach (typeIndex, type; Solution.Types) {{
                const string typeName = Solution.Types[typeIndex].stringof;
                mixin(typeName, " thisSolution = ", typeName, "(globalInput", typeName,  ", arena, scratch);");
                static if (typeName == "Year2022Day1") {
                    assert(thisSolution.maxSums[0] == 68802);
                    assert(thisSolution.top3sum == 205370);
                }
                mixin("solutions[", typeIndex, "] = thisSolution;");
            }}
        }
    }

    void draw(mu_Context* muctx, int windowWidth, int windowHeight, int fontHeight, ref Arena scratch) {
        TempMemory _TEMP_ = TempMemory(scratch);

        void layout_row(int count)(int[count] widths, int height) {
            mu_layout_row(muctx, cast(int)widths.length, widths.ptr, height);
        }

        int scale(int val, int ogMin, int ogMax, int newMin, int newMax) {
            int ogRange = ogMax - ogMin;
            float val01 = cast(float)(val - ogMin) / cast(float)ogRange;
            int newRange = newMax - newMin;
            float newvalFloat = val01 * cast(float)newRange + cast(float)newMin;
            int newvalInt = cast(int)newvalFloat;
            return newvalInt;
        }

        mu_begin(muctx);
        if (mu_begin_window_ex(muctx, "", mu_rect(0, 0, windowWidth, windowHeight), MU_OPT_NOTITLE | MU_OPT_NOCLOSE | MU_OPT_NORESIZE)) {
            layout_row([200, -1], -1);

            mu_begin_panel_ex(muctx, "SolutionSelector", 0);
            {
                layout_row([-1], 20);

                static foreach (typeIndex, type; Solution.Types) {{
                    mu_Color[3] oldColors = muctx.style.colors[MU_COLOR_BUTTON..MU_COLOR_BUTTONFOCUS + 1];
                    if (activeSolution == typeIndex) {
                        for (int ind = MU_COLOR_BUTTON; ind <= MU_COLOR_BUTTONFOCUS; ind++) {
                            muctx.style.colors[ind].r += 25;
                        }
                    }
                    if (mu_button_ex(muctx, Solution.Types[typeIndex].stringof, 0, MU_OPT_ALIGNCENTER)) {
                        activeSolution = typeIndex;
                    }
                    muctx.style.colors[MU_COLOR_BUTTON..MU_COLOR_BUTTONFOCUS + 1] = oldColors;
                }}
            }
            mu_end_panel(muctx);

            mu_begin_panel_ex(muctx, "Solution", 0);
            // TODO(khvorov) Fill
            solutions[activeSolution].match!(
                (ref Year2022Day1 sol) {
                    layout_row([-1], cast(int)fontHeight * 2);
                    mu_begin_panel_ex(muctx, "SolutionResultString", MU_OPT_NOFRAME);
                    {
                        layout_row([-1], cast(int)fontHeight);
                        string resultStr = StringBuilder(scratch).fmt("Part 1: ").fmt(sol.maxSums[0]).fmt(" Part 2: ").fmt(sol.top3sum).endNull();
                        mu_text(muctx, resultStr.ptr);
                    }
                    mu_end_panel(muctx);

                    layout_row([100, -1], -1);
                    mu_begin_panel_ex(muctx, "HistogramScale", MU_OPT_NOFRAME);
                    layout_row([-1], -1);
                    mu_Rect scaleBounds = mu_layout_next(muctx);
                    mu_end_panel(muctx);

                    {
                        mu_Color histColor = mu_color(100, 100, 100, 255);
                        mu_Color gridColor = mu_color(25, 25, 25, 255);
                        mu_Color axisColor = mu_color(25, 25, 25, 255);

                        mu_begin_panel_ex(muctx, "HistogramRects", MU_OPT_NOFRAME);
                        int rectWidth = 10;
                        int rectPad = 5;
                        int totalWidth = rectWidth * sol.elfCount + rectPad * (sol.elfCount - 1);
                        layout_row([totalWidth], -1);
                        const mu_Rect rectBounds = mu_layout_next(muctx);
                        scaleBounds.h = rectBounds.h;
                        int scaleToPx(int val) => scale(val, 0, sol.maxSums[0], rectBounds.y + rectBounds.h, rectBounds.y);

                        mu_Rect scaleAndRectsBounds = mu_Rect(scaleBounds.x, scaleBounds.y, rectBounds.x + rectBounds.w - scaleBounds.x, scaleBounds.h);
                        mu_Rect rectClipRect = mu_get_clip_rect(muctx);
                        mu_pop_clip_rect(muctx);
                        mu_push_clip_rect(muctx, scaleAndRectsBounds);
                        {
                            mu_Rect vlineRect = scaleBounds;
                            vlineRect.w = 2;
                            vlineRect.x += scaleBounds.w - vlineRect.w;
                            mu_draw_rect(muctx, vlineRect, axisColor);
                            for (int tickValue = 0; tickValue < 100000; tickValue += 10000) {
                                int tickPx = scaleToPx(tickValue);
                                mu_Rect tickRect = vlineRect;
                                tickRect.x -= 5;
                                tickRect.h = 2;
                                tickRect.w = rectBounds.w;
                                tickRect.y = tickPx;
                                mu_draw_rect(muctx, tickRect, gridColor);
                            }
                        }
                        mu_pop_clip_rect(muctx);
                        mu_push_clip_rect(muctx, rectClipRect);

                        mu_Rect histRect = mu_rect(rectBounds.x, rectBounds.y, 10, 0);
                        foreach (sum; sol.sums[0..sol.elfCount]) {
                            histRect.y = scaleToPx(sum);
                            histRect.h = (rectBounds.y + rectBounds.h) - histRect.y;
                            mu_draw_rect(muctx, histRect, histColor);
                            histRect.x += histRect.w + 5;
                        }
                        mu_end_panel(muctx);
                    }
                },

                (ref Year2022Day2 sol) {},
                (ref Year2022Day3 sol) {}
            );
            mu_end_panel(muctx);

            mu_end_window(muctx);
        }
        mu_end(muctx);
    }
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

    {
        char[1024] buf1;
        char[1024] buf2;
        Arena arena = Arena(buf1);
        Arena scratch = Arena(buf2);
        string[2] testInput = [
"1000
2000
3000

4000

5000
6000

7000
8000
9000

10000",

"24000
10000
11000"
        ];

        int[testInput.length] topMaxSum = [24000, 45000];
        int[testInput.length] top3sum = [45000, 45000];
        int[testInput.length] elvesCount = [5, 1];
        foreach(inputIndex, input; testInput) {
            arena.used = 0;
            scratch.used = 0;
            Year2022Day1 result = Year2022Day1(input, arena, scratch);
            assert(result.maxSums[0] == topMaxSum[inputIndex]);
            assert(result.top3sum == top3sum[inputIndex]);
            assert(result.elfCount == elvesCount[inputIndex]);
        }
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
