import core.stdc.string : strlen;

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
                mixin("if (name == ", member.stringof, ") { ", member, "(); foundMatch = true; }");
            }
        }
    }
    return foundMatch;
}

extern (C) void main(int argc, char** argv) {
    foreach (carg; argv[0 .. argc]) {
        if (!callFunctionByName(cast(string) carg[0 .. strlen(carg)])) {
            // TODO(khvorov) Error
        }
    }
}
