module sfmt.internal; ///

version (Big64)
    enum idxof(int i) = i ^ 1;
else
    enum idxof(int i) = i;

int idxof(int i)
{
    version (Big64)
        return i ^ 1;
    else
        return i;
}

/// 128-bit integer.
union ucent_
{
    ulong[2] u64;
    uint[4] u32;
    // checked
    ucent_ opBinary(string op)(int shift)
        if (op == "<<" || op == ">>")
    {
        immutable
            th = (ulong(u32[idxof!3]) << 32) | u32[idxof!2],
            tl = (ulong(u32[idxof!1]) << 32) | u32[idxof!0];
        ulong
            oh = mixin("th "~op~" (shift * 8)"),
            ol = mixin("tl "~op~" (shift * 8)");
        static if (op == "<<")
            oh |= tl >> (64 - shift * 8);
        static if (op == ">>")
            ol |= th << (64 - shift * 8);
        ucent_ ret;
        ret.u32[idxof!0] = cast(uint)ol;
        ret.u32[idxof!1] = ol >> 32;
        ret.u32[idxof!2] = cast(uint)oh;
        ret.u32[idxof!3] = oh >> 32;
        return ret;
    }
}

/** Recursion function.

The index below is modulo <var>n</var> for generateAll$(LPAREN)$(RPAREN).

Params:
    r = state[<var>i</var>]
    a = state[<var>i</var>-<var>n</var>]
    b = state[<var>i</var>-$(LPAREN)<var>n</var>-<var>m</var>$(RPAREN)]
    c = state[<var>i</var>-2]
    d = state[<var>i</var>-1]
*/
void recursion(uint[4] shifts, uint[4] masks)(ref ucent_ r, ref ucent_ a, ref ucent_ b, ref ucent_ c, ref ucent_ d)
{
    enum sl1 = shifts[0];
    enum sl2 = shifts[1];
    enum sr1 = shifts[2];
    enum sr2 = shifts[3];
    enum m0 = masks[idxof!0];
    enum m1 = masks[idxof!1];
    enum m2 = masks[idxof!2];
    enum m3 = masks[idxof!3];
    auto
        x = a << sl2,
        y = c >> sr2;
    r.u32[0] = a.u32[0] ^ x.u32[0] ^ ((b.u32[0] >> sr1) & m0) ^ y.u32[0] ^ (d.u32[0] << sl1);
    r.u32[1] = a.u32[1] ^ x.u32[1] ^ ((b.u32[1] >> sr1) & m1) ^ y.u32[1] ^ (d.u32[1] << sl1);
    r.u32[2] = a.u32[2] ^ x.u32[2] ^ ((b.u32[2] >> sr1) & m2) ^ y.u32[2] ^ (d.u32[2] << sl1);
    r.u32[3] = a.u32[3] ^ x.u32[3] ^ ((b.u32[3] >> sr1) & m3) ^ y.u32[3] ^ (d.u32[3] << sl1);
}

/// internal functions for seeding.
uint func1(uint x)
{
    return (x ^ (x >> 27)) * uint(1664525);
}

/// ditto
uint func2(uint x)
{
    return (x ^ (x >> 27)) * uint(1566083941);
}

/// read parameter from file (compile time).
auto parseParameters(int SFMT_mersenneExponent, size_t row)()
{
    import std.algorithm, std.format, std.range;
    auto r = import ("%d.csv".format(SFMT_mersenneExponent)).splitter("\n");
    foreach (i; 0..row)
        r.popFront;
    return Parameters(r.front.split(","));
}
/// parameters for SFMT.
struct Parameters
{
    import std.conv, std.format;
    int mersenneExponent; ///
    int DD;
    ptrdiff_t m; ///
    uint[4] shifts, /***/masks, /***/parity; ///
    this (string[] args)
    {
        mersenneExponent = args[0].to!int;
        DD = args[1].to!int;
        m = args[2].to!ptrdiff_t;
        foreach (i; 0..4)
        {
            shifts[i] = args[3+i].to!uint;
            masks[i] = args[7+i].to!uint(16);
            parity[i] = args[11+i].to!uint(16);
        }
    }
}

string sfmtMixin(size_t mexp, size_t row)
{
    import std.format;
    return "alias SFMT%d_%d = SFMT!(sfmt.internal.parseParameters!(%d, %d));\n".format(
            mexp, row-1, mexp, row);
}
