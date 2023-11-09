```
./install-pngquant3.sh 

Usage:

./install-pngquant3.sh install
```

```
./install-pngquant3.sh install
Install pngqaunt 3

export PATH=/opt/pngquant/bin:$PATH

which pngquant
/opt/pngquant/bin/pngquant

ldd $(which pngquant)
        linux-vdso.so.1 (0x00007ffcfd5ba000)
        liblcms2.so.2 => /lib64/liblcms2.so.2 (0x00007f7c9b6e9000)
        libpng16.so.16 => /lib64/libpng16.so.16 (0x00007f7c9b6b2000)
        libgcc_s.so.1 => /lib64/libgcc_s.so.1 (0x00007f7c9b697000)
        libm.so.6 => /lib64/libm.so.6 (0x00007f7c9b5bc000)
        libc.so.6 => /lib64/libc.so.6 (0x00007f7c9b200000)
        libz.so.1 => /lib64/libz.so.1 (0x00007f7c9b5a2000)
        /lib64/ld-linux-x86-64.so.2 (0x00007f7c9b7f9000)

/opt/pngquant/bin/pngquant --version
3.0.3

pngquant --version
3.0.3

pngquant 3 install complete
```

```
pngquant --help
pngquant, 3.0.3 (Rust), by Kornel Lesinski, Greg Roelofs.

usage:  pngquant [options] [ncolors] -- pngfile [pngfile ...]
        pngquant [options] [ncolors] - >stdout <stdin

options:
  --force           overwrite existing output files (synonym: -f)
  --skip-if-larger  only save converted files if they're smaller than original
  --output file     destination file path to use instead of --ext (synonym: -o)
  --ext new.png     set custom suffix/extension for output filenames
  --quality min-max don't save below min, use fewer colors below max (0-100)
  --speed N         speed/quality trade-off. 1=slow, 4=default, 11=fast & rough
  --nofs            disable Floyd-Steinberg dithering
  --posterize N     output lower-precision color (e.g. for ARGB4444 output)
  --strip           remove optional metadata (default on Mac)
  --verbose         print status messages (synonym: -v)

Quantizes one or more 32-bit RGBA PNGs to 8-bit (or smaller) RGBA-palette.
The output filename is the same as the input name except that
it ends in "-fs8.png", "-or8.png" or your custom extension (unless the
input is stdin, in which case the quantized image will go to stdout).
If you pass the special output path "-" and a single input file, that file
will be processed and the quantized image will go to stdout.
The default behavior if the output file exists is to skip the conversion;
use --force to overwrite. See man page for full list of options.
```