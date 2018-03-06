/*
	DirectXTex BC7 HQ Mod
	Copyright 2018 Eric Lasota

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

	**************************************************************************

	Based on DirectXTex DirectCompute BC7 Compressor

	Copyright (c) Microsoft Corporation. All rights reserved.
	Licensed under the MIT License.

	**************************************************************************

	Contains portions of libsquish

	Copyright (c) 2006 Simon Brown                          si@sjbrown.co.uk

	Permission is hereby granted, free of charge, to any person obtaining
	a copy of this software and associated documentation files (the 
	"Software"), to	deal in the Software without restriction, including
	without limitation the rights to use, copy, modify, merge, publish,
	distribute, sublicense, and/or sell copies of the Software, and to 
	permit persons to whom the Software is furnished to do so, subject to 
	the following conditions:

	The above copyright notice and this permission notice shall be included
	in all copies or substantial portions of the Software.

	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
	OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF 
	MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
	IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY 
	CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, 
	TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE 
	SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

	**************************************************************************

	Contains portions of FasTC

	Copyright 2016 The University of North Carolina at Chapel Hill

	Licensed under the Apache License, Version 2.0 (the "License");
	you may not use this file except in compliance with the License.
	You may obtain a copy of the License at

	   http://www.apache.org/licenses/LICENSE-2.0

	Unless required by applicable law or agreed to in writing, software
	distributed under the License is distributed on an "AS IS" BASIS,
	WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
	See the License for the specific language governing permissions and
	limitations under the License.
*/


#pragma warning(disable:3557)	// Loop only executes for 1 iteration, forcing unroll

#define HQ
//#define DEBUG_INCLUDE_DEBUG_DATA

#include "BC7EncodeCommon.h"

//#define DEBUG_NEVER_FLIP_ENDPOINTS
//#define DEBUG_ALWAYS_FLIP_ENDPOINTS
//#define DEBUG_NEVER_USE_0
//#define DEBUG_NEVER_USE_1
//#define DEBUG_NEVER_USE_2
//#define DEBUG_NEVER_USE_3
//#define DEBUG_NEVER_USE_4
//#define DEBUG_NEVER_USE_5
//#define DEBUG_NEVER_USE_6
//#define DEBUG_NEVER_USE_7

//#define DEBUG_MUTE_PARTITION_0
//#define DEBUG_MUTE_PARTITION_1
//#define DEBUG_MUTE_PARTITION_2

//#define DEBUG_INDEX_MIN
//#define DEBUG_INDEX_MAX

//#define DEBUG_FORCE_ROTATION 3
//#define DEBUG_FORCE_INDEX_SELECTOR 1

//#define DEBUG_DUMP_METADATA

//#define DEBUG_DUMP_RECONSTRUCTED_PIXEL 4
//#define DUMP_RECONSTRUCTION_ERROR 4
//#define DEBUG_DUMP_DEBUG_DATA

//#define DEBUG_ALWAYS_REFINE

#define ENDPOINT_SELECTOR_PASSES 3

#define POWER_ITERATION_COUNT 8

#define NUM_REFINE_PASSES 2

#define WORK_DATA_STRIDE 7
#define WORK_DATA_EP_OFFSET_0 1
#define WORK_DATA_EP_OFFSET_1 3
#define WORK_DATA_EP_OFFSET_2 5

void CopyBlock(uint blockID)
{
	uint start = blockID * WORK_DATA_STRIDE;
	for( uint i = 0; i < WORK_DATA_STRIDE; ++i )
		g_OutBuff[start + i] = g_InBuff[start + i];
}

// Pass 1: Compute centroid
// Pass 2: Compute covariance
// Pass 3: Axis generation

struct EndpointSelectorRGBA
{
	float4 total;
	float4 ctr;
	float4 axis;
    float xx;
    float xy;
    float xz;
    float xw;
    float yy;
    float yz;
    float yw;
    float zz;
    float zw;
    float ww;
	float min_dist;
	float max_dist;
};

void ContributeEndpointSelector( inout EndpointSelectorRGBA es, int step, float4 pt, float weight )
{
    if( step == 0 )
	{
		es.total += weight;
		es.ctr += weight * pt;
	}
	else if( step == 1 )
	{
		float4 a = pt - es.ctr;
		float4 b = weight * a;
		es.xx += a.x*b.x;
		es.xy += a.x*b.y;
		es.xz += a.x*b.z;
		es.xw += a.x*b.w;
		es.yy += a.y*b.y;
		es.yz += a.y*b.z;
		es.yw += a.y*b.w;
		es.zz += a.z*b.z;
		es.zw += a.z*b.w;
		es.ww += a.w*b.w;
	}
	else if( step == 2 )
	{
		float dist = dot(pt - es.ctr, es.axis);
		es.min_dist = min(dist, es.min_dist);
		es.max_dist = max(dist, es.max_dist);
	}
}

void InitEndpointSelector( out EndpointSelectorRGBA es )
{
	es.total = float4(0.0, 0.0, 0.0, 0.0);
	es.ctr = float4(0.0, 0.0, 0.0, 0.0);
	es.axis = float4(0.0, 0.0, 0.0, 0.0);
	es.xx = 0.0;
	es.xy = 0.0;
	es.xz = 0.0;
	es.xw = 0.0;
	es.yy = 0.0;
	es.yz = 0.0;
	es.yw = 0.0;
	es.zz = 0.0;
	es.zw = 0.0;
	es.ww = 0.0;
	es.max_dist = -1000.0;
	es.min_dist = 1000.0;
}

void InitEndpointSelectorPass( inout EndpointSelectorRGBA es, int step )
{
	if( step == 0 )
	{
	}
	else if( step == 1 )
	{
		es.ctr /= max(es.total, float4(0.0001, 0.0001, 0.0001, 0.0001));
	}
	else if( step == 2 )
	{	
		float4 row0 = float4(es.xx, es.xy, es.xz, es.xw);
		float4 row1 = float4(es.xy, es.yy, es.yz, es.yw);
		float4 row2 = float4(es.xz, es.yz, es.zz, es.zw);
		float4 row3 = float4(es.xw, es.yw, es.zw, es.ww);

		float4 v = float4(1.0, 1.0, 1.0, 1.0);
		for( int i = 0; i < POWER_ITERATION_COUNT; ++i )
		{
			// matrix multiply
			float4 w = row0*v.x;
			w += row1*v.y;
			w += row2*v.z;
			w += row3*v.w;

			float a = max(w.x, max(w.y, max(w.z, w.w)));

			if( a != 0.0 )
				v = w / a;
		}
		if( any(v) )
			v = normalize(v);
		es.axis = v;
	}
}

void GetEndpoints( EndpointSelectorRGBA es, out uint2x4 ep )
{
	// TODO: Clip to the edge
	ep[0] = uint4(clamp(round(es.ctr + es.axis * es.min_dist), 0.0, 255.0));
	ep[1] = uint4(clamp(round(es.ctr + es.axis * es.max_dist), 0.0, 255.0));
}

struct EndpointSelectorRGB
{
	float3 total;
	float3 ctr;
	float3 axis;
    float xx;
    float xy;
    float xz;
    float yy;
    float yz;
    float zz;
	float min_dist;
	float max_dist;
};

void ContributeEndpointSelector( inout EndpointSelectorRGB es, int step, float3 pt, float weight )
{
    if( step == 0 )
	{
		es.total += weight;
		es.ctr += weight * pt;
	}
	else if( step == 1 )
	{
		float3 a = pt - es.ctr;
		float3 b = weight * a;
		es.xx += a.x*b.x;
		es.xy += a.x*b.y;
		es.xz += a.x*b.z;
		es.yy += a.y*b.y;
		es.yz += a.y*b.z;
		es.zz += a.z*b.z;
	}
	else if( step == 2 )
	{
		float dist = dot(pt - es.ctr, es.axis);
		es.min_dist = min(dist, es.min_dist);
		es.max_dist = max(dist, es.max_dist);
	}
}

void InitEndpointSelector( out EndpointSelectorRGB es )
{
	es.total = float3(0.0, 0.0, 0.0);
	es.ctr = float3(0.0, 0.0, 0.0);
	es.axis = float3(0.0, 0.0, 0.0);
	es.xx = 0.0;
	es.xy = 0.0;
	es.xz = 0.0;
	es.yy = 0.0;
	es.yz = 0.0;
	es.zz = 0.0;
	es.max_dist = -1000.0;
	es.min_dist = 1000.0;
}

void InitEndpointSelectorPass( inout EndpointSelectorRGB es, int step )
{
	if( step == 0 )
	{
	}
	else if( step == 1 )
	{
		es.ctr /= max(es.total, 0.0001);
	}
	else if( step == 2 )
	{
		float3 row0 = float3(es.xx, es.xy, es.xz);
		float3 row1 = float3(es.xy, es.yy, es.yz);
		float3 row2 = float3(es.xz, es.yz, es.zz);

		float3 v = float3(1.0, 1.0, 1.0);
		for( int i = 0; i < POWER_ITERATION_COUNT; ++i )
		{
			// matrix multiply
			float3 w = row0*v.x;
			w += row1*v.y;
			w += row2*v.z;

			float a = max(w.x, max(w.y, w.z));

			if( a != 0.0 )
				v = w / a;
		}
		if( any(v) )
			v = normalize(v);
		es.axis = v;
	}
}

void GetEndpoints( EndpointSelectorRGB es, out uint2x4 ep )
{
	// TODO: Clip to the edge
	ep[0] = uint4(clamp(round(es.ctr + es.axis * es.min_dist), 0.0, 255.0), 255);
	ep[1] = uint4(clamp(round(es.ctr + es.axis * es.max_dist), 0.0, 255.0), 255);
}

uint BitsForPrec(uint prec)
{
	if(prec == 0)
		return 4;

	if(prec == 1)
		return 3;

	if(prec == 2)
		return 2;

	return 0;
}

struct IndexSelectorA
{
	uint2 endPoint;
	uint prec;
	float maxValue;
	float origin;
	float axis;
};

void InitIndexSelector(out IndexSelectorA is, uint2x4 endPoint, uint prec)
{
	is.endPoint[0] = endPoint[0].a;
	is.endPoint[1] = endPoint[1].a;
	is.prec = prec;

	is.maxValue = float((1 << BitsForPrec(prec)) - 1);

	is.origin = float(is.endPoint[0]);

	float axis = float(is.endPoint[1]) - is.origin;
	float len_squared = axis * axis;

	if (len_squared == 0.0)
		is.axis = 0;
	else
		is.axis = (axis / len_squared) * is.maxValue;
}

uint SelectIndex(IndexSelectorA is, uint4 pixel)
{
	float dist = (float(pixel.a) - is.origin) * is.axis;
	return uint(clamp(dist + 0.5, 0.0, is.maxValue));
}

uint ReconstructIndex(IndexSelectorA is, uint index)
{
	uint weight = aWeight[is.prec][index];
    return ( ( 64 - weight ) * is.endPoint[0] + weight * is.endPoint[1] + 32 ) >> 6;
}

struct IndexSelectorRGB
{
	uint2x3 endPoint;
	uint prec;
	float maxValue;
	float3 origin;
	float3 axis;
};

void InitIndexSelector(out IndexSelectorRGB is, uint2x4 endPoint, uint prec)
{
	is.endPoint[0] = endPoint[0].rgb;
	is.endPoint[1] = endPoint[1].rgb;

	is.prec = prec;
	is.maxValue = float((1 << BitsForPrec(prec)) - 1);

	is.origin = float3(is.endPoint[0]);

	float3 axis = float3(is.endPoint[1]) - is.origin;
	float len_squared = dot(axis, axis);

	if (len_squared == 0.0)
		is.axis = float3(0.0, 0.0, 0.0);
	else
		is.axis = (axis / len_squared) * is.maxValue;
}

uint SelectIndex(IndexSelectorRGB is, uint4 pixel)
{
	float dist = dot(float3(pixel.rgb) - is.origin, is.axis);
	return uint(clamp(dist + 0.5, 0.0, is.maxValue));
}

uint3 ReconstructIndex(IndexSelectorRGB is, uint index)
{
	uint weight = aWeight[is.prec][index];
    return ( ( 64 - weight ) * is.endPoint[0] + weight * is.endPoint[1] + 32 ) >> 6;
}

struct IndexSelectorRGBA
{
	uint2x4 endPoint;
	uint prec;
	float maxValue;
	float4 origin;
	float4 axis;
};

void InitIndexSelector(out IndexSelectorRGBA is, uint2x4 endPoint, uint prec)
{
	is.endPoint = endPoint;

	is.prec = prec;
	is.maxValue = float((1 << BitsForPrec(prec)) - 1);

	is.origin = float4(is.endPoint[0]);

	float4 axis = float4(is.endPoint[1]) - is.origin;
	float len_squared = dot(axis, axis);

	if (len_squared == 0.0)
		is.axis = float4(0.0, 0.0, 0.0, 0.0);
	else
		is.axis = (axis / len_squared) * is.maxValue;
}

uint SelectIndex(IndexSelectorRGBA is, uint4 pixel)
{
	float dist = dot(float4(pixel) - is.origin, is.axis);
	return uint(clamp(dist + 0.5, 0.0, is.maxValue));
}

uint4 ReconstructIndex(IndexSelectorRGBA is, uint index)
{
	uint weight = aWeight[is.prec][index];
    return ( ( 64 - weight ) * is.endPoint[0] + weight * is.endPoint[1] + 32 ) >> 6;
}

#define MAX_BUCKETS 16

struct EndpointRefiner
{
	float4 total;
	float weightTotal;

	float asq;
	float bsq;
	float ab;
	float4 ax;
	float4 bx;

	float maxIndex;
};

void InitEndpointRefiner( out EndpointRefiner er, uint numIndexes )
{
	er.total = float4(0.0, 0.0, 0.0, 0.0);
	er.weightTotal = 1.0;
	er.maxIndex = numIndexes - 1;
	er.asq = 0.0;
	er.bsq = 0.0;
	er.ab = 0.0;
	er.ax = float4(0.0, 0.0, 0.0, 0.0);
	er.bx = float4(0.0, 0.0, 0.0, 0.0);
}

void ContributeEndpointRefiner(inout EndpointRefiner er, uint4 pixel, uint index, float weight)
{
	float4 x = float4(pixel);

	float b = float(index) / er.maxIndex;
	float a = 1.0 - b;

	er.asq += a * a * weight;
	er.bsq += b * b * weight;
	er.ab += a * b * weight;

	er.ax += x * a * weight;
	er.bx += x * b * weight;

	er.total += x;
	er.weightTotal += weight;		
}

void GetRefinedEndpoints(EndpointRefiner er, out uint2x4 endPoint)
{
	float4 p1;
	float4 p2;
	float f = (er.asq * er.bsq - er.ab * er.ab);

	if (f == 0.0)
	{
		if (er.weightTotal == 0.0)
			p1 = p2 = float4(0.0, 0.0, 0.0, 0.0);
		else
			p1 = p2 = er.total / er.weightTotal;
	}
	else
	{
		p1 = (er.ax * er.bsq - er.bx * er.ab) / f;
		p2 = (er.bx * er.asq - er.ax * er.ab) / f;
	}

	p1 = clamp(p1, 0.0, 255.0);
	p2 = clamp(p2, 0.0, 255.0);

	endPoint[0] = uint4(round(p1));
	endPoint[1] = uint4(round(p2));
}

[numthreads( THREAD_GROUP_SIZE, 1, 1 )]
void TryMode456CS( uint GI : SV_GroupIndex, uint3 groupID : SV_GroupID ) // mode 4 5 6 all have 1 subset per block, and fix-up index is always index 0
{
    // we process 4 BC blocks per thread group
    const uint MAX_USED_THREAD = 16;                                                // pixels in a BC (block compressed) block
    uint BLOCK_IN_GROUP = THREAD_GROUP_SIZE / MAX_USED_THREAD;                      // the number of BC blocks a thread group processes = 64 / 16 = 4
    uint blockInGroup = GI / MAX_USED_THREAD;                                       // what BC block this thread is on within this thread group
    uint blockID = g_start_block_id + groupID.x * BLOCK_IN_GROUP + blockInGroup;    // what global BC block this thread is on
    uint threadBase = blockInGroup * MAX_USED_THREAD;                               // the first id of the pixel in this BC block in this thread group
    uint threadInBlock = GI - threadBase;                                           // id of the pixel in this BC block

#ifndef REF_DEVICE
    if (blockID >= g_num_total_blocks)
    {
        return;
    }
#endif

    uint block_y = blockID / g_num_block_x;
    uint block_x = blockID - block_y * g_num_block_x;
    uint base_x = block_x * BLOCK_SIZE_X;
    uint base_y = block_y * BLOCK_SIZE_Y;
    if (threadInBlock < 16)
    {
        shared_temp[GI].pixel = clamp(uint4(g_Input.Load( uint3( base_x + threadInBlock % 4, base_y + threadInBlock / 4, 0 ) ) * 255), 0, 255);

        shared_temp[GI].endPoint_low = shared_temp[GI].pixel;
        shared_temp[GI].endPoint_high = shared_temp[GI].pixel;
    }
#ifdef REF_DEVICE
    GroupMemoryBarrierWithGroupSync();
#endif

    if (threadInBlock < 8)
    {
        shared_temp[GI].endPoint_low = min(shared_temp[GI].endPoint_low, shared_temp[GI + 8].endPoint_low);
        shared_temp[GI].endPoint_high = max(shared_temp[GI].endPoint_high, shared_temp[GI + 8].endPoint_high);
    }
#ifdef REF_DEVICE
    GroupMemoryBarrierWithGroupSync();
#endif
    if (threadInBlock < 4)
    {
        shared_temp[GI].endPoint_low = min(shared_temp[GI].endPoint_low, shared_temp[GI + 4].endPoint_low);
        shared_temp[GI].endPoint_high = max(shared_temp[GI].endPoint_high, shared_temp[GI + 4].endPoint_high);
    }
#ifdef REF_DEVICE
    GroupMemoryBarrierWithGroupSync();
#endif
    if (threadInBlock < 2)
    {
        shared_temp[GI].endPoint_low = min(shared_temp[GI].endPoint_low, shared_temp[GI + 2].endPoint_low);
        shared_temp[GI].endPoint_high = max(shared_temp[GI].endPoint_high, shared_temp[GI + 2].endPoint_high);
    }
#ifdef REF_DEVICE
    GroupMemoryBarrierWithGroupSync();
#endif
    if (threadInBlock < 1)
    {
        shared_temp[GI].endPoint_low = min(shared_temp[GI].endPoint_low, shared_temp[GI + 1].endPoint_low);
        shared_temp[GI].endPoint_high = max(shared_temp[GI].endPoint_high, shared_temp[GI + 1].endPoint_high);
    }
#ifdef REF_DEVICE
    GroupMemoryBarrierWithGroupSync();
#endif

    uint rotation = 0;

	uint4 rotationMask = float4(0.0, 0.0, 0.0, 0.0);

    if (threadInBlock < 12) // Try mode 4 5 in threads 0..11
    {
        if ((threadInBlock < 2) || (8 == threadInBlock))       // rotation = 0 in thread 0, 1
        {
            rotation = 0;
			rotationMask = uint4(0, 0, 0, 255);
        }
        else if ((threadInBlock < 4) || (9 == threadInBlock))  // rotation = 1 in thread 2, 3
        {
            rotation = 1;
			rotationMask = uint4(255, 0, 0, 0);
        }
        else if ((threadInBlock < 6) || (10 == threadInBlock)) // rotation = 2 in thread 4, 5
        {
            rotation = 2;
			rotationMask = uint4(0, 255, 0, 0);
        }
        else if ((threadInBlock < 8) || (11 == threadInBlock)) // rotation = 3 in thread 6, 7
        {
            rotation = 3;
			rotationMask = uint4(0, 0, 255, 0);
        }
	}
	
	EndpointSelectorRGBA es;
	InitEndpointSelector(es);
	for( int ep_pass = 0; ep_pass < ENDPOINT_SELECTOR_PASSES; ++ep_pass )
	{
		InitEndpointSelectorPass(es, ep_pass);
		for( int pxi = 0; pxi < 16; ++pxi )
			ContributeEndpointSelector(es, ep_pass, float4(max(rotationMask, shared_temp[threadBase + pxi].pixel)), 1.0);
	}
	
    uint2x4 endPoint;
	GetEndpoints(es, endPoint);

	// Insert pre-rotated alpha back into the endpoints
	uint4 invRotationMask = 255 - rotationMask;
	
	endPoint[0] = min(shared_temp[threadBase].endPoint_low, rotationMask) + min(endPoint[0], invRotationMask);
	endPoint[1] = min(shared_temp[threadBase].endPoint_high, rotationMask) + min(endPoint[1], invRotationMask);

    uint error = 0xFFFFFFFF;
    uint mode = 0;
    uint index_selector = 0;

    uint2 indexPrec;
    if (threadInBlock < 8) // all threads of threadInBlock < 8 will be working on trying out mode 4, since only mode 4 has index selector bit
    {
        if (0 == (threadInBlock & 1)) // thread 0, 2, 4, 6
        {
            //2 represents 2bit index precision; 1 represents 3bit index precision
            index_selector = 0;
            indexPrec = uint2( 2, 1 );
        }
        else                          // thread 1, 3, 5, 7
        {
            //2 represents 2bit index precision; 1 represents 3bit index precision
            index_selector = 1;
            indexPrec = uint2( 1, 2 );
        }
    }
    else
    {
         //2 represents 2bit index precision
        indexPrec = uint2( 2, 2 );
    }

	uint4 debugData = uint4(0,0,0,0);

	uint bestError = 0xFFFFFFFF;
	uint2x4 bestEndPoint = uint2x4(uint4(0, 0, 0, 0), uint4(0, 0, 0, 0));

    uint color_index;
    uint alpha_index;
    if (threadInBlock < 12) // Try mode 4 5 in threads 0..11
    {
        // mode 4 5 have component rotation		
        if (rotation == 1)
        {
            endPoint[0].ra = endPoint[0].ar;
            endPoint[1].ra = endPoint[1].ar;
        }
        else if (rotation == 2)
        {
            endPoint[0].ga = endPoint[0].ag;
            endPoint[1].ga = endPoint[1].ag;
        }
        else if (rotation == 3)
        {
            endPoint[0].ba = endPoint[0].ab;
            endPoint[1].ba = endPoint[1].ab;
        }

		if (threadInBlock < 8)  // try mode 4 in threads 0..7
		{
			// mode 4 thread distribution
			// Thread           0   1   2   3   4   5   6   7
			// Rotation         0   0   1   1   2   2   3   3
			// Index selector   0   1   0   1   0   1   0   1

			mode = 4;
		}
		else                    // try mode 5 in threads 8..11
		{
			// mode 5 thread distribution
			// Thread    8  9  10  11
			// Rotation  0  1   2   3

			mode = 5;
		}

		for ( uint refinePass = 0; refinePass <= NUM_REFINE_PASSES; refinePass++ )
		{
			if (mode == 4)
				compress_endpoints4( endPoint );
			else // if(mode == 5)
				compress_endpoints5( endPoint );

			IndexSelectorA alphaIndexSelector;
			IndexSelectorRGB rgbIndexSelector;

			InitIndexSelector(rgbIndexSelector, endPoint, indexPrec.x);
			InitIndexSelector(alphaIndexSelector, endPoint, indexPrec.y);

			EndpointRefiner er;
			InitEndpointRefiner(er, 1 << BitsForPrec(indexPrec.x));

			error = 0;
			for ( uint i = 0; i < 16; i ++ )
			{
				uint4 pixel = shared_temp[threadBase + i].pixel;
				if (1 == rotation)
				{
					pixel.ra = pixel.ar;
				}
				else if (2 == rotation)
				{
					pixel.ga = pixel.ag;
				}
				else if (3 == rotation)
				{
					pixel.ba = pixel.ab;
				}

				color_index = SelectIndex(rgbIndexSelector, pixel);
				alpha_index = SelectIndex(alphaIndexSelector, pixel);

				ContributeEndpointRefiner(er, uint4(pixel.rgb, 255), color_index, 1.0);

				uint4 pixel_r;
				pixel_r.rgb = ReconstructIndex(rgbIndexSelector, color_index);
				pixel_r.a = ReconstructIndex(alphaIndexSelector, alpha_index);

				Ensure_A_Is_Larger( pixel_r, pixel );
				pixel_r -= pixel;
				if (1 == rotation)
				{
					pixel_r.ra = pixel_r.ar;
				}
				else if (2 == rotation)
				{
					pixel_r.ga = pixel_r.ag;
				}
				else if (3 == rotation)
				{
					pixel_r.ba = pixel_r.ab;
				}

				error += ComputeError(pixel_r, pixel_r);
			}

#ifdef DEBUG_ALWAYS_REFINE
			bestError = 0xffffffff;
#endif
			if (error < bestError)
			{
				bestError = error;
				bestEndPoint = endPoint;
			}

			if (refinePass != NUM_REFINE_PASSES)
			{
				uint2x4 refinedEP;
				GetRefinedEndpoints(er, refinedEP);
				endPoint[0].rgb = refinedEP[0].rgb;
				endPoint[1].rgb = refinedEP[1].rgb;
			}
		}

#ifdef DEBUG_FORCE_ROTATION
		if (rotation != DEBUG_FORCE_ROTATION)
			error = 0xffffffff;
#endif
    }
    else if (threadInBlock < 16) // Try mode 6 in threads 12..15, since in mode 4 5 6, only mode 6 has p bit
    {
        uint p = threadInBlock - 12;

		for ( uint refinePass = 0; refinePass <= NUM_REFINE_PASSES; refinePass++ )
		{
			EndpointRefiner er;
			InitEndpointRefiner(er, 16);  //InitEndpointRefiner(er, 1 << BitsForPrec(INDEX_PREC_4));

			compress_endpoints6( endPoint, uint2(p >> 0, p >> 1) & 1 );

			IndexSelectorRGBA indexSelector;
			InitIndexSelector(indexSelector, endPoint, INDEX_PREC_4);

			error = 0;
			for ( uint i = 0; i < 16; i ++ )
			{
				uint4 pixel = shared_temp[threadBase + i].pixel;

				uint color_index = SelectIndex(indexSelector, pixel);
				
				ContributeEndpointRefiner(er, pixel, color_index, 1.0);

				uint4 pixel_r = ReconstructIndex(indexSelector, color_index);
			
				Ensure_A_Is_Larger( pixel_r, pixel );
				pixel_r -= pixel;
				error += ComputeError(pixel_r, pixel_r);
			}

#ifdef DEBUG_ALWAYS_REFINE
			bestError = 0xffffffff;
#endif
			if (error < bestError)
			{
				bestError = error;
				bestEndPoint = endPoint;
			}

			endPoint[0] = uint4(0, 0, 0, 0);
			endPoint[1] = uint4(0, 0, 0, 0);
			if (refinePass != NUM_REFINE_PASSES)
			{
				uint2x4 refinedEP;
				GetRefinedEndpoints(er, refinedEP);
				endPoint[0].rgb = refinedEP[0].rgb;
				endPoint[1].rgb = refinedEP[1].rgb;
			}
		}

        mode = 6;
        rotation = p;    // Borrow rotation for p
    }

#ifdef DEBUG_NEVER_USE_4
	if (mode == 4)
		bestError = 0xffffffff;
#endif
#ifdef DEBUG_NEVER_USE_5
	if (mode == 5)
		bestError = 0xffffffff;
#endif
#ifdef DEBUG_NEVER_USE_6
	if (mode == 6)
		bestError = 0xffffffff;
#endif

#ifdef DEBUG_FORCE_INDEX_SELECTOR
	if (index_selector != DEBUG_FORCE_INDEX_SELECTOR)
		bestError = 0xffffffff;
#endif

    shared_temp[GI].error = bestError;
    shared_temp[GI].mode = mode;
    shared_temp[GI].index_selector = index_selector;
    shared_temp[GI].rotation = rotation;
	shared_temp[GI].endPoint_low = bestEndPoint[0];
	shared_temp[GI].endPoint_high = bestEndPoint[1];
#ifdef DEBUG_INCLUDE_DEBUG_DATA
	shared_temp[GI].debugData = debugData;
#endif
	
#ifdef REF_DEVICE
    GroupMemoryBarrierWithGroupSync();
#endif

    if (threadInBlock < 8)
    {
        if ( shared_temp[GI].error > shared_temp[GI + 8].error )
        {
            shared_temp[GI].error = shared_temp[GI + 8].error;
            shared_temp[GI].mode = shared_temp[GI + 8].mode;
            shared_temp[GI].index_selector = shared_temp[GI + 8].index_selector;
            shared_temp[GI].rotation = shared_temp[GI + 8].rotation;
			shared_temp[GI].endPoint_low = shared_temp[GI + 8].endPoint_low;
			shared_temp[GI].endPoint_high = shared_temp[GI + 8].endPoint_high;
#ifdef DEBUG_INCLUDE_DEBUG_DATA
			shared_temp[GI].debugData = shared_temp[GI + 8].debugData;
#endif
        }
    }
#ifdef REF_DEVICE
    GroupMemoryBarrierWithGroupSync();
#endif
    if (threadInBlock < 4)
    {
        if ( shared_temp[GI].error > shared_temp[GI + 4].error )
        {
            shared_temp[GI].error = shared_temp[GI + 4].error;
            shared_temp[GI].mode = shared_temp[GI + 4].mode;
            shared_temp[GI].index_selector = shared_temp[GI + 4].index_selector;
            shared_temp[GI].rotation = shared_temp[GI + 4].rotation;
			shared_temp[GI].endPoint_low = shared_temp[GI + 4].endPoint_low;
			shared_temp[GI].endPoint_high = shared_temp[GI + 4].endPoint_high;
#ifdef DEBUG_INCLUDE_DEBUG_DATA
			shared_temp[GI].debugData = shared_temp[GI + 4].debugData;
#endif
        }
    }
#ifdef REF_DEVICE
    GroupMemoryBarrierWithGroupSync();
#endif
    if (threadInBlock < 2)
    {
        if ( shared_temp[GI].error > shared_temp[GI + 2].error )
        {
            shared_temp[GI].error = shared_temp[GI + 2].error;
            shared_temp[GI].mode = shared_temp[GI + 2].mode;
            shared_temp[GI].index_selector = shared_temp[GI + 2].index_selector;
            shared_temp[GI].rotation = shared_temp[GI + 2].rotation;
			shared_temp[GI].endPoint_low = shared_temp[GI + 2].endPoint_low;
			shared_temp[GI].endPoint_high = shared_temp[GI + 2].endPoint_high;
#ifdef DEBUG_INCLUDE_DEBUG_DATA
			shared_temp[GI].debugData = shared_temp[GI + 2].debugData;
#endif
        }
    }
#ifdef REF_DEVICE
    GroupMemoryBarrierWithGroupSync();
#endif
    if (threadInBlock < 1)
    {
        if ( shared_temp[GI].error > shared_temp[GI + 1].error )
        {
            shared_temp[GI].error = shared_temp[GI + 1].error;
            shared_temp[GI].mode = shared_temp[GI + 1].mode;
            shared_temp[GI].index_selector = shared_temp[GI + 1].index_selector;
            shared_temp[GI].rotation = shared_temp[GI + 1].rotation;
			shared_temp[GI].endPoint_low = shared_temp[GI + 1].endPoint_low;
			shared_temp[GI].endPoint_high = shared_temp[GI + 1].endPoint_high;
#ifdef DEBUG_INCLUDE_DEBUG_DATA
			shared_temp[GI].debugData = shared_temp[GI + 1].debugData;
#endif
        }

		uint dataStart = blockID * WORK_DATA_STRIDE;

#ifdef DEBUG_DUMP_DEBUG_DATA
		g_OutBuff[dataStart] = shared_temp[GI].debugData;
#else
        g_OutBuff[dataStart] = uint4(shared_temp[GI].error, (shared_temp[GI].index_selector << 31) | shared_temp[GI].mode,
            0, shared_temp[GI].rotation); // rotation is indeed rotation for mode 4 5. for mode 6, rotation is p bit
#endif

		g_OutBuff[dataStart + WORK_DATA_EP_OFFSET_0] = shared_temp[GI].endPoint_low;
		g_OutBuff[dataStart + WORK_DATA_EP_OFFSET_0 + 1] = shared_temp[GI].endPoint_high;
    }
}

[numthreads( THREAD_GROUP_SIZE, 1, 1 )]
void TryMode137CS( uint GI : SV_GroupIndex, uint3 groupID : SV_GroupID ) // mode 1 3 7 all have 2 subsets per block
{
    const uint MAX_USED_THREAD = 64;
    uint BLOCK_IN_GROUP = THREAD_GROUP_SIZE / MAX_USED_THREAD;
    uint blockInGroup = GI / MAX_USED_THREAD;
    uint blockID = g_start_block_id + groupID.x * BLOCK_IN_GROUP + blockInGroup;
    uint threadBase = blockInGroup * MAX_USED_THREAD;
    uint threadInBlock = GI - threadBase;

    uint block_y = blockID / g_num_block_x;
    uint block_x = blockID - block_y * g_num_block_x;
    uint base_x = block_x * BLOCK_SIZE_X;
    uint base_y = block_y * BLOCK_SIZE_Y;
    
    if (threadInBlock < 16)
    {
        shared_temp[GI].pixel = clamp(uint4(g_Input.Load( uint3( base_x + threadInBlock % 4, base_y + threadInBlock / 4, 0 ) ) * 255), 0, 255);
    }
    GroupMemoryBarrierWithGroupSync();

    shared_temp[GI].error = 0xFFFFFFFF;

	uint step_selector;
	if (g_mode_id != 1)
		step_selector = INDEX_PREC_2;  // mode 3 7 have 2 bit index
	else
		step_selector = INDEX_PREC_3;  // mode 1 has 3 bit index

    uint2x4 endPoint[2];        // endPoint[0..1 for subset id][0..1 for low and high in the subset]
    uint2x4 endPointBackup[2];
    uint color_index;
    if (threadInBlock < 64)
    {
        uint partition = threadInBlock;
		uint4 debugData = uint4(0,0,0,0);

        uint bits = candidateSectionBit[partition];

		EndpointSelectorRGBA es[2];
		InitEndpointSelector(es[0]);
		InitEndpointSelector(es[1]);
		
		for( int ep_pass = 0; ep_pass < ENDPOINT_SELECTOR_PASSES; ++ep_pass )
		{
			InitEndpointSelectorPass(es[0], ep_pass);
			InitEndpointSelectorPass(es[1], ep_pass);
			for( int pxi = 0; pxi < 16; ++pxi )
			{
				uint4 pixel = shared_temp[threadBase + pxi].pixel;
				if (g_mode_id != 7)
					pixel.a = 255;

				if ( (( bits >> pxi ) & 0x01) == 1 )
					ContributeEndpointSelector(es[1], ep_pass, float4(pixel), 1.0);
				else
					ContributeEndpointSelector(es[0], ep_pass, float4(pixel), 1.0);
			}
		}
	
		GetEndpoints(es[0], endPoint[0]);
		GetEndpoints(es[1], endPoint[1]);

        endPointBackup[0] = endPoint[0];
        endPointBackup[1] = endPoint[1];

        uint max_p;
        if (1 == g_mode_id)
        {
            // in mode 1, there is only one p bit per subset
            max_p = 4;
        }
        else
        {
            // in mode 3 7, there are two p bits per subset, one for each end point
            max_p = 16;
        }

        uint rotation = 0;
        uint error = MAX_UINT;
		uint2x4 bestEndPoint[2];
		bestEndPoint[0] = uint2x4(uint4(0, 0, 0, 0), uint4(0, 0, 0, 0));
		bestEndPoint[1] = uint2x4(uint4(0, 0, 0, 0), uint4(0, 0, 0, 0));

        for ( uint p = 0; p < max_p; p ++ )
        {
            endPoint[0] = endPointBackup[0];
            endPoint[1] = endPointBackup[1];

			for (uint refinePass = 0; refinePass <= NUM_REFINE_PASSES; refinePass++)
			{
				for ( int i = 0; i < 2; i ++ ) // loop through 2 subsets
				{
					if (g_mode_id == 1)
					{
						compress_endpoints1( endPoint[i], (p >> i) & 1 );
					}
					else if (g_mode_id == 3)
					{
						compress_endpoints3( endPoint[i], uint2(p >> (i * 2 + 0), p >> (i * 2 + 1)) & 1 );
					}
					else if (g_mode_id == 7)
					{
						compress_endpoints7( endPoint[i], uint2(p >> (i * 2 + 0), p >> (i * 2 + 1)) & 1 );
					}
				}
			
				IndexSelectorRGBA indexSelectors[2];
				for ( i = 0; i < 2; ++i )
					InitIndexSelector(indexSelectors[i], endPoint[i], step_selector);

				EndpointRefiner er[2];
				InitEndpointRefiner(er[0], 1 << BitsForPrec(step_selector));
				InitEndpointRefiner(er[1], 1 << BitsForPrec(step_selector));

				uint p_error = 0;            
				for ( i = 0; i < 16; i ++ )
				{
					uint subset_index = (bits >> i) & 0x01;
					uint4 pixel_r;
					uint4 pixel = shared_temp[threadBase + i].pixel;

					if (subset_index == 1)
					{
						color_index = SelectIndex(indexSelectors[1], shared_temp[threadBase + i].pixel);
						pixel_r = ReconstructIndex(indexSelectors[1], color_index);
						ContributeEndpointRefiner(er[1], pixel, color_index, 1.0);
					}
					else
					{
						color_index = SelectIndex(indexSelectors[0], shared_temp[threadBase + i].pixel);
						pixel_r = ReconstructIndex(indexSelectors[0], color_index);
						ContributeEndpointRefiner(er[0], pixel, color_index, 1.0);
					}

					Ensure_A_Is_Larger( pixel_r, pixel );
					pixel_r -= pixel;
					p_error += ComputeError(pixel_r, pixel_r);
				}

				if (p_error < error)
				{
					error = p_error;
					rotation = p;
					bestEndPoint[0] = endPoint[0];
					bestEndPoint[1] = endPoint[1];
				}
				
				if (refinePass != NUM_REFINE_PASSES)
				{
					GetRefinedEndpoints(er[0], endPoint[0]);
					GetRefinedEndpoints(er[1], endPoint[1]);
				}
			}
        }

#ifdef DEBUG_NEVER_USE_1
		if (g_mode_id == 1)
			error = 0xffffffff;
#endif
#ifdef DEBUG_NEVER_USE_3
		if (g_mode_id == 3)
			error = 0xffffffff;
#endif
#ifdef DEBUG_NEVER_USE_7
		if (g_mode_id == 7)
			error = 0xffffffff;
#endif

        shared_temp[GI].error = error;
        shared_temp[GI].mode = g_mode_id;
        shared_temp[GI].partition = partition;
        shared_temp[GI].rotation = rotation; // mode 1 3 7 don't have rotation, we use rotation for p bits
        shared_temp[GI].endPoint_low = bestEndPoint[0][0];
        shared_temp[GI].endPoint_high = bestEndPoint[0][1];
        shared_temp[GI].endPoint1_low = bestEndPoint[1][0];
        shared_temp[GI].endPoint1_high = bestEndPoint[1][1];
#ifdef DEBUG_INCLUDE_DEBUG_DATA
		shared_temp[GI].debugData = debugData;
#endif
    }
    GroupMemoryBarrierWithGroupSync();

    if (threadInBlock < 32)
    {
        if ( shared_temp[GI].error > shared_temp[GI + 32].error )
        {
            shared_temp[GI].error = shared_temp[GI + 32].error;
            shared_temp[GI].mode = shared_temp[GI + 32].mode;
            shared_temp[GI].partition = shared_temp[GI + 32].partition;
            shared_temp[GI].rotation = shared_temp[GI + 32].rotation;
            shared_temp[GI].endPoint_low = shared_temp[GI + 32].endPoint_low;
            shared_temp[GI].endPoint_high = shared_temp[GI + 32].endPoint_high;
            shared_temp[GI].endPoint1_low = shared_temp[GI + 32].endPoint1_low;
            shared_temp[GI].endPoint1_high = shared_temp[GI + 32].endPoint1_high;
        }
    }
#ifdef REF_DEVICE
    GroupMemoryBarrierWithGroupSync();
#endif
if (threadInBlock < 16)
    {
        if ( shared_temp[GI].error > shared_temp[GI + 16].error )
        {
            shared_temp[GI].error = shared_temp[GI + 16].error;
            shared_temp[GI].mode = shared_temp[GI + 16].mode;
            shared_temp[GI].partition = shared_temp[GI + 16].partition;
            shared_temp[GI].rotation = shared_temp[GI + 16].rotation;
            shared_temp[GI].endPoint_low = shared_temp[GI + 16].endPoint_low;
            shared_temp[GI].endPoint_high = shared_temp[GI + 16].endPoint_high;
            shared_temp[GI].endPoint1_low = shared_temp[GI + 16].endPoint1_low;
            shared_temp[GI].endPoint1_high = shared_temp[GI + 16].endPoint1_high;
#ifdef DEBUG_INCLUDE_DEBUG_DATA
			shared_temp[GI].debugData = shared_temp[GI + 16].debugData;
#endif
        }
    }
#ifdef REF_DEVICE
    GroupMemoryBarrierWithGroupSync();
#endif
    if (threadInBlock < 8)
    {
        if ( shared_temp[GI].error > shared_temp[GI + 8].error )
        {
            shared_temp[GI].error = shared_temp[GI + 8].error;
            shared_temp[GI].mode = shared_temp[GI + 8].mode;
            shared_temp[GI].partition = shared_temp[GI + 8].partition;
            shared_temp[GI].rotation = shared_temp[GI + 8].rotation;
            shared_temp[GI].endPoint_low = shared_temp[GI + 8].endPoint_low;
            shared_temp[GI].endPoint_high = shared_temp[GI + 8].endPoint_high;
            shared_temp[GI].endPoint1_low = shared_temp[GI + 8].endPoint1_low;
            shared_temp[GI].endPoint1_high = shared_temp[GI + 8].endPoint1_high;
#ifdef DEBUG_INCLUDE_DEBUG_DATA
			shared_temp[GI].debugData = shared_temp[GI + 8].debugData;
#endif
        }
    }
#ifdef REF_DEVICE
    GroupMemoryBarrierWithGroupSync();
#endif
    if (threadInBlock < 4)
    {
        if ( shared_temp[GI].error > shared_temp[GI + 4].error )
        {
            shared_temp[GI].error = shared_temp[GI + 4].error;
            shared_temp[GI].mode = shared_temp[GI + 4].mode;
            shared_temp[GI].partition = shared_temp[GI + 4].partition;
            shared_temp[GI].rotation = shared_temp[GI + 4].rotation;
            shared_temp[GI].endPoint_low = shared_temp[GI + 4].endPoint_low;
            shared_temp[GI].endPoint_high = shared_temp[GI + 4].endPoint_high;
            shared_temp[GI].endPoint1_low = shared_temp[GI + 4].endPoint1_low;
            shared_temp[GI].endPoint1_high = shared_temp[GI + 4].endPoint1_high;
#ifdef DEBUG_INCLUDE_DEBUG_DATA
			shared_temp[GI].debugData = shared_temp[GI + 4].debugData;
#endif
        }
    }
#ifdef REF_DEVICE
    GroupMemoryBarrierWithGroupSync();
#endif
    if (threadInBlock < 2)
    {
        if ( shared_temp[GI].error > shared_temp[GI + 2].error )
        {
            shared_temp[GI].error = shared_temp[GI + 2].error;
            shared_temp[GI].mode = shared_temp[GI + 2].mode;
            shared_temp[GI].partition = shared_temp[GI + 2].partition;
            shared_temp[GI].rotation = shared_temp[GI + 2].rotation;
            shared_temp[GI].endPoint_low = shared_temp[GI + 2].endPoint_low;
            shared_temp[GI].endPoint_high = shared_temp[GI + 2].endPoint_high;
            shared_temp[GI].endPoint1_low = shared_temp[GI + 2].endPoint1_low;
            shared_temp[GI].endPoint1_high = shared_temp[GI + 2].endPoint1_high;
#ifdef DEBUG_INCLUDE_DEBUG_DATA
			shared_temp[GI].debugData = shared_temp[GI + 2].debugData;
#endif
        }
    }
#ifdef REF_DEVICE
    GroupMemoryBarrierWithGroupSync();
#endif

    if (threadInBlock < 1)
    {
        if ( shared_temp[GI].error > shared_temp[GI + 1].error )
        {
            shared_temp[GI].error = shared_temp[GI + 1].error;
            shared_temp[GI].mode = shared_temp[GI + 1].mode;
            shared_temp[GI].partition = shared_temp[GI + 1].partition;
            shared_temp[GI].rotation = shared_temp[GI + 1].rotation;
            shared_temp[GI].endPoint_low = shared_temp[GI + 1].endPoint_low;
            shared_temp[GI].endPoint_high = shared_temp[GI + 1].endPoint_high;
            shared_temp[GI].endPoint1_low = shared_temp[GI + 1].endPoint1_low;
            shared_temp[GI].endPoint1_high = shared_temp[GI + 1].endPoint1_high;
#ifdef DEBUG_INCLUDE_DEBUG_DATA
			shared_temp[GI].debugData = shared_temp[GI + 1].debugData;
#endif
        }

		uint dataStart = blockID * WORK_DATA_STRIDE;
        if (g_InBuff[dataStart].x > shared_temp[GI].error)
        {
#ifdef DEBUG_DUMP_DEBUG_DATA
			g_OutBuff[dataStart] = shared_temp[GI].debugData;
#else
            g_OutBuff[dataStart] = uint4(shared_temp[GI].error, shared_temp[GI].mode, shared_temp[GI].partition, shared_temp[GI].rotation); // mode 1 3 7 don't have rotation, we use rotation for p bits
#endif
			g_OutBuff[dataStart + WORK_DATA_EP_OFFSET_0] = shared_temp[GI].endPoint_low;
			g_OutBuff[dataStart + WORK_DATA_EP_OFFSET_0 + 1] = shared_temp[GI].endPoint_high;
			g_OutBuff[dataStart + WORK_DATA_EP_OFFSET_1] = shared_temp[GI].endPoint1_low;
			g_OutBuff[dataStart + WORK_DATA_EP_OFFSET_1 + 1] = shared_temp[GI].endPoint1_high;
        }
        else
        {
			CopyBlock(blockID);
        }
    }
}

void TryMode02CS( uint GI, uint3 groupID, uint modeId, uint num_partitions ) // mode 0 2 have 3 subsets per block
{
    const uint MAX_USED_THREAD = num_partitions;
    uint BLOCK_IN_GROUP = THREAD_GROUP_SIZE / MAX_USED_THREAD;
    uint blockInGroup = GI / MAX_USED_THREAD;
    uint blockID = g_start_block_id + groupID.x * BLOCK_IN_GROUP + blockInGroup;
    uint threadBase = blockInGroup * MAX_USED_THREAD;
    uint threadInBlock = GI - threadBase;

    uint block_y = blockID / g_num_block_x;
    uint block_x = blockID - block_y * g_num_block_x;
    uint base_x = block_x * BLOCK_SIZE_X;
    uint base_y = block_y * BLOCK_SIZE_Y;
    
    if (threadInBlock < 16)
    {
        shared_temp[GI].pixel = clamp(uint4(g_Input.Load( uint3( base_x + threadInBlock % 4, base_y + threadInBlock / 4, 0 ) ) * 255), 0, 255);
    }
    GroupMemoryBarrierWithGroupSync();

    shared_temp[GI].error = 0xFFFFFFFF;

	uint step_selector;
	if (0 == modeId)
		step_selector = INDEX_PREC_3;
	else
		step_selector = INDEX_PREC_2;

	uint numIndexBits = BitsForPrec(step_selector);

    uint2x4 endPoint[3];        // endPoint[0..1 for subset id][0..1 for low and high in the subset]
    uint2x4 endPointBackup[3];
	uint4 debugData = uint4(0, 0, 0, 0);
    if (threadInBlock < num_partitions)
    {
        uint partition = threadInBlock + 64;

		EndpointSelectorRGB es[3];
		for ( uint epi = 0; epi < 3; epi ++ )
			InitEndpointSelector(es[epi]);

        uint bits2 = candidateSectionBit2[partition - 64];
		for( int ep_pass = 0; ep_pass < ENDPOINT_SELECTOR_PASSES; ++ep_pass )
		{
			InitEndpointSelectorPass(es[0], ep_pass);
			InitEndpointSelectorPass(es[1], ep_pass);
			InitEndpointSelectorPass(es[2], ep_pass);

			for( int pxi = 0; pxi < 16; ++pxi )
			{
				uint4 pixel = shared_temp[threadBase + pxi].pixel;
				uint subset_index = ( bits2 >> ( pxi * 2 ) ) & 0x03;

				if ( subset_index == 2 )
					ContributeEndpointSelector(es[2], ep_pass, float3(pixel.rgb), 1.0);
				else if ( subset_index == 1 )
					ContributeEndpointSelector(es[1], ep_pass, float3(pixel.rgb), 1.0);
				else
					ContributeEndpointSelector(es[0], ep_pass, float3(pixel.rgb), 1.0);
			}
		}

		for ( uint epri = 0; epri < 3; epri ++ )
			GetEndpoints(es[epri], endPoint[epri]);

        endPointBackup[0] = endPoint[0];
        endPointBackup[1] = endPoint[1];
        endPointBackup[2] = endPoint[2];

        uint max_p;
        if (0 == modeId)
        {
            max_p = 64; // changed from 32 to 64
        }
        else
        {
            max_p = 1;
        }

        uint rotation = 0;
        uint error = MAX_UINT;
		uint2x4 bestEndPoint[3];

		for ( int i = 0; i < 3; i++ )
			bestEndPoint[i][0] = bestEndPoint[i][1] = uint4(0, 0, 0, 255);

        for ( uint p = 0; p < max_p; p ++ )
        {
            endPoint[0] = endPointBackup[0];
            endPoint[1] = endPointBackup[1];
            endPoint[2] = endPointBackup[2];
			
			for (uint refinePass = 0; refinePass <= NUM_REFINE_PASSES; refinePass++)
			{
				for ( i = 0; i < 3; i ++ )
				{
					if (0 == modeId)
					{
						compress_endpoints0( endPoint[i], uint2(p >> (i * 2 + 0), p >> (i * 2 + 1)) & 1 );
					}
					else
					{
						compress_endpoints2( endPoint[i] );
					}
				}

				IndexSelectorRGB indexSelectors[3];
				
				for ( i = 0; i < 3; i ++ )
					InitIndexSelector(indexSelectors[i], endPoint[i], step_selector);

				EndpointRefiner er[3];
				InitEndpointRefiner(er[0], 1 << numIndexBits);
				InitEndpointRefiner(er[1], 1 << numIndexBits);
				InitEndpointRefiner(er[2], 1 << numIndexBits);

				uint p_error = 0;
				for ( i = 0; i < 16; i ++ )
				{
					uint4 pixel = shared_temp[threadBase + i].pixel;

					uint4 pixel_r;
					uint color_index;
					uint subset_index = ( bits2 >> ( i * 2 ) ) & 0x03;
					if ( subset_index == 2 )
					{
						color_index = SelectIndex(indexSelectors[2], pixel);
						pixel_r.rgb = ReconstructIndex(indexSelectors[2], color_index);
						ContributeEndpointRefiner(er[2], uint4(pixel.rgb, 255), color_index, 1.0);
					}
					else if ( subset_index == 1 )
					{
						color_index = SelectIndex(indexSelectors[1], pixel);
						pixel_r.rgb = ReconstructIndex(indexSelectors[1], color_index);
						ContributeEndpointRefiner(er[1], uint4(pixel.rgb, 255), color_index, 1.0);
					}
					else
					{
						color_index = SelectIndex(indexSelectors[0], pixel);
						pixel_r.rgb = ReconstructIndex(indexSelectors[0], color_index);
						ContributeEndpointRefiner(er[0], uint4(pixel.rgb, 255), color_index, 1.0);
					}

					pixel_r.a = 255;

					Ensure_A_Is_Larger( pixel_r, pixel );
					pixel_r -= pixel;
					p_error += ComputeError(pixel_r, pixel_r);
				}

				if (p_error < error)
				{
					error = p_error;
					rotation = p;    // Borrow rotation for p
					bestEndPoint[0] = endPoint[0];
					bestEndPoint[1] = endPoint[1];
					bestEndPoint[2] = endPoint[2];
				}
				
				if (refinePass != NUM_REFINE_PASSES)
				{
					GetRefinedEndpoints(er[0], endPoint[0]);
					GetRefinedEndpoints(er[1], endPoint[1]);
					GetRefinedEndpoints(er[2], endPoint[2]);
				}
			}
        }

#ifdef DEBUG_NEVER_USE_0
		if (modeId == 0)
			error = 0xffffffff;
#endif
#ifdef DEBUG_NEVER_USE_2
		if (modeId == 2)
			error = 0xffffffff;
#endif

        shared_temp[GI].error = error;
        shared_temp[GI].partition = partition;
        shared_temp[GI].rotation = rotation;
		shared_temp[GI].endPoint_low = bestEndPoint[0][0];
		shared_temp[GI].endPoint_high = bestEndPoint[0][1];
		shared_temp[GI].endPoint1_low = bestEndPoint[1][0];
		shared_temp[GI].endPoint1_high = bestEndPoint[1][1];
		shared_temp[GI].endPoint2_low = bestEndPoint[2][0];
		shared_temp[GI].endPoint2_high = bestEndPoint[2][1];
#ifdef DEBUG_INCLUDE_DEBUG_DATA
		shared_temp[GI].debugData = debugData;
#endif
    }
    GroupMemoryBarrierWithGroupSync();

	if (modeId == 2)
	{
		if (threadInBlock < 32)
		{
			if ( shared_temp[GI].error > shared_temp[GI + 32].error )
			{
				shared_temp[GI].error = shared_temp[GI + 32].error;
				shared_temp[GI].partition = shared_temp[GI + 32].partition;
				shared_temp[GI].rotation = shared_temp[GI + 32].rotation;
				shared_temp[GI].endPoint_low = shared_temp[GI + 32].endPoint_low;
				shared_temp[GI].endPoint_high = shared_temp[GI + 32].endPoint_high;
				shared_temp[GI].endPoint1_low = shared_temp[GI + 32].endPoint1_low;
				shared_temp[GI].endPoint1_high = shared_temp[GI + 32].endPoint1_high;
				shared_temp[GI].endPoint2_low = shared_temp[GI + 32].endPoint2_low;
				shared_temp[GI].endPoint2_high = shared_temp[GI + 32].endPoint2_high;
#ifdef DEBUG_INCLUDE_DEBUG_DATA
				shared_temp[GI].debugData = shared_temp[GI + 32].debugData;
#endif
			}
		}
#ifdef REF_DEVICE
		GroupMemoryBarrierWithGroupSync();
#endif
		if (threadInBlock < 16)
		{
			if ( shared_temp[GI].error > shared_temp[GI + 16].error )
			{
				shared_temp[GI].error = shared_temp[GI + 16].error;
				shared_temp[GI].partition = shared_temp[GI + 16].partition;
				shared_temp[GI].rotation = shared_temp[GI + 16].rotation;
				shared_temp[GI].endPoint_low = shared_temp[GI + 16].endPoint_low;
				shared_temp[GI].endPoint_high = shared_temp[GI + 16].endPoint_high;
				shared_temp[GI].endPoint1_low = shared_temp[GI + 16].endPoint1_low;
				shared_temp[GI].endPoint1_high = shared_temp[GI + 16].endPoint1_high;
				shared_temp[GI].endPoint2_low = shared_temp[GI + 16].endPoint2_low;
				shared_temp[GI].endPoint2_high = shared_temp[GI + 16].endPoint2_high;
#ifdef DEBUG_INCLUDE_DEBUG_DATA
				shared_temp[GI].debugData = shared_temp[GI + 16].debugData;
#endif
			}
		}
#ifdef REF_DEVICE
		GroupMemoryBarrierWithGroupSync();
#endif
	}

    if (threadInBlock < 8)
    {
        if ( shared_temp[GI].error > shared_temp[GI + 8].error )
        {
            shared_temp[GI].error = shared_temp[GI + 8].error;
            shared_temp[GI].partition = shared_temp[GI + 8].partition;
            shared_temp[GI].rotation = shared_temp[GI + 8].rotation;
            shared_temp[GI].endPoint_low = shared_temp[GI + 8].endPoint_low;
            shared_temp[GI].endPoint_high = shared_temp[GI + 8].endPoint_high;
            shared_temp[GI].endPoint1_low = shared_temp[GI + 8].endPoint1_low;
            shared_temp[GI].endPoint1_high = shared_temp[GI + 8].endPoint1_high;
            shared_temp[GI].endPoint2_low = shared_temp[GI + 8].endPoint2_low;
            shared_temp[GI].endPoint2_high = shared_temp[GI + 8].endPoint2_high;
#ifdef DEBUG_INCLUDE_DEBUG_DATA
			shared_temp[GI].debugData = shared_temp[GI + 8].debugData;
#endif
        }
    }
#ifdef REF_DEVICE
    GroupMemoryBarrierWithGroupSync();
#endif
    if (threadInBlock < 4)
    {
        if ( shared_temp[GI].error > shared_temp[GI + 4].error )
        {
            shared_temp[GI].error = shared_temp[GI + 4].error;
            shared_temp[GI].partition = shared_temp[GI + 4].partition;
            shared_temp[GI].rotation = shared_temp[GI + 4].rotation;
            shared_temp[GI].endPoint_low = shared_temp[GI + 4].endPoint_low;
            shared_temp[GI].endPoint_high = shared_temp[GI + 4].endPoint_high;
            shared_temp[GI].endPoint1_low = shared_temp[GI + 4].endPoint1_low;
            shared_temp[GI].endPoint1_high = shared_temp[GI + 4].endPoint1_high;
            shared_temp[GI].endPoint2_low = shared_temp[GI + 4].endPoint2_low;
            shared_temp[GI].endPoint2_high = shared_temp[GI + 4].endPoint2_high;
#ifdef DEBUG_INCLUDE_DEBUG_DATA
			shared_temp[GI].debugData = shared_temp[GI + 4].debugData;
#endif
        }
    }
#ifdef REF_DEVICE
    GroupMemoryBarrierWithGroupSync();
#endif
    if (threadInBlock < 2)
    {
        if ( shared_temp[GI].error > shared_temp[GI + 2].error )
        {
            shared_temp[GI].error = shared_temp[GI + 2].error;
            shared_temp[GI].partition = shared_temp[GI + 2].partition;
            shared_temp[GI].rotation = shared_temp[GI + 2].rotation;
            shared_temp[GI].endPoint_low = shared_temp[GI + 2].endPoint_low;
            shared_temp[GI].endPoint_high = shared_temp[GI + 2].endPoint_high;
            shared_temp[GI].endPoint1_low = shared_temp[GI + 2].endPoint1_low;
            shared_temp[GI].endPoint1_high = shared_temp[GI + 2].endPoint1_high;
            shared_temp[GI].endPoint2_low = shared_temp[GI + 2].endPoint2_low;
            shared_temp[GI].endPoint2_high = shared_temp[GI + 2].endPoint2_high;
#ifdef DEBUG_INCLUDE_DEBUG_DATA
			shared_temp[GI].debugData = shared_temp[GI + 2].debugData;
#endif
        }
    }
#ifdef REF_DEVICE
    GroupMemoryBarrierWithGroupSync();
#endif
    if (threadInBlock < 1)
    {
        if ( shared_temp[GI].error > shared_temp[GI + 1].error )
        {
            shared_temp[GI].error = shared_temp[GI + 1].error;
            shared_temp[GI].partition = shared_temp[GI + 1].partition;
            shared_temp[GI].rotation = shared_temp[GI + 1].rotation;
            shared_temp[GI].endPoint_low = shared_temp[GI + 1].endPoint_low;
            shared_temp[GI].endPoint_high = shared_temp[GI + 1].endPoint_high;
            shared_temp[GI].endPoint1_low = shared_temp[GI + 1].endPoint1_low;
            shared_temp[GI].endPoint1_high = shared_temp[GI + 1].endPoint1_high;
            shared_temp[GI].endPoint2_low = shared_temp[GI + 1].endPoint2_low;
            shared_temp[GI].endPoint2_high = shared_temp[GI + 1].endPoint2_high;
#ifdef DEBUG_INCLUDE_DEBUG_DATA
			shared_temp[GI].debugData = shared_temp[GI + 1].debugData;
#endif
        }

		uint dataStart = blockID * WORK_DATA_STRIDE;
        if (g_InBuff[dataStart].x > shared_temp[GI].error)
        {
#ifdef DEBUG_DUMP_DEBUG_DATA
			g_OutBuff[dataStart] = shared_temp[GI].debugData;
#else
            g_OutBuff[dataStart] = uint4(shared_temp[GI].error, modeId, shared_temp[GI].partition, shared_temp[GI].rotation); // rotation is actually p bit for mode 0. for mode 2, rotation is always 0
#endif
			g_OutBuff[dataStart + WORK_DATA_EP_OFFSET_0] = shared_temp[GI].endPoint_low;
			g_OutBuff[dataStart + WORK_DATA_EP_OFFSET_0 + 1] = shared_temp[GI].endPoint_high;
			g_OutBuff[dataStart + WORK_DATA_EP_OFFSET_1] = shared_temp[GI].endPoint1_low;
			g_OutBuff[dataStart + WORK_DATA_EP_OFFSET_1 + 1] = shared_temp[GI].endPoint1_high;
			g_OutBuff[dataStart + WORK_DATA_EP_OFFSET_2] = shared_temp[GI].endPoint2_low;
			g_OutBuff[dataStart + WORK_DATA_EP_OFFSET_2 + 1] = shared_temp[GI].endPoint2_high;
        }
        else
        {
			CopyBlock(blockID);
        }
    }
}


[numthreads( THREAD_GROUP_SIZE, 1, 1 )]
void TryMode0CS( uint GI : SV_GroupIndex, uint3 groupID : SV_GroupID )
{
	TryMode02CS(GI, groupID, 0, 16);
}

[numthreads( THREAD_GROUP_SIZE, 1, 1 )]
void TryMode2CS( uint GI : SV_GroupIndex, uint3 groupID : SV_GroupID )
{
	TryMode02CS(GI, groupID, 2, 64);
}

[numthreads( THREAD_GROUP_SIZE, 1, 1 )]
void EncodeBlockCS(uint GI : SV_GroupIndex, uint3 groupID : SV_GroupID)
{
    const uint MAX_USED_THREAD = 16;
    uint BLOCK_IN_GROUP = THREAD_GROUP_SIZE / MAX_USED_THREAD;
    uint blockInGroup = GI / MAX_USED_THREAD;
    uint blockID = g_start_block_id + groupID.x * BLOCK_IN_GROUP + blockInGroup;
    uint threadBase = blockInGroup * MAX_USED_THREAD;
    uint threadInBlock = GI - threadBase;

#ifndef REF_DEVICE
    if (blockID >= g_num_total_blocks)
    {
        return;
    }
#endif

    uint block_y = blockID / g_num_block_x;
    uint block_x = blockID - block_y * g_num_block_x;
    uint base_x = block_x * BLOCK_SIZE_X;
    uint base_y = block_y * BLOCK_SIZE_Y;

	uint dataStart = blockID * WORK_DATA_STRIDE;
    uint mode = g_InBuff[dataStart].y & 0x7FFFFFFF;
    uint partition = g_InBuff[dataStart].z;
    uint index_selector = (g_InBuff[dataStart].y >> 31) & 1;
    uint rotation = g_InBuff[dataStart].w;

    if (threadInBlock < 16)
    {
        uint4 pixel = clamp(uint4(g_Input.Load( uint3( base_x + threadInBlock % 4, base_y + threadInBlock / 4, 0 ) ) * 255), 0, 255);

        if ((4 == mode) || (5 == mode))
        {
            if (1 == rotation)
            {
                pixel.ra = pixel.ar;
            }
            else if (2 == rotation)
            {
                pixel.ga = pixel.ag;
            }
            else if (3 == rotation)
            {
                pixel.ba = pixel.ab;
            }
        }

        shared_temp[GI].pixel = pixel;
    }
#ifdef REF_DEVICE
    GroupMemoryBarrierWithGroupSync();
#endif

    uint bits = candidateSectionBit[partition];
    uint bits2 = candidateSectionBit2[partition - 64];

	uint2 indexPrec;
	if ((0 == mode) || (1 == mode))
	{
		indexPrec = INDEX_PREC_3;
	}
	else if (6 == mode)
	{
		indexPrec = INDEX_PREC_4;
	}
	else if (4 == mode)
	{
		if (0 == index_selector)
		{
			indexPrec = uint2(INDEX_PREC_2, INDEX_PREC_3);
		}
		else
		{
			indexPrec = uint2(INDEX_PREC_3, INDEX_PREC_2);
		}
	}
	else
	{
		indexPrec = INDEX_PREC_2;
	}

    if (threadInBlock < 16)
    {
        uint color_index = 0;
        uint alpha_index = 0;

        uint2x4 ep;

        int subset_index;
        if ((0 == mode) || (2 == mode))
        {
            subset_index = (bits2 >> (threadInBlock * 2)) & 0x03;
        }
        else if ((1 == mode) || (3 == mode) || (7 == mode))
        {
            subset_index = (bits >> threadInBlock) & 0x01;
        }
        else
        {
            subset_index = 0;
        }

        ep[0] = g_InBuff[dataStart + WORK_DATA_EP_OFFSET_0 + 2 * subset_index];
        ep[1] = g_InBuff[dataStart + WORK_DATA_EP_OFFSET_0 + 2 * subset_index + 1];

        if ((4 == mode) || (5 == mode))
        {
			IndexSelectorRGB rgbIndexSelector;
			IndexSelectorA alphaIndexSelector;
			InitIndexSelector(rgbIndexSelector, ep, indexPrec.x);
			InitIndexSelector(alphaIndexSelector, ep, indexPrec.y);

			color_index = SelectIndex(rgbIndexSelector, shared_temp[threadBase + threadInBlock].pixel);
			alpha_index = SelectIndex(alphaIndexSelector, shared_temp[threadBase + threadInBlock].pixel);

            if (index_selector)
            {
                swap(color_index, alpha_index);
				swap(indexPrec.x, indexPrec.y);
            }
        }
        else
        {
			IndexSelectorRGBA indexSelector;
			InitIndexSelector(indexSelector, ep, indexPrec.x);

			color_index = SelectIndex(indexSelector, shared_temp[threadBase + threadInBlock].pixel);
        }
		
#ifdef DEBUG_INDEX_MIN
		color_index = 0;
		alpha_index = 0;
#endif

#ifdef DEBUG_INDEX_MAX
		color_index = (1 << BitsForPrec(indexPrec.x)) - 1;
		alpha_index = (1 << BitsForPrec(indexPrec.y)) - 1;
#endif

        shared_temp[GI].error = color_index;
        shared_temp[GI].mode = alpha_index;
    }
#ifdef REF_DEVICE
    GroupMemoryBarrierWithGroupSync();
#endif

#ifdef DEBUG_NEVER_FLIP_ENDPOINTS
	if (threadInBlock < 3)
	{
		uint2x4 ep;
        ep[0] = g_InBuff[dataStart + WORK_DATA_EP_OFFSET_0 + 2 * threadInBlock];
        ep[1] = g_InBuff[dataStart + WORK_DATA_EP_OFFSET_0 + 2 * threadInBlock + 1];

		shared_temp[GI].endPoint_low_quantized = ep[0];
		shared_temp[GI].endPoint_high_quantized = ep[1];
	}
#else
	// Detect color/alpha flipping for each subset
	if (threadInBlock < 3)
	{
		uint fixUpIndex = 0;
		if (threadInBlock == 1)
			fixUpIndex = candidateFixUpIndex1D[partition].x;
		else if (threadInBlock == 2)
			fixUpIndex = candidateFixUpIndex1D[partition].y;

		uint colorBits = BitsForPrec(indexPrec.x);
		uint alphaBits = BitsForPrec(indexPrec.y);

		uint2x4 ep;
        ep[0] = g_InBuff[dataStart + WORK_DATA_EP_OFFSET_0 + 2 * threadInBlock];
        ep[1] = g_InBuff[dataStart + WORK_DATA_EP_OFFSET_0 + 2 * threadInBlock + 1];

#ifdef DEBUG_ALWAYS_FLIP_ENDPOINTS
		if (1)
#else
		if (shared_temp[threadBase + fixUpIndex].error & (1 << (colorBits - 1)))
#endif
		{
			shared_temp[GI].flipColor = (1 << colorBits) - 1;

			if (mode == 4 || mode == 5)
			{
				if (index_selector)
					swap(ep[0].a, ep[1].a);
				else
					swap(ep[0].rgb, ep[1].rgb);
			}
			else
				swap(ep[0], ep[1]);
		}
		else
			shared_temp[GI].flipColor = 0;

		if (threadInBlock == 0 && (mode == 4 || mode == 5))
		{
#ifdef DEBUG_ALWAYS_FLIP_ENDPOINTS
			if (1)
#else
			if (shared_temp[threadBase + 0].mode & (1 << (alphaBits - 1)))
#endif
			{
				shared_temp[GI].flipAlpha = (1 << alphaBits) - 1;
				
				if (index_selector)
					swap(ep[0].rgb, ep[1].rgb);
				else
					swap(ep[0].a, ep[1].a);
			}
			else
				shared_temp[GI].flipAlpha = 0;
		}
		else
			shared_temp[GI].flipAlpha = 0;

		// Write out final endpoints
		shared_temp[GI].endPoint_low_quantized = ep[0];
		shared_temp[GI].endPoint_high_quantized = ep[1];
	}
	
#ifdef DEBUG_MUTE_PARTITION_0
	if (threadInBlock == 0)
	{
		shared_temp[GI].endPoint_low_quantized = uint4(0,0,0,0);
		shared_temp[GI].endPoint_high_quantized = uint4(0,0,0,0);
	}
#endif
	
#ifdef DEBUG_MUTE_PARTITION_1
	if (threadInBlock == 1)
	{
		shared_temp[GI].endPoint_low_quantized = uint4(0,0,0,0);
		shared_temp[GI].endPoint_high_quantized = uint4(0,0,0,0);
	}
#endif
	
#ifdef DEBUG_MUTE_PARTITION_2
	if (threadInBlock == 2)
	{
		shared_temp[GI].endPoint_low_quantized = uint4(0,0,0,0);
		shared_temp[GI].endPoint_high_quantized = uint4(0,0,0,0);
	}
#endif

#ifdef REF_DEVICE
    GroupMemoryBarrierWithGroupSync();
#endif

	// Flip indexes
	if (threadInBlock < 16)
	{
		int subset_index;
        if ((0 == mode) || (2 == mode))
        {
            subset_index = (bits2 >> (threadInBlock * 2)) & 0x03;
        }
        else if ((1 == mode) || (3 == mode) || (7 == mode))
        {
            subset_index = (bits >> threadInBlock) & 0x01;
        }
        else
        {
            subset_index = 0;
        }
		
		uint flipColor = shared_temp[threadBase + subset_index].flipColor;
		uint flipAlpha = shared_temp[threadBase + subset_index].flipAlpha;

		if (flipColor)
			shared_temp[GI].error = flipColor - shared_temp[GI].error;
		if (flipAlpha)
			shared_temp[GI].mode = flipAlpha - shared_temp[GI].mode;
	}
#ifdef REF_DEVICE
    GroupMemoryBarrierWithGroupSync();
#endif

#endif

	// Write out
    if (0 == threadInBlock)
    {
        uint4 block;
        if (0 == mode)
        {
            block_package0( block, partition, threadBase );
        }
        else if (1 == mode)
        {
            block_package1( block, partition, threadBase );
        }
        else if (2 == mode)
        {
            block_package2( block, partition, threadBase );
        }
        else if (3 == mode)
        {
            block_package3( block, partition, threadBase );
        }
        else if (4 == mode)
        {
            block_package4( block, rotation, index_selector, threadBase );
        }
        else if (5 == mode)
        {
            block_package5( block, rotation, threadBase );
        }
        else if (6 == mode)
        {
            block_package6( block, threadBase );
        }
        else //if (7 == mode)
        {
            block_package7( block, partition, threadBase );
        }
		
#ifdef DEBUG_DUMP_METADATA
		block = g_InBuff[dataStart];
#endif

        g_OutBuff[blockID] = block;
    }
}
