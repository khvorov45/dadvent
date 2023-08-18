module dadvent;

import core.stdc.string : memcpy, memset;

import microui;

struct Year2022Day1 {
    int[] caloriesStorage;
    struct Elf {
        int[] calories;
        int sum;

        int opCmp(Elf rhs) const => rhs.sum - sum;
    }
    Elf[] elves;
    int top3sum;

    this(string input, ref Arena arena, ref Arena scratch) {
        TempMemory _TEMP_ = TempMemory(scratch);

        LineRange lines = LineRange(input);
        int thisSum = 0;
        int itemIndexStart = 0;
        int curItemIndex = 0;

        DynArr!int caloriesStorageDyn = DynArr!int(arena);
        DynArr!Elf elvesScratch = DynArr!Elf(scratch, scratch.freesize);
        for (;;) {
            string thisLine = lines.line;
            if (thisLine.length > 0) {
                long number = parseInt(thisLine);
                caloriesStorageDyn.push(cast(int)number);
                thisSum += number;
                curItemIndex += 1;
            }
            lines.popFront();

            if (thisLine.length == 0 || lines.empty) {
                Elf elf = {caloriesStorageDyn.buf[itemIndexStart..curItemIndex], thisSum};
                elvesScratch.push(elf);
                thisSum = 0;
                itemIndexStart = curItemIndex;
                if (lines.empty) {
                    break;
                }
            }
        }

        caloriesStorage = caloriesStorageDyn.toSlice();
        elves = elvesScratch.copy(arena);

        import std.algorithm.sorting;
        elves.sort();
        foreach(elf; elves) {
            elf.calories.sort!("a > b");
        }

        top3sum = elves[0].sum + elves[1].sum + elves[2].sum;
    }
}

struct Year2022Day2 {
    enum Outcome {
        Loss,
        Draw,
        Win,
    }
    struct Round {
        int score;
        Outcome outcome;
    }
    Round[] roundsPart1;
    Round[] roundsPart2;
    int scorePart1;
    int scorePart2;

    this(string input, ref Arena arena, ref Arena scratch) {
        TempMemory _TEMP_ = TempMemory(scratch);

        DynArr!Round roundsPart1Storage = DynArr!Round(arena);
        DynArr!Round roundsPart2Storage = DynArr!Round(scratch, scratch.freesize);

        LineRange lines = LineRange(input);
        foreach (line; lines) {
            assert(line.length == 3);

            char c1 = line.ptr[0];
            assert(c1 == 'A' || c1 == 'B' || c1 == 'C');

            char c2 = line.ptr[2];
            assert(c2 == 'X' || c2 == 'Y' || c2 == 'Z');

            int choice1 = c1 - 'A';

            int choice2Part1 = c2 - 'X';
            Outcome outcomePart1 = Outcome.Loss;
            {
                bool draw = choice1 == choice2Part1;
                bool lose1 = ((choice1 + 1) % 3) == choice2Part1;
                bool lose2 = ((choice2Part1 + 1) % 3) == choice1;
                assert(draw || lose1 || lose2);

                if (draw) {
                    assert(!lose1 && !lose2);
                    outcomePart1 = Outcome.Draw;
                } else if (lose1) {
                    assert(!draw && !lose2);
                    outcomePart1 = Outcome.Win;
                }
            }
            int scoreOutcomePart1 = outcomePart1 * 3;

            Outcome outcomePart2 = cast(Outcome)(c2 - 'X');
            int scoreOutcomePart2 = outcomePart2 * 3;
            int choice2Part2 = 0;
            switch (scoreOutcomePart2) {
            case 0: choice2Part2 = (choice1 + 2) % 3; break;
            case 3: choice2Part2 = choice1; break;
            case 6: choice2Part2 = (choice1 + 1) % 3; break;
            default: assert(false, "unreachable");
            }

            int scoreRoundPart1 = scoreOutcomePart1 + choice2Part1 + 1;
            int scoreRoundPart2 = scoreOutcomePart2 + choice2Part2 + 1;
            scorePart1 += scoreRoundPart1;
            scorePart2 += scoreRoundPart2;

            Round roundPart1 = {scoreRoundPart1, outcomePart1};
            roundsPart1Storage.push(roundPart1);

            Round roundPart2 = {scoreRoundPart2, outcomePart2};
            roundsPart2Storage.push(roundPart2);
        }

        roundsPart1 = roundsPart1Storage.toSlice();
        roundsPart2 = roundsPart2Storage.copy(arena);
    }
}

struct Year2022Day3 {
    struct Backpack {
        string comp1;
        string comp2;
        char common;
    }
    Backpack[] backpacks;
    char[] badges;
    int sharedItemsPrioritySum;
    int badgePrioritySum;

    this(string input, ref Arena arena, ref Arena scratch) {
        TempMemory _TEMP_ = TempMemory(scratch);

        LineRange lines = LineRange(input);

        const int maxPriority = 52;
        bool[maxPriority + 1][3] groupLinePriorities;
        int curGroupLineIndex = 0;

        DynArr!Backpack backpackStorage = DynArr!Backpack(arena);
        DynArr!char badgeStorage = DynArr!char(scratch);

        foreach (line; lines) {
            assert(line.length % 2 == 0);
            int perCompartment = cast(int)line.length / 2;
            string comp1 = line[0 .. perCompartment];
            string comp2 = line[perCompartment .. line.length];

            bool[maxPriority + 1] comp1Priorities;
            bool[maxPriority + 1] comp2Priorities;
            for (int ind = 0; ind < perCompartment; ind++) {
                char comp1Item = comp1[ind];
                char comp2Item = comp2[ind];

                int getpriority(char ch) {
                    assert((ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z'));
                    int priority = ch >= 'a' ? ch - 'a' + 1 : ch - 'A' + 27;
                    return priority;
                }

                int comp1ItemPriority = getpriority(comp1Item);
                int comp2ItemPriority = getpriority(comp2Item);

                comp1Priorities[comp1ItemPriority] = true;
                comp2Priorities[comp2ItemPriority] = true;

                groupLinePriorities[curGroupLineIndex][comp1ItemPriority] = true;
                groupLinePriorities[curGroupLineIndex][comp2ItemPriority] = true;
            }

            bool foundShared = false;
            int sharedPriority = 0;
            for (int priority = 1; priority <= maxPriority; priority++) {
                bool incomp1 = comp1Priorities[priority];
                bool incomp2 = comp2Priorities[priority];
                if (incomp1 && incomp2) {
                    assert(!foundShared);
                    foundShared = true;
                    sharedPriority = priority;
                    sharedItemsPrioritySum += priority;
                }
            }
            assert(foundShared);

            char getchFromPriority(int priority) => cast(char)(priority <= 26 ? (priority - 1) + 'a' : (priority - 27) + 'A');

            if (curGroupLineIndex == 2) {
                bool foundBadge = false;
                int badgePriority = 0;
                for (int priority = 1; priority <= maxPriority; priority++) {
                    bool g0 = groupLinePriorities[0][priority];
                    bool g1 = groupLinePriorities[1][priority];
                    bool g2 = groupLinePriorities[2][priority];
                    if (g0 && g1 && g2) {
                        assert(!foundBadge);
                        foundBadge = true;
                        badgePriority = priority;
                        badgePrioritySum += priority;
                    }
                }
                assert(foundBadge);

                curGroupLineIndex = 0;
                for (int i = 0; i < groupLinePriorities.length; i++) {
                    bool[] arr = groupLinePriorities[i];
                    memset(arr.ptr, 0, arr.length * arr[0].sizeof);
                }

                char badgeCh = getchFromPriority(badgePriority);
                badgeStorage.push(badgeCh);
            } else {
                curGroupLineIndex += 1;
            }

            char sharedChar = getchFromPriority(sharedPriority);
            Backpack backpack = {comp1, comp2, sharedChar};
            backpackStorage.push(backpack);
        }

        backpacks = backpackStorage.toSlice();
        badges = badgeStorage.copy(arena);
        assert(backpacks.length / 3 == badges.length);
        assert(badges.length * 3 == backpacks.length);
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
    Arena* arena;
    long len;
    long arenaUsedBefore;

    this(Arena* arena_, long bytes) {
        arena = arena_;
        arenaUsedBefore = arena.used;
        buf = arena.alloc!(T)(bytes);
        len = 0;
    }

    this(ref Arena arena_, long bytes) {
        this(&arena_, bytes);
    }

    this(ref Arena arena_) {
        this(&arena_, arena_.freesize);
    }

    void push(T val) {
        buf[len] = val;
        len += 1;
    }

    T[] copy(ref Arena destArena) {
        long bytes = len * T.sizeof;
        T[] result = destArena.alloc!T(bytes, T.alignof);
        memcpy(result.ptr, buf.ptr, bytes);
        return result;
    }

    T[] toSlice() {
        arena.used = arenaUsedBefore + len * T.sizeof;
        T[] result = buf[0..len];
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
    int activeSolution = 2;

    this(ref Arena arena, ref Arena scratch) {
        {
            import input;
            static foreach (typeIndex, type; Solution.Types) {{
                const string typeName = Solution.Types[typeIndex].stringof;
                mixin(typeName, " thisSolution = ", typeName, "(globalInput", typeName,  ", arena, scratch);");
                static if (typeName == "Year2022Day1") {
                    assert(thisSolution.elves[0].sum == 68802);
                    assert(thisSolution.top3sum == 205370);
                }
                static if (typeName == "Year2022Day2") {
                    assert(thisSolution.scorePart1 == 12645);
                    assert(thisSolution.scorePart2 == 11756);
                }
                static if (typeName == "Year2022Day3") {
                    assert(thisSolution.sharedItemsPrioritySum == 7674);
                    assert(thisSolution.badgePrioritySum == 2805);
                }
                mixin("solutions[", typeIndex, "] = thisSolution;");
            }}
        }
    }

    void draw(mu_Context* muctx, int windowWidth, int windowHeight, ref Arena scratch) {
        TempMemory _TEMP_ = TempMemory(scratch);
        int fontHeight = muctx.text_height(muctx.style.font);
        int fontChWidth = muctx.text_width(muctx.style.font, "0", 1);

        void layout_row(int count)(int[count] widths, int height) {
            mu_layout_row(muctx, cast(int)widths.length, widths.ptr, height);
        }

        void drawRectWithBorder(mu_Rect rect, mu_Color fill, mu_Color border) {
            int borderThickness = 1;
            mu_Rect top = rect;
            top.h = borderThickness;
            mu_Rect bottom = top;
            bottom.y += rect.h - borderThickness;
            mu_Rect left = rect;
            left.w = borderThickness;
            mu_Rect right = left;
            right.x += rect.w - borderThickness;

            mu_draw_rect(muctx, rect, fill);
            mu_draw_rect(muctx, top, border);
            mu_draw_rect(muctx, bottom, border);
            mu_draw_rect(muctx, left, border);
            mu_draw_rect(muctx, right, border);
        }

        int scale(int val, int ogMin, int ogMax, int newMin, int newMax) {
            int ogRange = ogMax - ogMin;
            float val01 = cast(float)(val - ogMin) / cast(float)ogRange;
            int newRange = newMax - newMin;
            float newvalFloat = val01 * cast(float)newRange + cast(float)newMin;
            int newvalInt = cast(int)newvalFloat;
            return newvalInt;
        }

        mu_Rect cutTop(ref mu_Rect rect, int by) {
            mu_Rect result = rect;
            result.h = by;
            rect.h -= by;
            rect.y += by;
            return result;
        }

        mu_Rect cutBottom(ref mu_Rect rect, int by) {
            mu_Rect result = rect;
            result.h = by;
            result.y = rect.y + rect.h - by;
            rect.h -= by;
            return result;
        }

        mu_Rect cutLeft(ref mu_Rect rect, int by) {
            mu_Rect result = rect;
            result.w = by;
            rect.w -= by;
            rect.x += by;
            return result;
        }

        mu_Rect cutRight(ref mu_Rect rect, int by) {
            mu_Rect result = rect;
            result.w = by;
            result.x = rect.x + rect.w - by;
            rect.w -= by;
            return result;
        }

        mu_begin(muctx);
        if (mu_begin_window_ex(muctx, "", mu_rect(0, 0, windowWidth, windowHeight), MU_OPT_NOTITLE | MU_OPT_NOCLOSE | MU_OPT_NORESIZE)) {
            layout_row([200, -1], -1);

            {
                mu_begin_panel_ex(muctx, "SolutionSelector", MU_OPT_NOFRAME);
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

                mu_end_panel(muctx);
            }

            mu_begin_panel_ex(muctx, "Solution", MU_OPT_NOFRAME);

            {
                layout_row([-1], cast(int)fontHeight * 2);
                mu_begin_panel_ex(muctx, "SolutionResultString", MU_OPT_NOFRAME);
                layout_row([-1], cast(int)fontHeight);
                struct int2 {int x; int y;} // NOTE(khvorov) The D compiler is bad and incapable of handling int[2] here
                int2 result2Numbers = solutions[activeSolution].match!(
                    (ref Year2022Day1 sol) { return int2(sol.elves[0].sum, sol.top3sum); },
                    (ref Year2022Day2 sol) { return int2(sol.scorePart1, sol.scorePart2); },
                    (ref Year2022Day3 sol) { return int2(sol.sharedItemsPrioritySum, sol.badgePrioritySum); },
                );
                string resultStr = StringBuilder(scratch).fmt("Part 1: ").fmt(result2Numbers.x).fmt(" Part 2: ").fmt(result2Numbers.y).endNull();
                mu_text(muctx, resultStr.ptr);
                mu_end_panel(muctx);
            }

            // From http://tsitsul.in/pdf/colors/dark_6.pdf
            mu_Color[6] qualitativePalette = [
                mu_color(0, 89, 0, 255),
                mu_color(0, 0, 120, 255),
                mu_color(73, 13, 0, 255),
                mu_color(138, 3, 79, 255),
                mu_color(0, 90, 138, 255),
                mu_color(68, 53 ,0, 255),
            ];
            mu_Color qualitativePaletteGray = mu_color(88, 88, 88, 255);

            mu_Color gridColor = mu_color(50, 50, 50, 255);
            mu_Color axisColor = mu_color(150, 150, 150, 255);

            solutions[activeSolution].match!(
                (ref Year2022Day1 sol) {
                    layout_row([100, -1], -1);
                    mu_begin_panel_ex(muctx, "HistogramScale", MU_OPT_NOFRAME);
                    layout_row([-1], -1);
                    mu_Rect scaleBounds = mu_layout_next(muctx);
                    mu_end_panel(muctx);

                    {
                        mu_Color histBorderColor = qualitativePaletteGray;
                        int histRectWidth = 10;

                        mu_begin_panel_ex(muctx, "HistogramRects", MU_OPT_NOFRAME);
                        int totalWidth = histRectWidth * cast(int)sol.elves.length;
                        layout_row([totalWidth], -1);
                        const mu_Rect rectBounds = mu_layout_next(muctx);
                        scaleBounds.h = rectBounds.h;
                        int scaleToPx(int val) => scale(val, 0, sol.elves[0].sum, rectBounds.y + rectBounds.h, rectBounds.y);

                        mu_Rect scaleAndRectsBounds = mu_Rect(scaleBounds.x, scaleBounds.y, rectBounds.x + rectBounds.w - scaleBounds.x, scaleBounds.h);
                        mu_Rect rectClipRect = mu_get_clip_rect(muctx);
                        mu_pop_clip_rect(muctx);
                        mu_push_clip_rect(muctx, scaleAndRectsBounds);
                        {
                            mu_Rect vlineRect = scaleBounds;
                            vlineRect.w = 2;
                            vlineRect.x += scaleBounds.w - vlineRect.w;
                            mu_draw_rect(muctx, vlineRect, axisColor);
                            for (int tickValue = 10000; tickValue < 100000; tickValue += 10000) {
                                int tickPx = scaleToPx(tickValue);
                                mu_Rect tickRect = vlineRect;
                                tickRect.x -= 5;
                                tickRect.h = 2;
                                tickRect.w = rectBounds.w;
                                tickRect.y = tickPx;
                                mu_draw_rect(muctx, tickRect, gridColor);

                                {
                                    string tickValueStr = StringBuilder(scratch).fmt(tickValue).end();
                                    mu_Vec2 pos = mu_vec2(tickRect.x - 5 * fontChWidth, tickRect.y + (tickRect.h / 2) - fontHeight / 2);
                                    mu_draw_text(muctx, muctx.style.font, tickValueStr.ptr, cast(int)tickValueStr.length, pos, axisColor);
                                }
                            }
                        }
                        mu_pop_clip_rect(muctx);
                        mu_push_clip_rect(muctx, rectClipRect);

                        mu_Rect histRect = mu_rect(rectBounds.x, rectBounds.y, histRectWidth, 0);
                        foreach (elf; sol.elves) {
                            histRect.y = scaleToPx(elf.sum);
                            histRect.h = (rectBounds.y + rectBounds.h) - histRect.y;

                            mu_Rect calorieRect = histRect;
                            calorieRect.y += calorieRect.h;
                            calorieRect.h = 0;
                            int calorieRectColorIndex = 0;
                            foreach(count; elf.calories) {
                                int yFromBase = scaleToPx(count);
                                calorieRect.h = (rectBounds.y + rectBounds.h) - yFromBase;
                                calorieRect.y -= calorieRect.h;
                                drawRectWithBorder(calorieRect, qualitativePalette[calorieRectColorIndex], histBorderColor);
                                calorieRectColorIndex = (calorieRectColorIndex + 1) % qualitativePalette.length;
                            }
                            histRect.x += histRect.w;
                        }
                        mu_end_panel(muctx);
                    }
                },

                (ref Year2022Day2 sol) {
                    layout_row([-1], -1);
                    mu_begin_panel_ex(muctx, "RockPaperScissorsOutcomes", MU_OPT_NOFRAME);

                    int topAxisBoundsHeight = fontHeight;
                    int roundRectHeight = fontHeight;
                    int gapBetweenParts = 100;
                    float scorePerRow = 1000;
                    int rowsInPart1 = sol.scorePart1 / cast(int)scorePerRow + 1;
                    int rowsInPart2 = sol.scorePart2 / cast(int)scorePerRow + 1;
                    int totalHeight = topAxisBoundsHeight + rowsInPart1 * roundRectHeight + gapBetweenParts + rowsInPart2 * roundRectHeight;

                    layout_row([-1], totalHeight);

                    mu_Rect totalBounds = mu_layout_next(muctx);
                    cutRight(totalBounds, 50);
                    mu_Rect rectBounds = totalBounds;
                    mu_Rect topAxisBounds = cutTop(rectBounds, topAxisBoundsHeight);
                    mu_Rect leftNumbersBounds = cutLeft(rectBounds, fontChWidth * 2);
                    cutLeft(topAxisBounds, leftNumbersBounds.w);

                    float pxPerRow = cast(float)rectBounds.w;
                    float pxPerScore = pxPerRow / scorePerRow;
                    mu_Rect roundRect = mu_rect(rectBounds.x, rectBounds.y, 0, roundRectHeight);

                    Year2022Day2.Round[][2] roundSets = [sol.roundsPart1, sol.roundsPart2];
                    foreach (roundSet; roundSets) {
                        int rowCount = 1;
                        int scoreSum = 0;
                        foreach (round; roundSet) {
                            roundRect.w = cast(int)(cast(float)round.score * pxPerScore + 0.5);
                            scoreSum += round.score;
                            if (scoreSum > 1000) {
                                scoreSum = round.score;
                                rowCount += 1;
                                roundRect.x = rectBounds.x;
                                roundRect.y += roundRect.h;
                            }
                            drawRectWithBorder(roundRect, qualitativePalette[round.outcome], qualitativePaletteGray);
                            roundRect.x += roundRect.w;
                        }

                        mu_Vec2 rowNumberPos = mu_Vec2(leftNumbersBounds.x, leftNumbersBounds.y);
                        for (int row = 1; row <= rowCount; row++) {
                            string rowStr = StringBuilder(scratch).fmt(row).end();
                            mu_draw_text(muctx, muctx.style.font, rowStr.ptr, cast(int)rowStr.length, rowNumberPos, axisColor);
                            rowNumberPos.y += fontHeight;
                        }

                        roundRect.x = rectBounds.x;
                        roundRect.y += gapBetweenParts;
                        leftNumbersBounds.y = roundRect.y;
                    }

                    for (int tickValue = 0; tickValue <= cast(int)scorePerRow; tickValue += 100) {
                        int tickPx = scale(tickValue, 0, cast(int)scorePerRow, topAxisBounds.x, topAxisBounds.x + topAxisBounds.w);
                        string tickStr = StringBuilder(scratch).fmt(tickValue).end();
                        int strCentered = tickPx - cast(int)tickStr.length * fontChWidth / 2;
                        mu_draw_text(muctx, muctx.style.font, tickStr.ptr, cast(int)tickStr.length, mu_vec2(strCentered, topAxisBounds.y), axisColor);
                    }

                    int legendCenterY = totalBounds.y + topAxisBoundsHeight + rowsInPart1 * roundRectHeight + gapBetweenParts / 2 - fontHeight / 2;
                    mu_Vec2 legendPos = mu_vec2(totalBounds.x, legendCenterY);
                    string[sol.Outcome.max + 1] outcomeStrs;
                    static foreach (outcomeIndex; 0..(sol.Outcome.max + 1)) {outcomeStrs[outcomeIndex] = __traits(allMembers, sol.Outcome)[outcomeIndex];}
                    for (int outcomeIndex = 0; outcomeIndex <= sol.Outcome.max; outcomeIndex++) {
                        string outcomeStr = outcomeStrs[outcomeIndex];
                        mu_Color outcomeColor = qualitativePalette[outcomeIndex];
                        mu_Rect squareRect = mu_rect(legendPos.x, legendPos.y, 10, fontHeight);
                        drawRectWithBorder(squareRect, outcomeColor, qualitativePaletteGray);
                        legendPos.x += squareRect.w + 5;
                        mu_draw_text(muctx, muctx.style.font, outcomeStr.ptr, cast(int)outcomeStr.length, legendPos, axisColor);
                        legendPos.x += outcomeStr.length * fontChWidth + 10;
                    }

                    mu_end_panel(muctx);
                },

                (ref Year2022Day3 sol) {
                    layout_row([-1], -1);
                    mu_begin_panel_ex(muctx, "Backpacks", MU_OPT_NOFRAME);

                    int totalHeight = 20000; // TODO(khvorov) Work out
                    layout_row([-1], totalHeight);
                    mu_Rect totalBounds = mu_layout_next(muctx);

                    mu_Rect compRect = mu_rect(totalBounds.x, totalBounds.y, 0, fontHeight * 2);
                    foreach (backpackIndex, backpack; sol.backpacks) {
                        int padding = 10;
                        compRect.w = cast(int)backpack.comp1.length * fontChWidth + padding;
                        if (compRect.x + compRect.w > totalBounds.x + totalBounds.w) {
                            compRect.x = totalBounds.x;
                            compRect.y += compRect.h;
                        }
                        drawRectWithBorder(compRect, qualitativePalette[backpackIndex % qualitativePalette.length], qualitativePaletteGray);

                        void drawstr(string str, mu_Vec2 textPos) {
                            mu_Vec2 chPos = textPos;
                            char badgeCh = sol.badges[backpackIndex / 3];
                            foreach(ch; str) {
                                mu_Color color = axisColor;
                                if (ch == backpack.common) {
                                    color.r += 50;
                                }
                                if (ch == badgeCh) {
                                    color.g += 50;
                                }
                                mu_draw_text(muctx, muctx.style.font, &ch, 1, chPos, color);
                                chPos.x += fontChWidth;
                            }
                        }

                        mu_Vec2 textPos = mu_vec2(compRect.x + padding / 2, compRect.y);
                        drawstr(backpack.comp1, textPos);
                        textPos.y += fontHeight;
                        drawstr(backpack.comp2, textPos);
                        compRect.x += compRect.w;
                    }

                    mu_end_panel(muctx);
                }
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
11000

24000
10000
11000

24000
10000
11000"
        ];

        int[testInput.length] topMaxSum = [24000, 45000];
        int[testInput.length] top3sum = [45000, 45000 * 3];
        int[testInput.length] elvesCount = [5, 3];
        foreach(inputIndex, input; testInput) {
            arena.used = 0;
            scratch.used = 0;
            Year2022Day1 result = Year2022Day1(input, arena, scratch);
            assert(result.elves[0].sum == topMaxSum[inputIndex]);
            assert(result.top3sum == top3sum[inputIndex]);
            assert(cast(int)result.elves.length == elvesCount[inputIndex]);
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
