void year2022day1() {
    string input = getInput(__FUNCTION__);
}

void year2022day2() {
    string input = getInput(__FUNCTION__);
}

void year2022day3() {
    string input = getInput(__FUNCTION__);
}

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

string getInput(string functionName) {
    string justName = functionName[__MODULE__.length + 1 .. functionName.length];
    string inputPath = fmt("input/", justName, ".txt");
    string content = readEntireFile(inputPath);
    return content;
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
                    { writeToStdout(\"", member, "\n\"); ", member, "(); foundMatch = true; }"
                );
            }
        }
    }
    return foundMatch;
}

extern (C) int main(int argc, char** argv) {
    if (argc <= 1) {
        writeToStdout("provide function names to run (like year2022day1)\n");
        return 0;
    }

    globalArena = &globalArena_;
    globalArena.size = 1 * 1024 * 1024 * 1024;
    globalArena.base = allocvmem(globalArena.size);

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
        static assert(0, "unimplemented");
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
        static assert(0, "unimplemented");
    }

    return ptr;
}

string readEntireFile(string path) {
    string content = "";

    version (linux) {
        import core.sys.posix.fcntl;
        import core.sys.posix.unistd;

        int fd = open(cast(char*) path.ptr, O_RDONLY);
        assert(fd != -1, "could not open file");
        scope (exit)
            close(fd);

        char* ptr = cast(char*) globalArena.freeptr;
        ssize_t readRes = read(fd, ptr, globalArena.freesize);
        assert(readRes != -1, "could not read file");

        globalArena.changeUsed(readRes);

        content = cast(string) ptr[0 .. readRes];
    }

    version (Windows) {
        static assert(0, "unimplemented");
    }

    return content;
}
