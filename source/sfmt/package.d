module sfmt;

import std.stdio;
static import sfmt.internal;
import sfmt.internal : func1, func2, idxof, ucent_;

import std.algorithm : max, min;


mixin (sfmt.internal.sfmtMixins([size_t(607), 1279, 2281, 4253, 11213, 19937], [
        size_t(1), 2, 3, 4, 5, 6, 7, 8,
        9, 10, 11, 12, 13, 14, 15, 16,
        17, 18, 19, 20, 21, 22, 23, 24,
        25, 26, 27, 28, 29, 30, 31, 32]));

struct SFMT(sfmt.internal.Parameters parameters)
{
    enum mersenneExponent = parameters.mersenneExponent;
    enum SFMT_N = (mersenneExponent >> 7) + 1;
    enum SFMT_N64 = SFMT_N << 1;
    enum SFMT_N32 = SFMT_N << 2;
    enum SFMT_POS1 = parameters.POS1;
    enum shifts = parameters.shifts;
    enum masks = parameters.masks;
    enum parity = parameters.parity;
    enum id = parameters.id;
    alias recursion = sfmt.internal.recursion!(shifts, masks);

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
        foreach (i; 1..SFMT_N32)
            psfmt32[i.idxof] = 1812433253U * (psfmt32[(i - 1).idxof] ^ (psfmt32[(i - 1).idxof] >> 30)) + i;
        idx = SFMT_N32;
        assureLongPeriod;
    }
    void seed(uint[] seed)
    {
        enum size = SFMT_N * 4;
        static if (size >= 623)
            enum lag = 11;
        else static if (size >= 68)
            enum lag = 7;
        else static if (size >= 39)
            enum lag = 5;
        else
            enum lag = 3;
        enum mid = (size - lag) / 2;
        fillState(0x8b);
        immutable count = seed.length.max(SFMT_N32 - 1);
        uint* psfmt32 = &(state[0].u32[0]);
        uint r = func1(psfmt32[idxof!0] ^ psfmt32[idxof!mid] ^ psfmt32[idxof!(SFMT_N32 - 1)]);
        psfmt32[idxof!mid] += r;
        r += seed.length;
        psfmt32[idxof!(mid+lag)] += r;
        psfmt32[idxof!0] = r;

        size_t i = 1;
        foreach (j; 0..count.min(seed.length))
        {
            r = func1(
                    psfmt32[i.idxof]
                  ^ psfmt32[((i+mid)%SFMT_N32).idxof]
                  ^ psfmt32[((i+SFMT_N32-1)%SFMT_N32).idxof]);
            psfmt32[((i+mid)%SFMT_N32).idxof] += r;
            r += seed[j] + i;
            psfmt32[((i+mid+lag)%SFMT_N32).idxof] += r;
            psfmt32[i.idxof] = r;
            i = (i + 1) % SFMT_N32;
        }
        foreach (j; count.min(seed.length)..count)
        {
            r = func1(
                    psfmt32[i.idxof]
                  ^ psfmt32[((i+mid)%SFMT_N32).idxof]
                  ^ psfmt32[((i+SFMT_N32-1)%SFMT_N32).idxof]);
            psfmt32[((i+mid)%SFMT_N32).idxof] += r;
            r += i;
            psfmt32[((i+mid+lag)%SFMT_N32).idxof] += r;
            psfmt32[i.idxof] = r;
            i = (i + 1) % SFMT_N32;
        }
        foreach (j; 0..SFMT_N32)
        {
            r = func2(
                    psfmt32[i.idxof]
                  + psfmt32[((i+mid)%SFMT_N32).idxof]
                  + psfmt32[((i+SFMT_N32-1)%SFMT_N32).idxof]);
            psfmt32[((i+mid)%SFMT_N32).idxof] ^= r;
            r -= i;
            psfmt32[((i+mid+lag)%SFMT_N32).idxof] ^= r;
            psfmt32[i.idxof] = r;
            i = (i + 1) % SFMT_N32;
        }
        idx = SFMT_N32;
        assureLongPeriod;
    }
    version (Big32){} else
    T next(T)()
        if (is (T == ulong))
    {
        ulong* psfmt64 = &(state[0].u64[0]);
        assert (idx % 2 == 0, "out of alignment");
        if (SFMT_N32 <= idx)
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
        if (SFMT_N32 <= idx)
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
    {
        immutable size = array.length;
        recursion(
            array[0], state[0],
            state[0 + SFMT_POS1],
            state[SFMT_N - 2], state[SFMT_N - 1]);
        recursion(
            array[1], state[1],
            state[1 + SFMT_POS1],
            state[SFMT_N - 1], array[0]);

        foreach (i; 2 .. SFMT_N-SFMT_POS1)
        {
            recursion(
                array[i], state[i],
                state[i + SFMT_POS1],
                array[i - 2], array[i - 1]);
        }
        foreach (i; SFMT_N-SFMT_POS1 .. SFMT_N)
        {
            recursion(
                array[i], state[i],
                array[i + SFMT_POS1 - SFMT_N],
                array[i - 2], array[i - 1]);
        }
        foreach (i; SFMT_N .. size-SFMT_N)
        {
            recursion(
                array[i], array[i - SFMT_N],
                array[i + SFMT_POS1 - SFMT_N],
                array[i - 2], array[i - 1]);
        }
        foreach (j; 0..ptrdiff_t(2*SFMT_N-size).max(0))
        {
            state[j] = array[j + size - SFMT_N];
        }
        size_t j = ptrdiff_t(2*SFMT_N-size).max(0);
        foreach (i; size-SFMT_N..size)
        {
            recursion(
                array[i], array[i - SFMT_N],
                array[i + SFMT_POS1 - SFMT_N],
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
            state[0+SFMT_POS1],
            state[SFMT_N - 2], state[SFMT_N - 1]);
        recursion(
            state[1], state[1],
            state[1+SFMT_POS1],
            state[SFMT_N - 1], state[0]);
        foreach (i; 2..SFMT_N-SFMT_POS1)
        {
            recursion(
                state[i], state[i],
                state[i+SFMT_POS1],
                state[i - 2], state[i - 1]);
        }
        foreach (i; SFMT_N-SFMT_POS1..SFMT_N)
        {
            recursion(
                state[i], state[i],
                state[i+SFMT_POS1-SFMT_N],
                state[i - 2], state[i - 1]);
        }
        idx = 0;
    }
    ucent_[SFMT_N] state;
    int idx;
    /// returns true if modification is done
    bool assureLongPeriod()
    {
        uint inner;
        uint* psfmt32 = &(state[0].u32[0]);
        foreach (i; 0..4)
            inner ^= psfmt32[i.idxof] & parity[i];
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

