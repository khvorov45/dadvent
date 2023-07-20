void year2023day1() {
    int x = 1;
}

void year2023day2() {
    int x = 0;
}

void year2023day3() {
    int x = 0;
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
        writeToStdout("provide function names to run (like year2023day1)\n");
        return 0;
    }

    foreach (carg; argv[1 .. argc]) {
        import core.stdc.string : strlen;

        if (!callFunctionByName(cast(string) carg[0 .. strlen(carg)])) {
            writeToStdout("arg not found\n");
        }
    }

    return 0;
}

void writeToStdout(string msg) {
    version (linux) {
        import core.sys.posix.unistd : write, STDOUT_FILENO;

        write(STDOUT_FILENO, msg.ptr, msg.length);
    }

    version (Windows) {
        static assert(0, "unimplemented");
    }
}
