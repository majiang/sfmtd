module sfmt;

version (unittest)
    import std.stdio : stderr;
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
static this ()
{
    static foreach (mexp; [size_t(607), 1279, 2281, 4253, 11213, 19937])
    {
        import std.range : iota;
        import std.format : format;
        static foreach (row; 32.iota)
        {
            rtSFMTs ~= RunTimeSFMT(mixin ("SFMT%d_%d".format(mexp, row)).params);
        }
    }
}
RunTimeSFMT[] rtSFMTs;///
///
unittest
{
    assert (rtSFMTs.length == 192);
}

///
struct SFMT(sfmt.internal.Parameters parameters)
{
    private alias params = parameters;
    enum isUniformRandom = true;///
    enum empty = false;///
    enum min = ulong.min;///
    enum max = ulong.max;///
    enum mersenneExponent = parameters.mersenneExponent;///
    enum n = (mersenneExponent >> 7) + 1;///
    enum size = n << 2;///
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
    enum m = parameters.m;///
    enum shifts = parameters.shifts;///
    enum masks = parameters.masks;///
    enum parity = parameters.parity;///
    alias recursion = sfmt.internal.recursion!(shifts, masks);
    ucent_[n] state;
    mixin SFMTMixin;
    enum id = "SFMT-%d:%d-%(%d-%):%(%08x-%)".format(
                mersenneExponent, m,
                shifts[],
                masks[]
                );///
}
///
mixin template SFMTMixin()
{
    ///
    this (uint seed)
    {
        this.seed(seed);
    }
    ///
    this (uint[] seed)
    {
        this.seed(seed);
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
    ///
    void seed(uint seed)
    {
        uint* psfmt32 = &(state[0].u32[0]);
        psfmt32[idxof!0] = seed;
        foreach (i; 1..size)
            psfmt32[i.idxof] = 1812433253U * (psfmt32[(i - 1).idxof] ^ (psfmt32[(i - 1).idxof] >> 30)) + i;
        idx = size;
        assureLongPeriod;
        generateAll;
    }
    ///
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
        generateAll;
    }
    /// input range interface.
    ulong front() @property
    {
        assert (idx % 2 == 0, "out of alignment");
        ulong* psfmt64 = &(state[0].u64[0]);
        return psfmt64[idx / 2];
    }
    /// ditto
    void popFront()
    {
        idx += 2;
        if (size <= idx) // in current implementation,
            generateAll; // this is necessary when only popFront is called repeatedly.
    }
    version (Big32){} else
    T frontPop(T : ulong)()///
    {
        auto ret = front;
        popFront;
        return ret;
    }
    version (Big64){} else
    T frontPop(T : uint)()///
    {
        uint* psfmt32 = &(state[0].u32[0]);
        immutable r = psfmt32[idx];
        idx += 1;
        if (size <= idx)
            generateAll;
        return r;
    }
    ///
    T next(T)(size_t size)
        if (is (T == ulong[]) || is (T == uint[]))
    {
        return cast(T)fill(cast(ucent_[])(new T(size)));
    }
    private auto fill(ucent_[] array)
    in
    {
        assert (n <= array.length);
        assert (idx % 4 == 0, "out of alignment");
    }
    body
    {
        immutable size_t
            index = idx / 4,
            size = array.length;
        immutable size_t
            prepared = n-index;
        array[0..prepared] = state[index..$];
        scope (failure)
        {
            import std.stdio;
            stderr.writefln("index:%d, size:%d, prepared:%d, n-m:%d, n:%d",
                index, size, prepared, n-m, n);
        }
        // array[prepared-j] == state[n-j]
        // array[i-n] == state[i-prepared]
        // array[i] == state[i+n-prepared] == state[i+index]
        immutable size_t[] bounds = [0, 1, n-m, n];
        if (prepared <= 0)
        {
            recursion(
                array[0], state[0],
                state[m],
                state[index-2], array[index-1]);
        }
        if (prepared <= 1)
        {
            recursion(
                array[1], state[1-prepared],
                state[1+m-prepared],
                state[index-1], array[0]);
        }
        if (prepared <= n-m-1)
        foreach (i; prepared.max(2)..n-m)
        {
            recursion(
                array[i], state[i-prepared],
                state[i-(prepared-m)],
                array[i-2], array[i-1]);
        }
        foreach (i; prepared.max(n-m)..n)
        {
            recursion(
                array[i], state[i-prepared],
                array[i-(n-m)],
                array[i-2], array[i-1]);
        }
        foreach (i; n .. size)
        {
            recursion(
                array[i], array[i-n],
                array[i-(n-m)],
                array[i-2], array[i-1]);
        }
        // array[$-n+i] == state[i-n]
        // array[$+i] == state[i]
        recursion(
            state[0], array[$-n],
            array[$-(n-m)],
            array[$-2], array[$-1]);
        recursion(
            state[1], array[$+1-n],
            array[$+1-(n-m)],
            array[$-1], state[0]);
        foreach (i; 2..(n-m))
        {
            recursion(
                state[i], array[$+i-n],
                array[$+i-(n-m)],
                state[i-2], state[i-1]);
        }
        foreach (i; (n-m)..n)
        {
            recursion(
                state[i], array[$+i-n],
                state[i-(n-m)],
                state[i-2], state[i-1]);
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
}
///
struct RunTimeSFMT
{
    mixin SFMTMixin;
    size_t mersenneExponent;///
    ptrdiff_t n/***/, size/***/, lag, mid;
    size_t tail, imid, iml;
    size_t m;///
    size_t[4] shifts/***/, masks/***/, parity/***/;
    ucent_[] state;
    ///
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
    ///
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
    ///
    string id()
    {
        return "SFMT-%d:%d-%(%d-%):%(%08x-%)".format(
                mersenneExponent, m,
                shifts[],
                masks[]
                );
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
        assert (ct.frontPop!ulong == rt.frontPop!ulong);
    stderr.writeln("checked compile time and run time");
}
unittest
{
    import std.random;
    static assert (isUniformRNG!SFMT19937);
    assert (SFMT19937(4321u).front == 16924766246869039260UL);
}
unittest
{
    import std.algorithm : equal;
    import std.range : take;
    assert (SFMT19937(4321u).next!(ulong[])(1000).equal(
            SFMT19937(4321u).take(1000)));
    stderr.writeln("checked next!ulong[] and range functionality");
}

unittest
{
    version (unittest){} else static assert (false);
    import std.random;
    auto sfmt = SFMT19937(4321u);
    foreach (i; 0..1000)
    {
        assert (0 <= sfmt.uniform01!real);
        assert (0 <= sfmt.uniform01!double);
        assert (0 <= sfmt.uniform01!float);
        assert (sfmt.uniform01!real < 1);
        assert (sfmt.uniform01!double < 1);
        assert (sfmt.uniform01!float < 1);
    }
    stderr.writeln("checked uniform01");

    auto sixThousandth = sfmt.front;
    sfmt = SFMT19937(4321u);
    foreach (i; 0..6000)
        sfmt.popFront;
    assert (sfmt.front == sixThousandth);
    stderr.writeln("checked call-only-popFront case");
}
unittest
{
    void testNext(U, ISFMT)(ISFMT sfmt)
    {
        auto copy = sfmt;
        auto firstBlock = sfmt.next!(U[])(10000);
        auto secondBlock = sfmt.next!(U[])(10000);
        U s;
        foreach (i, b; firstBlock)
            assert (b == (s = copy.frontPop!U), "mismatch: first[%d] = %0*,8x != %0*,8x".format(i, U.sizeof>>1, b, U.sizeof>>1, s));
        foreach (i, b; secondBlock)
            assert (b == (s = copy.frontPop!U), "mismatch: second[%d;%d] = %0*,8x != %0*,8x".format(i, i+firstBlock.length, U.sizeof>>1, b, U.sizeof>>1, s));
    }
    testNext!ulong(SFMT19937(4321u));
    testNext!ulong(SFMT19937([uint(5), 4, 3, 2, 1]));
    testNext!uint(SFMT19937(1234u));
    testNext!uint(SFMT19937([uint(0x1234), 0x5678, 0x9abc, 0xdef0]));
    stderr.writeln("checked next!U and next!U[] (U = ulong, uint)");
}
unittest
{
    void testPopFrontThenBlock(size_t firstSize, size_t secondSize)
    {
        import std.range : drop, take;
        import std.algorithm : equal;
        auto sfmt = SFMT19937(4321u);
        foreach (i; 0..firstSize*2)
            sfmt.popFront;
        auto a = sfmt.next!(ulong[])(secondSize*2);
        auto b = SFMT19937(4321u).drop(firstSize*2).take(secondSize*2);
        assert (a.equal(b));
    }
    foreach (i; 0..SFMT19937.n)
        foreach (j; SFMT19937.n..SFMT19937.n*2)
        {
            testPopFrontThenBlock(i, j);
        }
    stderr.writeln("checked next!U[]");
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

