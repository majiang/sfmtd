import std.stdio;

void main(string[] args)
{
    import sfmt : rtSFMTs, SFMT19937;
    import std.exception, std.format, std.getopt;
    import std.algorithm;
    size_t width;
    size_t mexp;
    size_t row;
    args.getopt("width|w", &width, "mexp|x", &mexp, "index|i", &row);
    enum mexps = [size_t(607), 1279, 2281, 4253, 11213, 19937];
    auto ix = mexps.length - mexps.find(mexp).length;
    (ix < mexps.length).enforce("mexp must be one of %(%d, %).".format(mexps));
    (row < 32).enforce("index must be less than 32.");
    switch (args[1])
    {
        break; case "check":
            auto sfmt = rtSFMTs[32*ix+row];
            auto target = (2 < args.length) ? File(args[2], "w") : stdout;
            if (width & 64)
            {
                sfmt.check64(target);
            }
            if (width & 32)
            {
                sfmt.check32(target);
            }
        break; case "speed":
            if (width & 64)
            {
                writeln("64bit:");
                speed64!SFMT19937;
            }
            if (width & 32)
            {
                writeln("32bit:");
                speed32!SFMT19937;
            }
        break; default:
            throw new Exception("Unknown command '%s'".format(args[1]));
    }
}
void check32(ISFMT)(ISFMT sfmt, File target)
{
    target.writeln(sfmt.id);
    target.writeln("32 bit generated randoms");
    sfmt.seed(uint(1234));
    sfmt.check!uint(10000, 1000, 10000, 700, target); // checked!
    sfmt.seed([uint(0x1234), 0x5678, 0x9abc, 0xdef0]);
    sfmt.check!uint(10000, 1000, 10000, 700, target);
}
void check64(ISFMT)(ISFMT sfmt, File target)
{
    target.writeln(sfmt.id);
    target.writeln("64 bit generated randoms");
    sfmt.seed(uint(4321));
    sfmt.check!ulong(5000, 1000, 5000, 700, target);
    sfmt.seed([uint(5), 4, 3, 2, 1]);
    sfmt.check!ulong(5000, 1000, 5000, 700, target);
}
void check(U, ISFMT)(ISFMT sfmt, size_t firstSize, size_t print, size_t secondSize, size_t check, File target)
{
    static if (is (U == uint))
    {
        enum fmt = "%10d";
        enum columns = 5;
    }
    static if (is (U == ulong))
    {
        enum fmt = "%20d";
        enum columns = 3;
    }

    import std.range : chunks, take;

    static if (is (SEED == uint))
        "init_gen_rand__________".writeln;
    static if (is (SEED == uint[]))
        "init_by_array__________".writeln;
    auto toPrint = sfmt.next!(U[])(sfmt.size*2).take(print).chunks(columns);
    target.writefln("%(%("~fmt~" %)\n%)", toPrint);
}
import std.datetime.stopwatch;
import std.random;
void speed32(ISFMT)(in size_t n = 1_0000_0000, in size_t t = 10)
{
    writeln("phobos-MT\tSFMT");
    auto buf = new uint[n];
    foreach (i; 0..t)
        "%d\t%d".writefln(speedMT(Mt19937(), buf), speedSFMT!uint(ISFMT(), buf));
}
void speed64(ISFMT)(in size_t n = 5000_0000, in size_t t = 10)
{
    writeln("phobos-MT\tSFMT");
    auto buf = new ulong[n];
    foreach (i; 0..t)
        "%d\t%d".writefln(speedMT(Mt19937_64(), buf), speedSFMT!ulong(ISFMT(), buf));
}
auto speedMT(IMT)(IMT mt, void[] _res)
{
    mt.seed(unpredictableSeed);
    auto res = cast(typeof (mt.front)[])_res;
    auto sw = StopWatch(AutoStart.yes);
    foreach (i; 0..res.length)
    {
        res[i] = mt.front;
        mt.popFront;
    }
    return sw.peek.total!"msecs";
}
auto speedSFMT(U, ISFMT)(ISFMT sfmt, void[] _res)
{
    sfmt.seed(unpredictableSeed);
    auto res = cast(U[]) _res;
    auto sw = StopWatch(AutoStart.yes);
    foreach (i; 0..res.length)
    {
        res[i] = sfmt.frontPop!U;
    }
    return sw.peek.total!"msecs";
}
