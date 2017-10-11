import std.stdio;

void main(string[] args)
{
    import sfmt;
    import std.getopt;
    size_t width;
    args.getopt("width|w", &width);
    if (width == 64)
        check64!SFMT;
    if (width == 32)
        check32!SFMT;
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
