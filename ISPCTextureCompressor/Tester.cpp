#include <stdio.h>

#include "ispc_texcomp.h"
#include "../DirectXTex/DirectXTex.h"

#include "../stb_image/stb_image.h"

int main(int argc, const char** argv)
{
    if (argc != 3)
        return -1;

    int w, h, channels;

    stbi_uc* imageData = stbi_load(argv[1], &w, &h, &channels, 4);

    if (!imageData)
        return -1;

    size_t compressedSize = w * h;
    unsigned char* compressedBlocks = new unsigned char[compressedSize];

    bc7_enc_settings settings;
    GetProfile_alpha_slow(&settings);

    rgba_surface surface;
    surface.width = w;
    surface.height = h;
    surface.stride = w * 4;
    surface.ptr = imageData;

    CompressBlocksBC7(&surface, compressedBlocks, &settings);

    stbi_image_free(imageData);


    DirectX::Image image;
    image.format = DXGI_FORMAT_BC7_UNORM;
    image.width = w;
    image.height = h;
    image.rowPitch = 0;
    image.slicePitch = compressedSize;
    image.pixels = compressedBlocks;

    size_t outLen = strlen(argv[2]);
    wchar_t* outPathW = new wchar_t[outLen + 1];
    outPathW[outLen] = 0;
    for (size_t i = 0; i < outLen; i++)
        outPathW[i] = static_cast<wchar_t>(argv[2][i]);

    DirectX::SaveToDDSFile(image, 0, outPathW);
    
    delete[] outPathW;
    delete[] compressedBlocks;

    return 0;
}
