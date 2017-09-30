module sfmt;

version (MT19937)
{
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
