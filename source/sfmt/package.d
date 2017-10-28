module sfmt;

import std.stdio;
static import sfmt.internal;
import sfmt.internal : func1, func2, idxof, ucent_;

import std.algorithm : max, min;

static foreach (mexp; [size_t(607), 1279, 2281, 4253, 11213, 19937])
{
    import std.range : iota;
    import std.algorithm : map;
    import std.format : format;
    static foreach (row; 32.iota.map!(_=>_+1))
    {
        mixin (sfmt.internal.sfmtMixin(mexp, row));
    }
    mixin ("alias SFMT%d = SFMT%d_0;".format(mexp, mexp));
}

struct SFMT(sfmt.internal.Parameters parameters)
{
    enum isUniformRandom = true;
    enum empty = false;
    enum min = ulong.min;
    enum max = ulong.max;
    enum mersenneExponent = parameters.mersenneExponent;
    enum n = (mersenneExponent >> 7) + 1;
    enum size = n << 2;
    static if (size >= 623)
        enum lag = 11;
    else static if (size >= 68)
        enum lag = 7;
    else static if (size >= 39)
        enum lag = 5;
    else
        enum lag = 3;
    enum mid = (size - lag) / 2;
    enum tail = idxof!(size - 1);
    enum imid = idxof!mid;
    enum iml = idxof!(mid+lag);
    enum m = parameters.m;
    enum shifts = parameters.shifts;
    enum masks = parameters.masks;
    enum parity = parameters.parity;
    enum id = parameters.id;
    alias recursion = sfmt.internal.recursion!(shifts, masks);
    ucent_[n] state;
    mixin SFMTMixin;
}
mixin template SFMTMixin()
{
    this (uint seed)
    {
        this.seed(seed);
    }
    this (uint[] seed)
    {
        this.seed(seed);
    }
    void printState()
    {
        import std.stdio;
        "state:".writeln;
        foreach (row; state[0..2]~state[$-2..$])
            "%(%08x %)".writefln(row.u32);
    }
    void fillState(ubyte b)
    {
        ucent_ x;
        x.u32[0] = b;
        x.u32[0] = x.u32[0] << 8 | x.u32[0];
        x.u32[0] = x.u32[0] << 16 | x.u32[0];
        x.u32[1..$] = x.u32[0];
        state[] = x;
    }
    // checked
    void seed(uint seed)
    {
        uint* psfmt32 = &(state[0].u32[0]);
        psfmt32[idxof!0] = seed;
        foreach (i; 1..size)
            psfmt32[i.idxof] = 1812433253U * (psfmt32[(i - 1).idxof] ^ (psfmt32[(i - 1).idxof] >> 30)) + i;
        idx = size;
        assureLongPeriod;
    }
    void seed(uint[] seed)
    {
        fillState(0x8b);
        immutable count = seed.length.max(size - 1);
        uint* psfmt32 = &(state[0].u32[0]);
        uint r = func1(psfmt32[idxof!0] ^ psfmt32[imid] ^ psfmt32[tail]);
        psfmt32[imid] += r;
        r += seed.length;
        psfmt32[iml] += r;
        psfmt32[idxof!0] = r;

        size_t i = 1;
        foreach (j; 0..count.min(seed.length))
        {
            r = func1(
                    psfmt32[i.idxof]
                  ^ psfmt32[((i+mid)%size).idxof]
                  ^ psfmt32[((i+size-1)%size).idxof]);
            psfmt32[((i+mid)%size).idxof] += r;
            r += seed[j] + i;
            psfmt32[((i+mid+lag)%size).idxof] += r;
            psfmt32[i.idxof] = r;
            i = (i + 1) % size;
        }
        foreach (j; count.min(seed.length)..count)
        {
            r = func1(
                    psfmt32[i.idxof]
                  ^ psfmt32[((i+mid)%size).idxof]
                  ^ psfmt32[((i+size-1)%size).idxof]);
            psfmt32[((i+mid)%size).idxof] += r;
            r += i;
            psfmt32[((i+mid+lag)%size).idxof] += r;
            psfmt32[i.idxof] = r;
            i = (i + 1) % size;
        }
        foreach (j; 0..size)
        {
            r = func2(
                    psfmt32[i.idxof]
                  + psfmt32[((i+mid)%size).idxof]
                  + psfmt32[((i+size-1)%size).idxof]);
            psfmt32[((i+mid)%size).idxof] ^= r;
            r -= i;
            psfmt32[((i+mid+lag)%size).idxof] ^= r;
            psfmt32[i.idxof] = r;
            i = (i + 1) % size;
        }
        idx = size;
        assureLongPeriod;
    }
    /// input range interface.
    ulong front() @property
    {
        assert (idx % 2 == 0, "out of alignment");
        ulong* psfmt64 = &(state[0].u64[0]);
        if (size <= idx) // in current implementation,
            generateAll; // this is necessary for first call.
        return psfmt64[idx / 2];
    }
    /// ditto.
    void popFront()
    {
        idx += 2;
        if (size <= idx) // in current implementation,
            generateAll; // this is necessary when only popFront is called repeatedly.
    }
    version (Big32){} else
    T next(T)()
        if (is (T == ulong))
    {
        ulong* psfmt64 = &(state[0].u64[0]);
        assert (idx % 2 == 0, "out of alignment");
        if (size <= idx)
            generateAll;
        immutable r = psfmt64[idx / 2];
        idx += 2;
        return r;
    }
    version (Big64){} else
    T next(T)()
        if (is (T == uint))
    {
        uint* psfmt32 = &(state[0].u32[0]);
        if (size <= idx)
            generateAll;
        immutable r = psfmt32[idx];
        idx += 1;
        return r;
    }
    T next(T)(size_t size)
        if (is (T == ulong[]) || is (T == uint[]))
    {
        return cast(T)fill(cast(ucent_[])(new T(size)));
    }
    private auto fill(ucent_[] array)
    in
    {
        assert (n <= array.length);
    }
    body
    {
        immutable size = array.length;
        recursion(
            array[0], state[0],
            state[0 + m],
            state[n - 2], state[n - 1]);
        recursion(
            array[1], state[1],
            state[1 + m],
            state[n - 1], array[0]);

        foreach (i; 2 .. n-m)
        {
            recursion(
                array[i], state[i],
                state[i + m],
                array[i - 2], array[i - 1]);
        }
        foreach (i; n-m .. n)
        {
            recursion(
                array[i], state[i],
                array[i + m - n],
                array[i - 2], array[i - 1]);
        }
        foreach (i; n .. size-n)
        {
            recursion(
                array[i], array[i - n],
                array[i + m - n],
                array[i - 2], array[i - 1]);
        }
        foreach (j; 0..ptrdiff_t(2*n-size).max(0))
        {
            state[j] = array[j + size - n];
        }
        size_t j = ptrdiff_t(2*n-size).max(0);
        foreach (i; size-n..size)
        {
            recursion(
                array[i], array[i - n],
                array[i + m - n],
                array[i - 2], array[i - 1]);
            state[j] = array[i];
            j += 1;
        }
        return array;
    }
    private void generateAll()
    {
        recursion(
            state[0], state[0],
            state[0+m],
            state[n - 2], state[n - 1]);
        recursion(
            state[1], state[1],
            state[1+m],
            state[n - 1], state[0]);
        foreach (i; 2..n-m)
        {
            recursion(
                state[i], state[i],
                state[i+m],
                state[i - 2], state[i - 1]);
        }
        foreach (i; n-m..n)
        {
            recursion(
                state[i], state[i],
                state[i+m-n],
                state[i - 2], state[i - 1]);
        }
        idx = 0;
    }
    int idx;
    /// returns true if modification is done
    bool assureLongPeriod()
    {
        uint inner;
        uint* psfmt32 = &(state[0].u32[0]);
        static foreach (i; 0..4)
            inner ^= psfmt32[idxof!i] & parity[i];
        foreach (i; [16, 8, 4, 2, 1])
            inner ^= inner >> i;
        inner &= 1;
        if (inner == 1)
            return false;
        foreach (i; 0..4)
        {
            uint working = 1;
            foreach (j; 0..32)
            {
                if (working & parity[i])
                {
                    psfmt32[i.idxof] ^= working;
                    return true;
                }
                working <<= 1;
            }
        }
        assert (false, "unreachable?");
    }
    void dumpState()
    {
        debug
        {
            import std.stdio;
            foreach (i, elem; state)
            {
                if (i % 2)
                    stderr.write(" ");
                stderr.writef("%(%016x-%)", elem.u64[]);
                if (i % 2)
                    stderr.writeln;
            }
        }
    }
}
struct RunTimeSFMT
{
    mixin SFMTMixin;
    size_t mersenneExponent;
    ptrdiff_t n, size, lag, mid;
    size_t tail, imid, iml;
    size_t m;
    size_t[4] shifts, masks, parity;
    ucent_[] state;
    this (sfmt.internal.Parameters parameters)
    {
        mexp(parameters.mersenneExponent);
        m = parameters.m;
        shifts = parameters.shifts;
        masks = parameters.masks;
        parity = parameters.parity;
        import std.random : unpredictableSeed;
        seed(unpredictableSeed);
    }
    size_t mexp(size_t value) @property
    {
        mersenneExponent = value;
        n = (value >> 7) + 1;
        state.length = n;
        size = n << 2;
        if (size >= 623)
            lag = 11;
        else if (size >= 68)
            lag = 7;
        else if (size >= 39)
            lag = 5;
        else
            lag = 3;
        mid = (size - lag) / 2;
        tail = (size - 1).idxof;
        imid = mid.idxof;
        iml = (mid+lag).idxof;
        return value;
    }
    void recursion(ref ucent_ r, ref ucent_ a, ref ucent_ b, ref ucent_ c, ref ucent_ d)
    {
        immutable
            sl1 = shifts[0],
            sl2 = shifts[1],
            sr1 = shifts[2],
            sr2 = shifts[3];
        immutable
            m0 = masks[idxof!0],
            m1 = masks[idxof!1],
            m2 = masks[idxof!2],
            m3 = masks[idxof!3];
        auto
            x = a << sl2,
            y = c >> sr2;
        r.u32[0] = a.u32[0] ^ x.u32[0] ^ ((b.u32[0] >> sr1) & m0) ^ y.u32[0] ^ (d.u32[0] << sl1);
        r.u32[1] = a.u32[1] ^ x.u32[1] ^ ((b.u32[1] >> sr1) & m1) ^ y.u32[1] ^ (d.u32[1] << sl1);
        r.u32[2] = a.u32[2] ^ x.u32[2] ^ ((b.u32[2] >> sr1) & m2) ^ y.u32[2] ^ (d.u32[2] << sl1);
        r.u32[3] = a.u32[3] ^ x.u32[3] ^ ((b.u32[3] >> sr1) & m3) ^ y.u32[3] ^ (d.u32[3] << sl1);
    }
}
unittest
{
    auto ct = SFMT19937(13579u);
    RunTimeSFMT rt;
    rt.mexp(ct.mersenneExponent);
    rt.m = ct.m;
    rt.shifts = ct.shifts;
    rt.masks = ct.masks;
    rt.parity = ct.parity;
    rt.seed(13579u);
    foreach (i; 0..1000)
        assert (ct.next!ulong == rt.next!ulong);
    stderr.writeln("unittest passed!");
}
unittest
{
    import std.random;
    static assert (isUniformRNG!SFMT19937);
    assert (SFMT19937(4321u).front == 16924766246869039260UL);
    import std.algorithm : equal;
    import std.range : take;
    pragma (msg, "check output of original and range interfaces.");
    // currently, only normal case is tested: need to test the cases front and popFront are unequally called.
    assert (SFMT19937(4321u).next!(ulong[])(1000).equal(
            SFMT19937(4321u).take(1000)));
    import std.traits : isIntegral;
    auto sfmt = SFMT19937(4321u),
        x = sfmt.uniform01!real,
        y = sfmt.uniform01!double,
        z = sfmt.uniform01!float;
}

version (BigEndian)
{
    pragma (msg, "not tested");
    version (Only64bit)
        version = Big64;
    else version (With32bit)
        version = Big32;
    else static assert (false, "Specify Only64bit or With32bit in BigEndian environment");
}
version (LittleEndian)
{
    pragma (msg, "supported");
}

version (Only64bit)
    version (With32bit)
        static assert (false, "Specify (at most) one of Only64bit or With32bit");

