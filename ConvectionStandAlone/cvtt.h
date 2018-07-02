#pragma once
#ifndef __CONVECTION_TEXTURE_TOOLS_H__
#define __CONVECTION_TEXTURE_TOOLS_H__

#include <stdint.h>

namespace CVTT
{
	const uint32_t CVTT_FLAGS_BC7_FORCE_MODE6	= 0x0001;
	const uint32_t CVTT_FLAGS_BC7_USE_3SUBSETS	= 0x0002;
	const uint32_t CVTT_FLAGS_UNIFORM			= 0x0004;

	const uint32_t NUM_PARALLEL_BLOCKS = 8;
	const uint32_t NUM_PIXELS_PER_BLOCK = 16;

	struct TexCompressOptions
	{
		uint32_t flags;

		float redWeight;
		float greenWeight;
		float blueWeight;
		float alphaWeight;

		float alphaThreshold;

		TexCompressOptions()
			: flags(0)
			, alphaThreshold(0.5f)
			, redWeight(0.2125f / 0.7154f)
			, greenWeight(1.0f)
			, blueWeight(0.0721f / 0.7154f)
			, alphaWeight(1.0f)
		{
		}
	};

	void EncodeBC1(uint8_t *pBC, const uint8_t *pColor, const TexCompressOptions &options);
	void EncodeBC2(uint8_t *pBC, const uint8_t *pColor, const TexCompressOptions &options);
	void EncodeBC3(uint8_t *pBC, const uint8_t *pColor, const TexCompressOptions &options);
	void EncodeBC4U(uint8_t *pBC, const uint8_t *pColor, const TexCompressOptions &options);
	void EncodeBC4S(uint8_t *pBC, const int8_t *pColor, const TexCompressOptions &options);
	void EncodeBC5U(uint8_t *pBC, const uint8_t *pColor, const TexCompressOptions &options);
	void EncodeBC5S(uint8_t *pBC, const int8_t *pColor, const TexCompressOptions &options);
	void EncodeBC6HU(uint8_t *pBC, const int16_t *pColor, const TexCompressOptions &options);
	void EncodeBC6HS(uint8_t *pBC, const int16_t *pColor, const TexCompressOptions &options);
	void EncodeBC7(uint8_t *pBC, const uint8_t *pColor, const TexCompressOptions &options);
}

#endif
