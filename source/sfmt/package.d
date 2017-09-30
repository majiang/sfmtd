module sfmt;

static import sfmt.internal;
alias recursion = sfmt.internal.recursion!(18, 1, 11, 1, masks);
import sfmt.internal : func1, func2, idxof, ucent_;

import std.algorithm : max, min;

version (MT19937)
{
    enum SFMT_MEXP = 19937;
    enum SFMT_N = (SFMT_MEXP >> 7) + 1;
    enum SFMT_N64 = SFMT_N << 1;
    enum SFMT_N32 = SFMT_N << 2;
    enum masks = [0xdfffffefU, 0xddfecb7fU, 0xbffaffffU, 0xbffffff6U];
    enum parity = [0x00000001U, 0x00000000U, 0x00000000U, 0x13c9e684U];
    enum id = "SFMT-19937:122-18-1-11-1:dfffffef-ddfecb7f-bffaffff-bffffff6";

    struct SFMT
    {
        enum id = .id;
        this (uint seed)
        {
            this.seed(seed);
        }
        this (uint[] seed)
        {
            this.seed(seed);
        }
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
            state = typeof (state).init;
            auto count = SFMT_N32.max(seed.length + 1);
            uint* psfmt32 = &(state[0].u32[0]);
            uint r = func1(psfmt32[idxof!0] ^ psfmt32[idxof!mid] ^ psfmt32[idxof!(SFMT_N32 - 1)]);
            psfmt32[idxof!mid] += r;
            r += seed.length;
            psfmt32[idxof!(mid+lag)] += r;
            psfmt32[idxof!0] = r;
            count -= 1;

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
        T next(T)()
            if (is (T == ulong) || is (T == uint))
        {
            return T.init;
        }
        T next(T)(size_t size)
            if (is (T == ulong[]) || is (T == uint[]))
        {
            return T.init;
        }
        ucent_[SFMT_N] state;
        int idx;
        /// returns true if modification is done
        bool assureLongPeriod()
        {
            uint inner;
            uint* psfmt32 = &(state[0].u32[0]);
            foreach (i; 0..4)
                inner ^= psfmt32[i.idxof] ^ parity[i];
            foreach (i; [16, 8, 4, 2, 1])
                inner ^= inner >> i;
            inner ^= 1;
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
}
else
{
    static assert (false, "Not supported");
}

version (BigEndian)
{
    pragma (msg, "not tested");
    version (Only64bit)
        version = Big64;
    else version (With32bit)
    {
    }
    else static assert (false, "Specify Only64bit or With32bit in BigEndian environment");
}
version (LittleEndian)
{
    pragma (msg, "supported");
}

version (Only64bit)
    version (With32bit)
        static assert (false, "Specify (at most) one of Only64bit or With32bit");

