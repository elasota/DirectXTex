Convection Texture Tools

Copyright (c) 2018 Eric Lasota

Licensed under MIT License (see LICENSE.txt for details)

Convection Texture Tools are an enhanced fork of Microsoft's DirectX Texture Library (DirectXTex).

All of the CPU codecs have been replaced with new SIMD-optimized codecs that get great quality and great speed.

See the "ConvectionKernels" dir for stand-alone codecs if you want to use them outside of the library.

For usage, see ReadMe_DirectXTex.txt

Flag changes:
-rw, -gw, -bw, and -aw change channel importance for red, green, blue, and alpha respectively.
-nogpu has been removed, use -gpu 0 to use the GPU codecs, be aware that they're lower quality though.
