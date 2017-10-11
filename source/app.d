import std.stdio;

void main(string[] args)
{
    import sfmt;
    import std.format, std.getopt;
    size_t width;
    args.getopt("width|w", &width);
    switch (args[1])
    {
        break; case "check":
            if (width == 64)
                check64!SFMT;
            if (width == 32)
                check32!SFMT;
            if (width == 96)
            {
                writeln("64bit:");
                check64!SFMT;
                writeln("32bit:");
                check32!SFMT;
            }
        break; case "speed":
            if (width == 64)
                speed64!SFMT;
            if (width == 32)
                speed32!SFMT;
            if (width == 96)
            {
                writeln("64bit:");
                speed64!SFMT;
                writeln("32bit:");
                speed32!SFMT;
            }
        break; default:
            throw new Exception("Unknown command '%s'".format(args[1]));
    }
}
void check32(ISFMT)()
{
    ISFMT.id.writeln;
    uint(1234).check!(uint, ISFMT)(10000, 1000, 10000, 700); // checked!
    [uint(0x1234), 0x5678, 0x9abc, 0xdef0].check!(uint, ISFMT)(10000, 1000, 10000, 700);
}
void check64(ISFMT)()
{
    ISFMT.id.writeln;
    uint(4321).check!(ulong, ISFMT)(5000, 1000, 5000, 700);
    [uint(5), 4, 3, 2, 1].check!(ulong, ISFMT)(5000, 1000, 5000, 700);
}
void check(U, ISFMT, SEED)(SEED seed, size_t firstSize, size_t print, size_t secondSize, size_t check)
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

    import std.exception : enforce;
    import std.string : format;

    static if (is (SEED == uint))
        "init_gen_rand__________".writeln;
    static if (is (SEED == uint[]))
        "init_by_array__________".writeln;
    auto sfmt = ISFMT(seed);
    auto first = sfmt.next!(U[])(firstSize);
    auto second = sfmt.next!(U[])(secondSize);
    assert (first.length == firstSize);
    assert (second.length == secondSize);
    sfmt.seed(seed);
    foreach (i, a; first)
    {
        auto r = sfmt.next!U;
        (r == a).enforce("mismatch at %d first:%x gen:%x".format(i, a, r));
        if (print <= i)
            continue;
        (fmt~" ").writef(r);
        if ((i + 1) % columns)
            continue;
        writeln;
    }
    if (print % columns)
        writeln;
    foreach (i, a; second)
    {
        auto r = sfmt.next!U;
        (r == a).enforce("mismatch at %d second:%x gen:%x".format(i, a, r));
        if (check == i)
            break;
    }
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
        res[i] = sfmt.next!U;
    }
    return sw.peek.total!"msecs";
}
