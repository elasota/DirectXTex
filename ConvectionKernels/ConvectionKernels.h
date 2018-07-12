#pragma once
#ifndef __CVTT_CONVECTION_KERNELS__
#define __CVTT_CONVECTION_KERNELS__

#include <stdint.h>

namespace CVTT
{
    namespace Flags
    {
        const uint32_t BC7_Use3Subsets      = 0x01;
        const uint32_t BC7_ForceMode6       = 0x02;
        const uint32_t S3TC_Exhaustive      = 0x04;
        const uint32_t Uniform              = 0x08;
        const uint32_t BC6H_FastIndexing    = 0x10;
    }

    const unsigned int NumParallelBlocks = 8;

    struct Options
    {
        uint32_t flags;
        float threshold;
        float redWeight;
        float greenWeight;
        float blueWeight;
        float alphaWeight;

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

    struct InputBlockU8
    {
        uint8_t m_pixels[16][4];
    };

    struct InputBlockS8
    {
        int8_t m_pixels[16][4];
    };

    struct InputBlockF16
    {
        int16_t m_pixels[16][4];
    };

    namespace Kernels
    {
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
