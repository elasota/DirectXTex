using System;
using System.Collections.Generic;
using System.IO;
using System.Drawing;

namespace InspectDDS
{
    public struct DDSHeader
    {
        public uint size;
        public uint flags;
        public uint height;
        public uint width;
        public uint pitchOrLinearSize;
        public uint depth;
        public uint mipMapCount;
        public DDSPixelFormat pixelFormat;
        public uint caps;
        public uint caps2;
        public uint caps3;
        public uint caps4;
    }

    public struct DDSPixelFormat
    {
        public uint size;
        public uint flags;
        public uint fourCC;
        public uint rgbBitCount;
        public uint rBitMask;
        public uint gBitMask;
        public uint bBitMask;
        public uint aBitMask;
    }

    public enum ResourceDimension
    {
        D3D10_RESOURCE_DIMENSION_UNKNOWN = 0,
        D3D10_RESOURCE_DIMENSION_BUFFER = 1,
        D3D10_RESOURCE_DIMENSION_TEXTURE1D = 2,
        D3D10_RESOURCE_DIMENSION_TEXTURE2D = 3,
        D3D10_RESOURCE_DIMENSION_TEXTURE3D = 4
    }

    public enum DXGIFormat
    {
        DXGI_FORMAT_UNKNOWN = 0,
        DXGI_FORMAT_R32G32B32A32_TYPELESS = 1,
        DXGI_FORMAT_R32G32B32A32_FLOAT = 2,
        DXGI_FORMAT_R32G32B32A32_UINT = 3,
        DXGI_FORMAT_R32G32B32A32_SINT = 4,
        DXGI_FORMAT_R32G32B32_TYPELESS = 5,
        DXGI_FORMAT_R32G32B32_FLOAT = 6,
        DXGI_FORMAT_R32G32B32_UINT = 7,
        DXGI_FORMAT_R32G32B32_SINT = 8,
        DXGI_FORMAT_R16G16B16A16_TYPELESS = 9,
        DXGI_FORMAT_R16G16B16A16_FLOAT = 10,
        DXGI_FORMAT_R16G16B16A16_UNORM = 11,
        DXGI_FORMAT_R16G16B16A16_UINT = 12,
        DXGI_FORMAT_R16G16B16A16_SNORM = 13,
        DXGI_FORMAT_R16G16B16A16_SINT = 14,
        DXGI_FORMAT_R32G32_TYPELESS = 15,
        DXGI_FORMAT_R32G32_FLOAT = 16,
        DXGI_FORMAT_R32G32_UINT = 17,
        DXGI_FORMAT_R32G32_SINT = 18,
        DXGI_FORMAT_R32G8X24_TYPELESS = 19,
        DXGI_FORMAT_D32_FLOAT_S8X24_UINT = 20,
        DXGI_FORMAT_R32_FLOAT_X8X24_TYPELESS = 21,
        DXGI_FORMAT_X32_TYPELESS_G8X24_UINT = 22,
        DXGI_FORMAT_R10G10B10A2_TYPELESS = 23,
        DXGI_FORMAT_R10G10B10A2_UNORM = 24,
        DXGI_FORMAT_R10G10B10A2_UINT = 25,
        DXGI_FORMAT_R11G11B10_FLOAT = 26,
        DXGI_FORMAT_R8G8B8A8_TYPELESS = 27,
        DXGI_FORMAT_R8G8B8A8_UNORM = 28,
        DXGI_FORMAT_R8G8B8A8_UNORM_SRGB = 29,
        DXGI_FORMAT_R8G8B8A8_UINT = 30,
        DXGI_FORMAT_R8G8B8A8_SNORM = 31,
        DXGI_FORMAT_R8G8B8A8_SINT = 32,
        DXGI_FORMAT_R16G16_TYPELESS = 33,
        DXGI_FORMAT_R16G16_FLOAT = 34,
        DXGI_FORMAT_R16G16_UNORM = 35,
        DXGI_FORMAT_R16G16_UINT = 36,
        DXGI_FORMAT_R16G16_SNORM = 37,
        DXGI_FORMAT_R16G16_SINT = 38,
        DXGI_FORMAT_R32_TYPELESS = 39,
        DXGI_FORMAT_D32_FLOAT = 40,
        DXGI_FORMAT_R32_FLOAT = 41,
        DXGI_FORMAT_R32_UINT = 42,
        DXGI_FORMAT_R32_SINT = 43,
        DXGI_FORMAT_R24G8_TYPELESS = 44,
        DXGI_FORMAT_D24_UNORM_S8_UINT = 45,
        DXGI_FORMAT_R24_UNORM_X8_TYPELESS = 46,
        DXGI_FORMAT_X24_TYPELESS_G8_UINT = 47,
        DXGI_FORMAT_R8G8_TYPELESS = 48,
        DXGI_FORMAT_R8G8_UNORM = 49,
        DXGI_FORMAT_R8G8_UINT = 50,
        DXGI_FORMAT_R8G8_SNORM = 51,
        DXGI_FORMAT_R8G8_SINT = 52,
        DXGI_FORMAT_R16_TYPELESS = 53,
        DXGI_FORMAT_R16_FLOAT = 54,
        DXGI_FORMAT_D16_UNORM = 55,
        DXGI_FORMAT_R16_UNORM = 56,
        DXGI_FORMAT_R16_UINT = 57,
        DXGI_FORMAT_R16_SNORM = 58,
        DXGI_FORMAT_R16_SINT = 59,
        DXGI_FORMAT_R8_TYPELESS = 60,
        DXGI_FORMAT_R8_UNORM = 61,
        DXGI_FORMAT_R8_UINT = 62,
        DXGI_FORMAT_R8_SNORM = 63,
        DXGI_FORMAT_R8_SINT = 64,
        DXGI_FORMAT_A8_UNORM = 65,
        DXGI_FORMAT_R1_UNORM = 66,
        DXGI_FORMAT_R9G9B9E5_SHAREDEXP = 67,
        DXGI_FORMAT_R8G8_B8G8_UNORM = 68,
        DXGI_FORMAT_G8R8_G8B8_UNORM = 69,
        DXGI_FORMAT_BC1_TYPELESS = 70,
        DXGI_FORMAT_BC1_UNORM = 71,
        DXGI_FORMAT_BC1_UNORM_SRGB = 72,
        DXGI_FORMAT_BC2_TYPELESS = 73,
        DXGI_FORMAT_BC2_UNORM = 74,
        DXGI_FORMAT_BC2_UNORM_SRGB = 75,
        DXGI_FORMAT_BC3_TYPELESS = 76,
        DXGI_FORMAT_BC3_UNORM = 77,
        DXGI_FORMAT_BC3_UNORM_SRGB = 78,
        DXGI_FORMAT_BC4_TYPELESS = 79,
        DXGI_FORMAT_BC4_UNORM = 80,
        DXGI_FORMAT_BC4_SNORM = 81,
        DXGI_FORMAT_BC5_TYPELESS = 82,
        DXGI_FORMAT_BC5_UNORM = 83,
        DXGI_FORMAT_BC5_SNORM = 84,
        DXGI_FORMAT_B5G6R5_UNORM = 85,
        DXGI_FORMAT_B5G5R5A1_UNORM = 86,
        DXGI_FORMAT_B8G8R8A8_UNORM = 87,
        DXGI_FORMAT_B8G8R8X8_UNORM = 88,
        DXGI_FORMAT_R10G10B10_XR_BIAS_A2_UNORM = 89,
        DXGI_FORMAT_B8G8R8A8_TYPELESS = 90,
        DXGI_FORMAT_B8G8R8A8_UNORM_SRGB = 91,
        DXGI_FORMAT_B8G8R8X8_TYPELESS = 92,
        DXGI_FORMAT_B8G8R8X8_UNORM_SRGB = 93,
        DXGI_FORMAT_BC6H_TYPELESS = 94,
        DXGI_FORMAT_BC6H_UF16 = 95,
        DXGI_FORMAT_BC6H_SF16 = 96,
        DXGI_FORMAT_BC7_TYPELESS = 97,
        DXGI_FORMAT_BC7_UNORM = 98,
        DXGI_FORMAT_BC7_UNORM_SRGB = 99,
        DXGI_FORMAT_AYUV = 100,
        DXGI_FORMAT_Y410 = 101,
        DXGI_FORMAT_Y416 = 102,
        DXGI_FORMAT_NV12 = 103,
        DXGI_FORMAT_P010 = 104,
        DXGI_FORMAT_P016 = 105,
        DXGI_FORMAT_420_OPAQUE = 106,
        DXGI_FORMAT_YUY2 = 107,
        DXGI_FORMAT_Y210 = 108,
        DXGI_FORMAT_Y216 = 109,
        DXGI_FORMAT_NV11 = 110,
        DXGI_FORMAT_AI44 = 111,
        DXGI_FORMAT_IA44 = 112,
        DXGI_FORMAT_P8 = 113,
        DXGI_FORMAT_A8P8 = 114,
        DXGI_FORMAT_B4G4R4A4_UNORM = 115,
        DXGI_FORMAT_P208 = 130,
        DXGI_FORMAT_V208 = 131,
        DXGI_FORMAT_V408 = 132,
    }

    public struct DDSHeaderDXT10
    {
        public DXGIFormat dxgiFormat;
        public ResourceDimension resourceDimension;
        public uint miscFlag;
        public uint arraySize;
        public uint miscFlags2;
    }


    class Program
    {
        static uint ReadUInt32(FileStream fs)
        {
            byte[] buffer = new byte[4];
            fs.Read(buffer, 0, 4);
            return (uint)(buffer[0] | (buffer[1] << 8) | (buffer[2] << 16) | (buffer[3] << 24));
        }

        static DDSPixelFormat ReadDDSPixelFormat(FileStream fs)
        {
            DDSPixelFormat pixelFormat;

            pixelFormat.size = ReadUInt32(fs);
            pixelFormat.flags = ReadUInt32(fs);
            pixelFormat.fourCC = ReadUInt32(fs);
            pixelFormat.rgbBitCount = ReadUInt32(fs);
            pixelFormat.rBitMask = ReadUInt32(fs);
            pixelFormat.gBitMask = ReadUInt32(fs);
            pixelFormat.bBitMask = ReadUInt32(fs);
            pixelFormat.aBitMask = ReadUInt32(fs);

            return pixelFormat;
        }

        static DDSHeader ReadDDSHeader(FileStream fs)
        {
            DDSHeader header;
            header.size = ReadUInt32(fs);
            header.flags = ReadUInt32(fs);
            header.height = ReadUInt32(fs);
            header.width = ReadUInt32(fs);
            header.pitchOrLinearSize = ReadUInt32(fs);
            header.depth = ReadUInt32(fs);
            header.mipMapCount = ReadUInt32(fs);
            fs.Seek(11 * 4, SeekOrigin.Current);
            header.pixelFormat = ReadDDSPixelFormat(fs);
            header.caps = ReadUInt32(fs);
            header.caps2 = ReadUInt32(fs);
            header.caps3 = ReadUInt32(fs);
            header.caps4 = ReadUInt32(fs);
            fs.Seek(4, SeekOrigin.Current);

            return header;
        }

        static DDSHeaderDXT10 ReadDDSHeader10(FileStream fs)
        {
            DDSHeaderDXT10 header;
            header.dxgiFormat = (DXGIFormat)ReadUInt32(fs);
            header.resourceDimension = (ResourceDimension)ReadUInt32(fs);
            header.miscFlag = ReadUInt32(fs);
            header.arraySize = ReadUInt32(fs);
            header.miscFlags2 = ReadUInt32(fs);

            return header;
        }

        public enum PBitMode
        {
            PerEndpoint,
            PerSubset,
            None,
        }

        public enum AlphaMode
        {
            None,
            Combined,
            Separate
        }


        public struct BC7Mode
        {
            public PBitMode pBitMode;
            public AlphaMode alphaMode;
            public uint rgbBits;
            public uint alphaBits;
            public uint partitionBits;
            public uint numSubsets;
            public uint indexBits;
            public uint alphaIndexBits;
            public bool hasIndexSelector;

            public BC7Mode(PBitMode pBitMode, AlphaMode alphaMode, uint rgbBits, uint alphaBits, uint partitionBits, uint numSubsets, uint indexBits, uint alphaIndexBits, bool hasIndexSelector)
            {
                this.pBitMode = pBitMode;
                this.alphaMode = alphaMode;
                this.rgbBits = rgbBits;
                this.alphaBits = alphaBits;
                this.partitionBits = partitionBits;
                this.numSubsets = numSubsets;
                this.indexBits = indexBits;
                this.alphaIndexBits = alphaIndexBits;
                this.hasIndexSelector = hasIndexSelector;
            }
        }

        static BC7Mode[] s_modes = new BC7Mode[]
        {
            new BC7Mode(PBitMode.PerEndpoint, AlphaMode.None, 4, 0, 4, 3, 3, 0, false),     // 0
            new BC7Mode(PBitMode.PerSubset, AlphaMode.None, 6, 0, 6, 2, 3, 0, false),       // 1
            new BC7Mode(PBitMode.None, AlphaMode.None, 5, 0, 6, 3, 2, 0, false),            // 2
            new BC7Mode(PBitMode.PerEndpoint, AlphaMode.None, 7, 0, 6, 2, 2, 0, false),     // 3 (Mode reference has an error, P-bit is really per-endpoint)

            new BC7Mode(PBitMode.None, AlphaMode.Separate, 5, 6, 0, 1, 2, 3, true),         // 4
            new BC7Mode(PBitMode.None, AlphaMode.Separate, 7, 8, 0, 1, 2, 2, false),        // 5
            new BC7Mode(PBitMode.PerEndpoint, AlphaMode.Combined, 7, 7, 0, 1, 4, 0, false), // 6
            new BC7Mode(PBitMode.PerEndpoint, AlphaMode.Combined, 5, 5, 6, 2, 2, 0, false)  // 7
        };


        static uint[] s_partitionMap2 = new uint[64]
        {
            0xCCCC, 0x8888, 0xEEEE, 0xECC8,
            0xC880, 0xFEEC, 0xFEC8, 0xEC80,
            0xC800, 0xFFEC, 0xFE80, 0xE800,
            0xFFE8, 0xFF00, 0xFFF0, 0xF000,
            0xF710, 0x008E, 0x7100, 0x08CE,
            0x008C, 0x7310, 0x3100, 0x8CCE,
            0x088C, 0x3110, 0x6666, 0x366C,
            0x17E8, 0x0FF0, 0x718E, 0x399C,
            0xaaaa, 0xf0f0, 0x5a5a, 0x33cc,
            0x3c3c, 0x55aa, 0x9696, 0xa55a,
            0x73ce, 0x13c8, 0x324c, 0x3bdc,
            0x6996, 0xc33c, 0x9966, 0x660,
            0x272, 0x4e4, 0x4e40, 0x2720,
            0xc936, 0x936c, 0x39c6, 0x639c,
            0x9336, 0x9cc6, 0x817e, 0xe718,
            0xccf0, 0xfcc, 0x7744, 0xee22,
        };

        static uint[] s_partitionMap3 = new uint[64]
        {
            0xaa685050, 0x6a5a5040, 0x5a5a4200, 0x5450a0a8,
            0xa5a50000, 0xa0a05050, 0x5555a0a0, 0x5a5a5050,
            0xaa550000, 0xaa555500, 0xaaaa5500, 0x90909090,
            0x94949494, 0xa4a4a4a4, 0xa9a59450, 0x2a0a4250,
            0xa5945040, 0x0a425054, 0xa5a5a500, 0x55a0a0a0,
            0xa8a85454, 0x6a6a4040, 0xa4a45000, 0x1a1a0500,
            0x0050a4a4, 0xaaa59090, 0x14696914, 0x69691400,
            0xa08585a0, 0xaa821414, 0x50a4a450, 0x6a5a0200,
            0xa9a58000, 0x5090a0a8, 0xa8a09050, 0x24242424,
            0x00aa5500, 0x24924924, 0x24499224, 0x50a50a50,
            0x500aa550, 0xaaaa4444, 0x66660000, 0xa5a0a5a0,
            0x50a050a0, 0x69286928, 0x44aaaa44, 0x66666600,
            0xaa444444, 0x54a854a8, 0x95809580, 0x96969600,
            0xa85454a8, 0x80959580, 0xaa141414, 0x96960000,
            0xaaaa1414, 0xa05050a0, 0xa0a5a5a0, 0x96000000,
            0x40804080, 0xa9a8a9a8, 0xaaaaaa44, 0x2a4a5254,
        };

        static uint[] s_fixupIndexes2 = new uint[64]
        {
            15,15,15,15,
            15,15,15,15,
            15,15,15,15,
            15,15,15,15,
            15, 2, 8, 2,
             2, 8, 8,15,
             2, 8, 2, 2,
             8, 8, 2, 2,

            15,15, 6, 8,
             2, 8,15,15,
             2, 8, 2, 2,
             2,15,15, 6,
             6, 2, 6, 8,
            15,15, 2, 2,
            15,15,15,15,
            15, 2, 2,15,
        };

        static uint[,] s_fixupIndexes3 = new uint[64,2]
        {
            { 3,15},{ 3, 8},{15, 8},{15, 3},
            { 8,15},{ 3,15},{15, 3},{15, 8},
            { 8,15},{ 8,15},{ 6,15},{ 6,15},
            { 6,15},{ 5,15},{ 3,15},{ 3, 8},
            { 3,15},{ 3, 8},{ 8,15},{15, 3},
            { 3,15},{ 3, 8},{ 6,15},{10, 8},
            { 5, 3},{ 8,15},{ 8, 6},{ 6,10},
            { 8,15},{ 5,15},{15,10},{15, 8},

            { 8,15},{15, 3},{ 3,15},{ 5,10},
            { 6,10},{10, 8},{ 8, 9},{15,10},
            {15, 6},{ 3,15},{15, 8},{ 5,15},
            {15, 3},{15, 6},{15, 6},{15, 8}, //The Spec doesn't mark the first fixed up index in this row, so I apply 15 for them, and seems correct
            { 3,15},{15, 3},{ 5,15},{ 5,15},
            { 5,15},{ 8,15},{ 5,15},{10,15},
            { 5,15},{10,15},{ 8,15},{13,15},
            {15, 3},{12,15},{ 3,15},{ 3, 8},
        };

        static uint[][] s_weight = new uint[5][]
        {
            new uint[0],
            new uint[0],
            new uint[4] { 0, 21, 43, 64 },
            new uint[8] { 0, 9, 18, 27, 37, 46, 55, 64 },
            new uint[16] {0,  4,  9, 13, 17, 21, 26, 30, 34, 38, 43, 47, 51, 55, 60, 64},
        };

        static uint Interpolate(uint a, uint b, uint bits, uint index)
        {

            uint weight = s_weight[bits][index];
            return ((64 - weight) * a + weight * b + 32) >> 6;
        }

        public class BlockParser
        {
            ulong low;
            ulong high;
            uint bitOffset;
            long pos;

            public BlockParser()
            {
                low = 0;
                high = 0;
                bitOffset = 0;
                pos = 0;
            }

            public void Read(FileStream fs)
            {
                pos = fs.Position;

                uint a = ReadUInt32(fs);
                uint b = ReadUInt32(fs);
                uint c = ReadUInt32(fs);
                uint d = ReadUInt32(fs);

                low = ((((ulong)b) << 32) | ((ulong)a));
                high = ((((ulong)d) << 32) | ((ulong)c));
            }

            public uint ReadBits(uint numBits)
            {
                return ReadBits((int)numBits);
            }

            public uint ReadBits(int numBits)
            {
                if (numBits == 0)
                    return 0;

                bitOffset += (uint)numBits;
                if (bitOffset > 128)
                    throw new Exception();

                uint mask = (0xffu >> (8 - numBits));
                uint result = (uint)(low & mask);

                low >>= numBits;
                low |= (high << (64 - numBits));
                high >>= numBits;

                return result;
            }

            public void End()
            {
                if (bitOffset != 128)
                    throw new Exception();

                bitOffset = 0;
            }
        }

        static uint UnquantizeEndpoint(uint ep, uint bits)
        {
            ep <<= (8 - (int)bits);
            ep |= (ep >> (int)bits);
            return ep;
        }

        static uint UnquantizeEndpoint(uint ep, uint bits, uint p)
        {
            return UnquantizeEndpoint((ep << 1) | p, bits + 1);
        }

        static void Swap<T>(ref T a, ref T b)
        {
            T temp = a;
            a = b;
            b = temp;
        }

        static void Main(string[] args)
        {
            using (FileStream inStream = new FileStream(args[0], FileMode.Open, FileAccess.Read))
            {
                uint magic = ReadUInt32(inStream);
                DDSHeader header = ReadDDSHeader(inStream);
                DDSHeaderDXT10 header10 = ReadDDSHeader10(inStream);

                uint width = header.width;
                uint height = header.height;

                uint debugLines = 17;
                uint debugCols = 20;

                // Debug block layout
                // Rows 0-2: Endpoints
                // Row 3: Mode, Partition, Rotation, Index Selector
                // Rows 4-7: Index 1
                // Rows 8-11: Index 2
                // Rows 12-15: Reconstructed

                BlockParser bp = new BlockParser();

                uint debugImageWidth = width / 4 * debugCols;
                uint debugImageHeight = height / 4 * debugLines;

                using (Bitmap bmp = new Bitmap((int)debugImageWidth, (int)debugImageHeight))
                {
                    for (uint y = 0; y < debugImageHeight; y++)
                        for (uint x = 0; x < debugImageWidth; x++)
                            bmp.SetPixel((int)x, (int)y, Color.Red);

                    for (uint y = 0; y < height; y += 4)
                    {
                        int iy = (int)(y / 4 * debugLines);

                        for (uint x = 0; x < width; x += 4)
                        {
                            int ix = (int)(x / 4 * debugCols);

                            bp.Read(inStream);

                            uint[,] endpoints = new uint[6,4];
                            uint[] pBits = new uint[6];

                            int modeID = 8;
                            for (int i = 0; i < 8; i++)
                            {
                                if (bp.ReadBits(1) == 1)
                                {
                                    modeID = i;
                                    break;
                                }
                            }

                            if (modeID == 8)
                                throw new Exception();

                            BC7Mode mode = s_modes[modeID];

                            uint partition = bp.ReadBits(mode.partitionBits);
                            uint rotation = (mode.alphaMode == AlphaMode.Separate) ? bp.ReadBits(2) : 0;
                            uint indexSelector = (mode.hasIndexSelector) ? bp.ReadBits(1) : 0;

                            for (uint c = 0; c < 3; c++)
                                for (uint i = 0; i < mode.numSubsets * 2; i++)
                                    endpoints[i, c] = bp.ReadBits(mode.rgbBits);

                            if (mode.alphaMode != AlphaMode.None)
                            {
                                for (uint i = 0; i < mode.numSubsets * 2; i++)
                                    endpoints[i, 3] = bp.ReadBits(mode.alphaBits);
                            }

                            if (mode.pBitMode == PBitMode.None)
                            {
                                for (uint i = 0; i < mode.numSubsets * 2; i++)
                                {
                                    for (uint c = 0; c < 3; c++)
                                        endpoints[i, c] = UnquantizeEndpoint(endpoints[i, c], mode.rgbBits);
                                    endpoints[i, 3] = UnquantizeEndpoint(endpoints[i, 3], mode.alphaBits);
                                }
                            }
                            else
                            {
                                for (uint i = 0; i < mode.numSubsets * 2; i += 2)
                                {
                                    uint pBit1 = bp.ReadBits(1);
                                    uint pBit2 = (mode.pBitMode == PBitMode.PerEndpoint) ? bp.ReadBits(1) : pBit1;

                                    for (uint c = 0; c < 3; c++)
                                    {
                                        endpoints[i, c] = UnquantizeEndpoint(endpoints[i, c], mode.rgbBits, pBit1);
                                        endpoints[i + 1, c] = UnquantizeEndpoint(endpoints[i + 1, c], mode.rgbBits, pBit2);
                                    }
                                    endpoints[i, 3] = UnquantizeEndpoint(endpoints[i, 3], mode.alphaBits, pBit1);
                                    endpoints[i + 1, 3] = UnquantizeEndpoint(endpoints[i + 1, 3], mode.alphaBits, pBit2);
                                }
                            }

                            if (mode.alphaMode == AlphaMode.None)
                            {
                                for (uint i = 0; i < mode.numSubsets * 2; i++)
                                    endpoints[i, 3] = 255;
                            }

                            uint[] rgbIndexes = new uint[16];
                            uint[] alphaIndexes = new uint[16];
                            uint[] subsets = new uint[16];
                            bool[] fixups = new bool[16];

                            for (int i = 0; i < 16; i++)
                            {
                                switch (mode.numSubsets)
                                {
                                    case 2:
                                        subsets[i] = (s_partitionMap2[partition] >> i) & 1;
                                        fixups[i] = (i == s_fixupIndexes2[partition]);
                                        break;

                                    case 3:
                                        subsets[i] = (s_partitionMap3[partition] >> (i * 2)) & 3;
                                        fixups[i] = (i == s_fixupIndexes3[partition, 0] || i == s_fixupIndexes3[partition, 1]);
                                        break;

                                    default:
                                        break;
                                }
                            }

                            fixups[0] = true;

                            for (int i = 0; i < 16; i++)
                            {
                                uint indexBits = mode.indexBits;
                                if (fixups[i])
                                    indexBits -= 1;
                                rgbIndexes[i] = bp.ReadBits(indexBits);
                            }

                            if (mode.alphaIndexBits != 0)
                            {
                                for (int i = 0; i < 16; i++)
                                {
                                    uint indexBits = mode.alphaIndexBits;
                                    if (fixups[i])
                                        indexBits -= 1;
                                    alphaIndexes[i] = bp.ReadBits(indexBits);
                                }
                            }

                            uint rgbIndexPrec = mode.indexBits;
                            uint alphaIndexPrec = mode.alphaIndexBits;

                            if (indexSelector == 1)
                            {
                                Swap<uint[]>(ref rgbIndexes, ref alphaIndexes);
                                Swap<uint>(ref rgbIndexPrec, ref alphaIndexPrec);
                            }

                            bp.End();

                            for (int i = 0; i < 3; i++)
                            {
                                int ep0r = (int)endpoints[i * 2, 0];
                                int ep0g = (int)endpoints[i * 2, 1];
                                int ep0b = (int)endpoints[i * 2, 2];
                                int ep0a = (int)endpoints[i * 2, 3];

                                int ep1r = (int)endpoints[i * 2 + 1, 0];
                                int ep1g = (int)endpoints[i * 2 + 1, 1];
                                int ep1b = (int)endpoints[i * 2 + 1, 2];
                                int ep1a = (int)endpoints[i * 2 + 1, 3];

                                if (rotation == 1)
                                {
                                    Swap<int>(ref ep0r, ref ep0a);
                                    Swap<int>(ref ep1r, ref ep1a);
                                }
                                else if (rotation == 2)
                                {
                                    Swap<int>(ref ep0g, ref ep0a);
                                    Swap<int>(ref ep1g, ref ep1a);
                                }
                                else if (rotation == 3)
                                {
                                    Swap<int>(ref ep0b, ref ep0a);
                                    Swap<int>(ref ep1b, ref ep1a);
                                }

                                Color ep0 = Color.FromArgb(ep0a, ep0r, ep0g, ep0b);
                                Color ep1 = Color.FromArgb(ep1a, ep1r, ep1g, ep1b);

                                bmp.SetPixel(ix, iy + i, ep0);
                                bmp.SetPixel(ix + 1, iy + i, ep1);

                                if (mode.alphaMode == AlphaMode.Separate)
                                {
                                }
                                else
                                {
                                    for (uint interp = 0; interp < (1 << (int)mode.indexBits); interp++)
                                    {
                                        uint ir = Interpolate((uint)ep0r, (uint)ep1r, mode.indexBits, interp);
                                        uint ig = Interpolate((uint)ep0g, (uint)ep1g, mode.indexBits, interp);
                                        uint ib = Interpolate((uint)ep0b, (uint)ep1b, mode.indexBits, interp);
                                        uint ia = Interpolate((uint)ep0a, (uint)ep1a, mode.indexBits, interp);


                                        bmp.SetPixel(ix + 3 + (int)interp, iy + i, Color.FromArgb((int)ia, (int)ir, (int)ig, (int)ib));
                                    }
                                }
                            }

                            bmp.SetPixel(ix + 0, iy + 3, Color.FromArgb((int)modeID * 0x10, (int)modeID * 0x10, (int)modeID * 0x10));
                            bmp.SetPixel(ix + 1, iy + 3, Color.FromArgb((int)partition * 4, (int)partition * 4, (int)partition * 4));

                            bmp.SetPixel(ix + 2, iy + 3, Color.FromArgb((int)(0xff000000 | (0xff000000 >> (8 * (int)rotation)))));
                            bmp.SetPixel(ix + 3, iy + 3, Color.FromArgb((int)(indexSelector == 1 ? 0xffffffff : 0xff000000)));

                            for (int i = 0; i < 16; i++)
                            {
                                int shiftedIndex = 0xf + ((int)rgbIndexes[i] << 4);

                                int offsetX = i % 4;
                                int offsetY = i / 4;

                                if (mode.numSubsets == 1)
                                    bmp.SetPixel(ix + offsetX, iy + offsetY + 4, Color.FromArgb(shiftedIndex, shiftedIndex, shiftedIndex));
                                else
                                {
                                    int r = (subsets[i] == 0) ? shiftedIndex : 0;
                                    int g = (subsets[i] == 1) ? shiftedIndex : 0;
                                    int b = (subsets[i] == 2) ? shiftedIndex : 0;

                                    bmp.SetPixel(ix + offsetX, iy + offsetY + 4, Color.FromArgb(r, g, b));
                                }
                            }

                            for (int i = 0; i < 16; i++)
                            {
                                int shiftedIndex = 0xf + ((int)alphaIndexes[i] << 4);

                                int offsetX = i % 4;
                                int offsetY = i / 4;

                                bmp.SetPixel(ix + offsetX, iy + offsetY + 8, Color.FromArgb(shiftedIndex, shiftedIndex, shiftedIndex));
                            }

                            // Rows 13-16: Reconstructed
                            for (int i = 0; i < 16; i++)
                            {
                                uint subset = subsets[i];

                                uint r = Interpolate(endpoints[subset * 2, 0], endpoints[subset * 2 + 1, 0], rgbIndexPrec, rgbIndexes[i]);
                                uint g = Interpolate(endpoints[subset * 2, 1], endpoints[subset * 2 + 1, 1], rgbIndexPrec, rgbIndexes[i]);
                                uint b = Interpolate(endpoints[subset * 2, 2], endpoints[subset * 2 + 1, 2], rgbIndexPrec, rgbIndexes[i]);
                                uint a = 255;

                                if (mode.alphaMode == AlphaMode.Combined)
                                    a = Interpolate(endpoints[subset * 2, 3], endpoints[subset * 2 + 1, 3], rgbIndexPrec, rgbIndexes[i]);

                                if (mode.alphaMode == AlphaMode.Separate)
                                    a = Interpolate(endpoints[subset * 2, 3], endpoints[subset * 2 + 1, 3], alphaIndexPrec, alphaIndexes[i]);

                                if (rotation == 1)
                                    Swap<uint>(ref r, ref a);
                                else if (rotation == 2)
                                    Swap<uint>(ref g, ref a);
                                else if (rotation == 3)
                                    Swap<uint>(ref b, ref a);

                                int offsetX = i % 4;
                                int offsetY = i / 4;

                                bmp.SetPixel(ix + offsetX, iy + offsetY + 12, Color.FromArgb((int)a, (int)r, (int)g, (int)b));
                            }
                        }
                    }

                    bmp.Save(args[1], System.Drawing.Imaging.ImageFormat.Png);
                }
            }
        }
    }
}
