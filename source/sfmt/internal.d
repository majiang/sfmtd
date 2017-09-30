module sfmt.internal;

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

union ucent_
{
    ulong[2] u64;
    uint[4] u32;
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
        ret.u32[idxof!2] = cast(uint)ol;
        ret.u32[idxof!3] = ol >> 32;
        return ret;
    }
}

void recursion(uint sl1, uint sl2, uint sr1, uint sr2, uint[4] masks)(ref ucent_ r, ref ucent_ a, ref ucent_ b, ref ucent_ c, ref ucent_ d)
{
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

uint func1(uint x)
{
    return (x ^ (x >> 27)) * uint(1664525);
}

uint func2(uint x)
{
    return (x ^ (x >> 27)) * uint(1566083941);
}
