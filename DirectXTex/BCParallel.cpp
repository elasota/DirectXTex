/*
    Based on codec from Convection Texture Tools
    Copyright (c) 2018 Eric Lasota

    Permission is hereby granted, free of charge, to any person obtaining
    a copy of this software and associated documentation files (the
    "Software"), to deal in the Software without restriction, including
    without limitation the rights to use, copy, modify, merge, publish,
    distribute, sublicense, and/or sell copies of the Software, and to
    permit persons to whom the Software is furnished to do so, subject
    to the following conditions:

    The above copyright notice and this permission notice shall be included
    in all copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
    OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
    MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
    IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
    CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
    TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
    SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

    -------------------------------------------------------------------------------------

    Copyright (c) Microsoft Corporation. All rights reserved.
    Licensed under the MIT License.

    http://go.microsoft.com/fwlink/?LinkId=248926
*/
#include "directxtexp.h"

#include "BC.h"
#include "../ConvectionKernels/ConvectionKernels.h"

static_assert(NUM_PARALLEL_BLOCKS == CVTT::NumParallelBlocks, "NUM_PARALLEL_BLOCKS and CVTT NumParallelBlocks should be the same");

using namespace DirectX;
using namespace DirectX::PackedVector;

static void PrepareInputBlockU8(CVTT::InputBlockU8 inputBlocks[CVTT::NumParallelBlocks], const XMVECTOR *&pColor)
{
    for (size_t block = 0; block < CVTT::NumParallelBlocks; block++)
    {
        CVTT::InputBlockU8& inputBlock = inputBlocks[block];

        for (size_t px = 0; px < NUM_PIXELS_PER_BLOCK; px++)
        {
            for (size_t ch = 0; ch < 4; ch++)
                inputBlock.m_pixels[px][ch] = static_cast<uint8_t>(std::floorf(std::max<float>(0.0f, std::min<float>(255.0f, floorf(XMVectorGetByIndex(*pColor, ch) * 255.0f + 0.5f)))));

            pColor++;
        }
    }
}

static void PrepareInputBlockS8(CVTT::InputBlockS8 inputBlocks[CVTT::NumParallelBlocks], const XMVECTOR *&pColor)
{
    for (size_t block = 0; block < CVTT::NumParallelBlocks; block++)
    {
        CVTT::InputBlockS8& inputBlock = inputBlocks[block];

        for (size_t px = 0; px < NUM_PIXELS_PER_BLOCK; px++)
        {
            for (size_t ch = 0; ch < 4; ch++)
                inputBlock.m_pixels[px][ch] = static_cast<uint8_t>(std::floorf(std::max<float>(-127.0f, std::min<float>(127.0f, floorf(XMVectorGetByIndex(*pColor, ch) * 254.0f - 126.5f)))));

            pColor++;
        }
    }
}

static void PrepareInputBlockF16(CVTT::InputBlockF16 inputBlocks[CVTT::NumParallelBlocks], const XMVECTOR *&pColor)
{
    for (size_t block = 0; block < CVTT::NumParallelBlocks; block++)
    {
        CVTT::InputBlockF16& inputBlock = inputBlocks[block];

        XMHALF4 packedHalfs[NUM_PIXELS_PER_BLOCK];

        for (size_t i = 0; i < NUM_PIXELS_PER_BLOCK; ++i)
            XMStoreHalf4(packedHalfs + i, *pColor++);

        memcpy(inputBlock.m_pixels, packedHalfs, NUM_PIXELS_PER_BLOCK * 8);
    }
}

static CVTT::Options GenerateCVTTOptions(const TexCompressOptions &options)
{
    CVTT::Options cvttOptions;
    cvttOptions.threshold = options.threshold;
    cvttOptions.redWeight = options.redWeight;
    cvttOptions.greenWeight = options.greenWeight;
    cvttOptions.blueWeight = options.blueWeight;
    cvttOptions.alphaWeight = options.alphaWeight;

    if (options.flags & BC_FLAGS_FORCE_BC7_MODE6)
        cvttOptions.flags &= ~(CVTT::Flags::BC7_EnablePartitioning);
    if (options.flags & BC_FLAGS_USE_3SUBSETS)
        cvttOptions.flags |= CVTT::Flags::BC7_Enable3Subsets;
    if (options.flags & BC_FLAGS_UNIFORM)
        cvttOptions.flags |= CVTT::Flags::Uniform;

    cvttOptions.flags |= CVTT::Flags::S3TC_Exhaustive;

    return cvttOptions;
}

_Use_decl_annotations_
void DirectX::D3DXEncodeBC7Parallel(uint8_t *pBC, const XMVECTOR *pColor, const TexCompressOptions &options)
{
    assert(pColor);
    assert(pBC);

    CVTT::InputBlockU8 inputBlocks[NUM_PARALLEL_BLOCKS];
    PrepareInputBlockU8(inputBlocks, pColor);
    CVTT::Kernels::EncodeBC7(pBC, inputBlocks, GenerateCVTTOptions(options));
}

_Use_decl_annotations_
void DirectX::D3DXEncodeBC6HUParallel(uint8_t *pBC, const XMVECTOR *pColor, const TexCompressOptions &options)
{
    assert(pColor);
    assert(pBC);

    CVTT::InputBlockF16 inputBlocks[NUM_PARALLEL_BLOCKS];
    PrepareInputBlockF16(inputBlocks, pColor);
    CVTT::Kernels::EncodeBC6HU(pBC, inputBlocks, GenerateCVTTOptions(options));
}

_Use_decl_annotations_
void DirectX::D3DXEncodeBC6HSParallel(uint8_t *pBC, const XMVECTOR *pColor, const TexCompressOptions &options)
{
    assert(pColor);
    assert(pBC);

    CVTT::InputBlockF16 inputBlocks[NUM_PARALLEL_BLOCKS];
    PrepareInputBlockF16(inputBlocks, pColor);
    CVTT::Kernels::EncodeBC6HS(pBC, inputBlocks, GenerateCVTTOptions(options));
}

_Use_decl_annotations_
void DirectX::D3DXEncodeBC1Parallel(uint8_t *pBC, const XMVECTOR *pColor, const TexCompressOptions &options)
{
    assert(pColor);
    assert(pBC);

    CVTT::InputBlockU8 inputBlocks[NUM_PARALLEL_BLOCKS];
    PrepareInputBlockU8(inputBlocks, pColor);
    CVTT::Kernels::EncodeBC1(pBC, inputBlocks, GenerateCVTTOptions(options));
}

_Use_decl_annotations_
void DirectX::D3DXEncodeBC2Parallel(uint8_t *pBC, const XMVECTOR *pColor, const TexCompressOptions &options)
{
    assert(pColor);
    assert(pBC);

    CVTT::InputBlockU8 inputBlocks[NUM_PARALLEL_BLOCKS];
    PrepareInputBlockU8(inputBlocks, pColor);
    CVTT::Kernels::EncodeBC2(pBC, inputBlocks, GenerateCVTTOptions(options));
}

_Use_decl_annotations_
void DirectX::D3DXEncodeBC3Parallel(uint8_t *pBC, const XMVECTOR *pColor, const TexCompressOptions &options)
{
    assert(pColor);
    assert(pBC);

    CVTT::InputBlockU8 inputBlocks[NUM_PARALLEL_BLOCKS];
    PrepareInputBlockU8(inputBlocks, pColor);
    CVTT::Kernels::EncodeBC3(pBC, inputBlocks, GenerateCVTTOptions(options));
}

void DirectX::D3DXEncodeBC4UParallel(uint8_t *pBC, const XMVECTOR *pColor, const TexCompressOptions &options)
{
    assert(pColor);
    assert(pBC);

    CVTT::InputBlockU8 inputBlocks[NUM_PARALLEL_BLOCKS];
    PrepareInputBlockU8(inputBlocks, pColor);
    CVTT::Kernels::EncodeBC4U(pBC, inputBlocks, GenerateCVTTOptions(options));
}

void DirectX::D3DXEncodeBC4SParallel(uint8_t *pBC, const XMVECTOR *pColor, const TexCompressOptions &options)
{
    assert(pColor);
    assert(pBC);

    CVTT::InputBlockS8 inputBlocks[NUM_PARALLEL_BLOCKS];
    PrepareInputBlockS8(inputBlocks, pColor);
    CVTT::Kernels::EncodeBC4S(pBC, inputBlocks, GenerateCVTTOptions(options));
}

void DirectX::D3DXEncodeBC5UParallel(uint8_t *pBC, const XMVECTOR *pColor, const TexCompressOptions &options)
{
    assert(pColor);
    assert(pBC);

    CVTT::InputBlockU8 inputBlocks[NUM_PARALLEL_BLOCKS];
    PrepareInputBlockU8(inputBlocks, pColor);
    CVTT::Kernels::EncodeBC5U(pBC, inputBlocks, GenerateCVTTOptions(options));
}


void DirectX::D3DXEncodeBC5SParallel(uint8_t *pBC, const XMVECTOR *pColor, const TexCompressOptions &options)
{
    assert(pColor);
    assert(pBC);

    CVTT::InputBlockS8 inputBlocks[NUM_PARALLEL_BLOCKS];
    PrepareInputBlockS8(inputBlocks, pColor);
    CVTT::Kernels::EncodeBC5S(pBC, inputBlocks, GenerateCVTTOptions(options));
}
