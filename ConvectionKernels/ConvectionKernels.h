#pragma once
#ifndef __CVTT_CONVECTION_KERNELS__
#define __CVTT_CONVECTION_KERNELS__

#include <stdint.h>

namespace CVTT
{
    namespace Flags
    {
        const uint32_t BC7_Use3Subsets      = 0x01; // Enable modes 0 and 2 in BC7 encoding (slower, better quality)
        const uint32_t BC7_ForceMode6       = 0x02; // Use only mode 6 in BC7 encoding (faster, worse quality)
        const uint32_t S3TC_Exhaustive      = 0x04; // Exhaustive search RGB orderings when encoding BC1-BC3 (much slower, better quality)
        const uint32_t Uniform              = 0x08; // Uniform color channel importance
        const uint32_t BC6H_FastIndexing    = 0x10; // Use fast indexing in BC6H encoder (faster, worse quality)
    }

    const unsigned int NumParallelBlocks = 8;

    struct Options
    {
        uint32_t flags;     // Bitmask of CVTT::Flags values
        float threshold;    // Alpha test threshold for BC1
        float redWeight;    // Red channel importance
        float greenWeight;  // Green channel importance
        float blueWeight;   // Blue channel importance
        float alphaWeight;  // Alpha channel importance

        Options()
            : flags(0)
            , threshold(0.5f)
            , redWeight(0.2125f / 0.7154f)
            , greenWeight(1.0f)
            , blueWeight(0.0721f / 0.7154f)
            , alphaWeight(1.0f)
        {
        }
    };

    // RGBA input block for unsigned 8-bit formats
    struct InputBlockU8
    {
        uint8_t m_pixels[16][4];
    };

    // RGBA input block for signed 8-bit formats
    struct InputBlockS8
    {
        int8_t m_pixels[16][4];
    };

    // RGBA input block for half-precision float formats (bit-cast to int16_t)
    struct InputBlockF16
    {
        int16_t m_pixels[16][4];
    };

    namespace Kernels
    {
        // NOTE: All functions accept and output NumParallelBlocks blocks at once
        void EncodeBC1(uint8_t *pBC, const InputBlockU8 *pBlocks, const Options &options);
        void EncodeBC2(uint8_t *pBC, const InputBlockU8 *pBlocks, const Options &options);
        void EncodeBC3(uint8_t *pBC, const InputBlockU8 *pBlocks, const Options &options);
        void EncodeBC4U(uint8_t *pBC, const InputBlockU8 *pBlocks, const Options &options);
        void EncodeBC4S(uint8_t *pBC, const InputBlockS8 *pBlocks, const Options &options);
        void EncodeBC5U(uint8_t *pBC, const InputBlockU8 *pBlocks, const Options &options);
        void EncodeBC5S(uint8_t *pBC, const InputBlockS8 *pBlocks, const Options &options);
        void EncodeBC6HU(uint8_t *pBC, const InputBlockF16 *pBlocks, const Options &options);
        void EncodeBC6HS(uint8_t *pBC, const InputBlockF16 *pBlocks, const Options &options);
        void EncodeBC7(uint8_t *pBC, const InputBlockU8 *pBlocks, const Options &options);
    }
}

#endif
