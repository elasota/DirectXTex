#include "BC7EncodeCommon.h"

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

    uint2x4 endPoint;
    endPoint[0] = shared_temp[threadBase].endPoint_low;
    endPoint[1] = shared_temp[threadBase].endPoint_high;

    uint error = 0xFFFFFFFF;
    uint mode = 0;
    uint index_selector = 0;
    uint rotation = 0;

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

    uint4 pixel_r;
    uint color_index;
    uint alpha_index;
    int4 span;
    int2 span_norm_sqr;
    int2 dotProduct;
    if (threadInBlock < 12) // Try mode 4 5 in threads 0..11
    {
        // mode 4 5 have component rotation
        if ((threadInBlock < 2) || (8 == threadInBlock))       // rotation = 0 in thread 0, 1
        {
            rotation = 0;
        }
        else if ((threadInBlock < 4) || (9 == threadInBlock))  // rotation = 1 in thread 2, 3
        {
            endPoint[0].ra = endPoint[0].ar;
            endPoint[1].ra = endPoint[1].ar;

            rotation = 1;
        }
        else if ((threadInBlock < 6) || (10 == threadInBlock)) // rotation = 2 in thread 4, 5
        {
            endPoint[0].ga = endPoint[0].ag;
            endPoint[1].ga = endPoint[1].ag;

            rotation = 2;
        }
        else if ((threadInBlock < 8) || (11 == threadInBlock)) // rotation = 3 in thread 6, 7
        {
            endPoint[0].ba = endPoint[0].ab;
            endPoint[1].ba = endPoint[1].ab;

            rotation = 3;
        }

        if (threadInBlock < 8)  // try mode 4 in threads 0..7
        {
            // mode 4 thread distribution
            // Thread           0	1	2	3	4	5	6	7
            // Rotation	        0	0	1	1	2	2	3	3
            // Index selector   0	1	0	1	0	1	0	1

            mode = 4;
            compress_endpoints4( endPoint );
        }
        else                    // try mode 5 in threads 8..11
        {
            // mode 5 thread distribution
            // Thread	 8	9  10  11
            // Rotation	 0	1   2   3

            mode = 5;
            compress_endpoints5( endPoint );
        }

        uint4 pixel = shared_temp[threadBase + 0].pixel;
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

        span = endPoint[1] - endPoint[0];
        span_norm_sqr = uint2( dot( span.rgb, span.rgb ), span.a * span.a );
        
        // in mode 4 5 6, end point 0 must be closer to pixel 0 than end point 1, because of the fix-up index is always index 0
        // TODO: this shouldn't be necessary here in error calculation
        /*
        dotProduct = int2( dot( span.rgb, pixel.rgb - endPoint[0].rgb ), span.a * ( pixel.a - endPoint[0].a ) );
        if ( span_norm_sqr.x > 0 && dotProduct.x > 0 && uint( dotProduct.x * 63.49999 ) > uint( 32 * span_norm_sqr.x ) )
        {
            span.rgb = -span.rgb;
            swap(endPoint[0].rgb, endPoint[1].rgb);
        }
        if ( span_norm_sqr.y > 0 && dotProduct.y > 0 && uint( dotProduct.y * 63.49999 ) > uint( 32 * span_norm_sqr.y ) )
        {
            span.a = -span.a;
            swap(endPoint[0].a, endPoint[1].a);
        }
        */
	
        // should be the same as above
        dotProduct = int2( dot( pixel.rgb - endPoint[0].rgb, pixel.rgb - endPoint[0].rgb ), dot( pixel.rgb - endPoint[1].rgb, pixel.rgb - endPoint[1].rgb ) );
        if ( dotProduct.x > dotProduct.y )
        {
            span.rgb = -span.rgb;
            swap(endPoint[0].rgb, endPoint[1].rgb);
        }
        dotProduct = int2( dot( pixel.a - endPoint[0].a, pixel.a - endPoint[0].a ), dot( pixel.a - endPoint[1].a, pixel.a - endPoint[1].a ) );
        if ( dotProduct.x > dotProduct.y )
        {
            span.a = -span.a;
            swap(endPoint[0].a, endPoint[1].a);
        }

        error = 0;
        for ( uint i = 0; i < 16; i ++ )
        {
            pixel = shared_temp[threadBase + i].pixel;
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

            dotProduct.x = dot( span.rgb, pixel.rgb - endPoint[0].rgb );
            color_index = ( span_norm_sqr.x <= 0 /*endPoint[0] == endPoint[1]*/ || dotProduct.x <= 0 /*pixel == endPoint[0]*/ ) ? 0
                : ( ( dotProduct.x < span_norm_sqr.x ) ? aStep[indexPrec.x][ uint( dotProduct.x * 63.49999 / span_norm_sqr.x ) ] : aStep[indexPrec.x][63] );
            dotProduct.y = dot( span.a, pixel.a - endPoint[0].a );
            alpha_index = ( span_norm_sqr.y <= 0 || dotProduct.y <= 0 ) ? 0
                : ( ( dotProduct.y < span_norm_sqr.y ) ? aStep[indexPrec.y][ uint( dotProduct.y * 63.49999 / span_norm_sqr.y ) ] : aStep[indexPrec.y][63] );

            // the same color_index and alpha_index should be used for reconstruction, so this should be left commented out
            /*if (index_selector)
            {
                swap(color_index, alpha_index);
            }*/

            pixel_r.rgb = ( ( 64 - aWeight[indexPrec.x][color_index] ) * endPoint[0].rgb +
                            aWeight[indexPrec.x][color_index] * endPoint[1].rgb + 
                            32 ) >> 6;
            pixel_r.a = ( ( 64 - aWeight[indexPrec.y][alpha_index] ) * endPoint[0].a + 
                          aWeight[indexPrec.y][alpha_index] * endPoint[1].a + 
                          32 ) >> 6;

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
    }
    else if (threadInBlock < 16) // Try mode 6 in threads 12..15, since in mode 4 5 6, only mode 6 has p bit
    {
        uint p = threadInBlock - 12;

        compress_endpoints6( endPoint, uint2(p >> 0, p >> 1) & 1 );

        uint4 pixel = shared_temp[threadBase + 0].pixel;

        span = endPoint[1] - endPoint[0];
        span_norm_sqr = dot( span, span );
        dotProduct = dot( span, pixel - endPoint[0] );
        if ( span_norm_sqr.x > 0 && dotProduct.x >= 0 && uint( dotProduct.x * 63.49999 ) > uint( 32 * span_norm_sqr.x ) )
        {
            span = -span;
            swap(endPoint[0], endPoint[1]);
        }
            
        error = 0;
        for ( uint i = 0; i < 16; i ++ )
        {
            pixel = shared_temp[threadBase + i].pixel;
            
            dotProduct.x = dot( span, pixel - endPoint[0] );
            color_index = ( span_norm_sqr.x <= 0 || dotProduct.x <= 0 ) ? 0
                : ( ( dotProduct.x < span_norm_sqr.x ) ? aStep[0][ uint( dotProduct.x * 63.49999 / span_norm_sqr.x ) ] : aStep[0][63] );
            
            pixel_r = ( ( 64 - aWeight[0][color_index] ) * endPoint[0]
                + aWeight[0][color_index] * endPoint[1] + 32 ) >> 6;
        
            Ensure_A_Is_Larger( pixel_r, pixel );
            pixel_r -= pixel;
            error += ComputeError(pixel_r, pixel_r);
        }

        mode = 6;
        rotation = p;    // Borrow rotation for p
    }

    shared_temp[GI].error = error;
    shared_temp[GI].mode = mode;
    shared_temp[GI].index_selector = index_selector;
    shared_temp[GI].rotation = rotation;

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
        }

        g_OutBuff[blockID] = uint4(shared_temp[GI].error, (shared_temp[GI].index_selector << 31) | shared_temp[GI].mode,
            0, shared_temp[GI].rotation); // rotation is indeed rotation for mode 4 5. for mode 6, rotation is p bit
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

    uint4 pixel_r;
    uint2x4 endPoint[2];        // endPoint[0..1 for subset id][0..1 for low and high in the subset]
    uint2x4 endPointBackup[2];
    uint color_index;
    if (threadInBlock < 64)
    {
        uint partition = threadInBlock;

        endPoint[0][0] = MAX_UINT;
        endPoint[0][1] = MIN_UINT;
        endPoint[1][0] = MAX_UINT;
        endPoint[1][1] = MIN_UINT;
        uint bits = candidateSectionBit[partition];
        for ( uint i = 0; i < 16; i ++ )
        {
            uint4 pixel = shared_temp[threadBase + i].pixel;
            if ( (( bits >> i ) & 0x01) == 1 )
            {
                endPoint[1][0] = min( endPoint[1][0], pixel );
                endPoint[1][1] = max( endPoint[1][1], pixel );
            }
            else
            {
                endPoint[0][0] = min( endPoint[0][0], pixel );
                endPoint[0][1] = max( endPoint[0][1], pixel );
            }
        }

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
        for ( uint p = 0; p < max_p; p ++ )
        {
            endPoint[0] = endPointBackup[0];
            endPoint[1] = endPointBackup[1];

            for ( i = 0; i < 2; i ++ ) // loop through 2 subsets
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

            int4 span[2];
            span[0] = endPoint[0][1] - endPoint[0][0];
            span[1] = endPoint[1][1] - endPoint[1][0];

            if (g_mode_id != 7)
            {
                span[0].w = span[1].w = 0;
            }

            int span_norm_sqr[2];
            span_norm_sqr[0] = dot( span[0], span[0] );
            span_norm_sqr[1] = dot( span[1], span[1] );

            // TODO: again, this shouldn't be necessary here in error calculation
            int dotProduct = dot( span[0], shared_temp[threadBase + 0].pixel - endPoint[0][0] );
            if ( span_norm_sqr[0] > 0 && dotProduct > 0 && uint( dotProduct * 63.49999 ) > uint( 32 * span_norm_sqr[0] ) )
            {
                span[0] = -span[0];
                swap(endPoint[0][0], endPoint[0][1]);
            }
            dotProduct = dot( span[1], shared_temp[threadBase + candidateFixUpIndex1D[partition].x].pixel - endPoint[1][0] );
            if ( span_norm_sqr[1] > 0 && dotProduct > 0 && uint( dotProduct * 63.49999 ) > uint( 32 * span_norm_sqr[1] ) )
            {
                span[1] = -span[1];
                swap(endPoint[1][0], endPoint[1][1]);
            }

            uint step_selector;
            if (g_mode_id != 1)
            {
                step_selector = 2;  // mode 3 7 have 2 bit index
            }
            else
            {
                step_selector = 1;  // mode 1 has 3 bit index
            }

            uint p_error = 0;            
            for ( i = 0; i < 16; i ++ )
            {
                if (((bits >> i) & 0x01) == 1)
                {
                    dotProduct = dot( span[1], shared_temp[threadBase + i].pixel - endPoint[1][0] );
                    color_index = (span_norm_sqr[1] <= 0 || dotProduct <= 0) ? 0
                        : ((dotProduct < span_norm_sqr[1]) ? aStep[step_selector][uint(dotProduct * 63.49999 / span_norm_sqr[1])] : aStep[step_selector][63]);
                }
                else
                {
                    dotProduct = dot( span[0], shared_temp[threadBase + i].pixel - endPoint[0][0] );
                    color_index = (span_norm_sqr[0] <= 0 || dotProduct <= 0) ? 0
                        : ((dotProduct < span_norm_sqr[0]) ? aStep[step_selector][uint(dotProduct * 63.49999 / span_norm_sqr[0])] : aStep[step_selector][63]);
                }

                uint subset_index = (bits >> i) & 0x01;

                pixel_r = ((64 - aWeight[step_selector][color_index]) * endPoint[subset_index][0]
                    + aWeight[step_selector][color_index] * endPoint[subset_index][1] + 32) >> 6;
                if (g_mode_id != 7)
                {
                    pixel_r.a = 255;
                }

                uint4 pixel = shared_temp[threadBase + i].pixel;
                Ensure_A_Is_Larger( pixel_r, pixel );
                pixel_r -= pixel;
                p_error += ComputeError(pixel_r, pixel_r);
            }

            if (p_error < error)
            {
                error = p_error;
                rotation = p;
            }
        }

        shared_temp[GI].error = error;
        shared_temp[GI].mode = g_mode_id;
        shared_temp[GI].partition = partition;
        shared_temp[GI].rotation = rotation; // mode 1 3 7 don't have rotation, we use rotation for p bits
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
        }

        if (g_InBuff[blockID].x > shared_temp[GI].error)
        {
            g_OutBuff[blockID] = uint4(shared_temp[GI].error, shared_temp[GI].mode, shared_temp[GI].partition, shared_temp[GI].rotation); // mode 1 3 7 don't have rotation, we use rotation for p bits
        }
        else
        {
            g_OutBuff[blockID] = g_InBuff[blockID];
        }
    }
}

[numthreads( THREAD_GROUP_SIZE, 1, 1 )]
void TryMode02CS( uint GI : SV_GroupIndex, uint3 groupID : SV_GroupID ) // mode 0 2 have 3 subsets per block
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

    uint num_partitions;
    if (0 == g_mode_id)
    {
        num_partitions = 16;
    }
    else
    {
        num_partitions = 64;
    }

    uint4 pixel_r;
    uint2x4 endPoint[3];        // endPoint[0..1 for subset id][0..1 for low and high in the subset]
    uint2x4 endPointBackup[3];
    uint color_index[16];
    if (threadInBlock < num_partitions)
    {
        uint partition = threadInBlock + 64;

        endPoint[0][0] = MAX_UINT;
        endPoint[0][1] = MIN_UINT;
        endPoint[1][0] = MAX_UINT;
        endPoint[1][1] = MIN_UINT;
        endPoint[2][0] = MAX_UINT;
        endPoint[2][1] = MIN_UINT;
        uint bits2 = candidateSectionBit2[partition - 64];
        for ( uint i = 0; i < 16; i ++ )
        {
            uint4 pixel = shared_temp[threadBase + i].pixel;
            uint subset_index = ( bits2 >> ( i * 2 ) ) & 0x03;
            if ( subset_index == 2 )
            {
                endPoint[2][0] = min( endPoint[2][0], pixel );
                endPoint[2][1] = max( endPoint[2][1], pixel );
            }
            else if ( subset_index == 1 )
            {
                endPoint[1][0] = min( endPoint[1][0], pixel );
                endPoint[1][1] = max( endPoint[1][1], pixel );
            }
            else
            {
                endPoint[0][0] = min( endPoint[0][0], pixel );
                endPoint[0][1] = max( endPoint[0][1], pixel );
            }
        }

        endPointBackup[0] = endPoint[0];
        endPointBackup[1] = endPoint[1];
        endPointBackup[2] = endPoint[2];

        uint max_p;
        if (0 == g_mode_id)
        {
            max_p = 64; // changed from 32 to 64
        }
        else
        {
            max_p = 1;
        }

        uint rotation = 0;
        uint error = MAX_UINT;
        for ( uint p = 0; p < max_p; p ++ )
        {
            endPoint[0] = endPointBackup[0];
            endPoint[1] = endPointBackup[1];
            endPoint[2] = endPointBackup[2];

            for ( i = 0; i < 3; i ++ )
            {
                if (0 == g_mode_id)
                {
                    compress_endpoints0( endPoint[i], uint2(p >> (i * 2 + 0), p >> (i * 2 + 1)) & 1 );
                }
                else
                {
                    compress_endpoints2( endPoint[i] );
                }
            }

            uint step_selector = 1 + (2 == g_mode_id);

            int4 span[3];
            span[0] = endPoint[0][1] - endPoint[0][0];
            span[1] = endPoint[1][1] - endPoint[1][0];
            span[2] = endPoint[2][1] - endPoint[2][0];
            span[0].w = span[1].w = span[2].w = 0;
            int span_norm_sqr[3];
            span_norm_sqr[0] = dot( span[0], span[0] );
            span_norm_sqr[1] = dot( span[1], span[1] );
            span_norm_sqr[2] = dot( span[2], span[2] );

            // TODO: again, this shouldn't be necessary here in error calculation
            uint ci[3] = { 0, candidateFixUpIndex1D[partition].x, candidateFixUpIndex1D[partition].y };
            for (i = 0; i < 3; i ++)
            {
                int dotProduct = dot( span[i], shared_temp[threadBase + ci[i]].pixel - endPoint[i][0] );
                if ( span_norm_sqr[i] > 0 && dotProduct > 0 && uint( dotProduct * 63.49999 ) > uint( 32 * span_norm_sqr[i] ) )
                {
                    span[i] = -span[i];
                    swap(endPoint[i][0], endPoint[i][1]);
                }
            }

            uint p_error = 0;
            for ( i = 0; i < 16; i ++ )
            {
                uint subset_index = ( bits2 >> ( i * 2 ) ) & 0x03;
                if ( subset_index == 2 )
                {
                    int dotProduct = dot( span[2], shared_temp[threadBase + i].pixel - endPoint[2][0] );
                    color_index[i] = ( span_norm_sqr[2] <= 0 || dotProduct <= 0 ) ? 0
                        : ( ( dotProduct < span_norm_sqr[2] ) ? aStep[step_selector][ uint( dotProduct * 63.49999 / span_norm_sqr[2] ) ] : aStep[step_selector][63] );
                }
                else if ( subset_index == 1 )
                {
                    int dotProduct = dot( span[1], shared_temp[threadBase + i].pixel - endPoint[1][0] );
                    color_index[i] = ( span_norm_sqr[1] <= 0 || dotProduct <= 0 ) ? 0
                        : ( ( dotProduct < span_norm_sqr[1] ) ? aStep[step_selector][ uint( dotProduct * 63.49999 / span_norm_sqr[1] ) ] : aStep[step_selector][63] );
                }
                else
                {
                    int dotProduct = dot( span[0], shared_temp[threadBase + i].pixel - endPoint[0][0] );
                    color_index[i] = ( span_norm_sqr[0] <= 0 || dotProduct <= 0 ) ? 0
                        : ( ( dotProduct < span_norm_sqr[0] ) ? aStep[step_selector][ uint( dotProduct * 63.49999 / span_norm_sqr[0] ) ] : aStep[step_selector][63] );
                }

                pixel_r = ( ( 64 - aWeight[step_selector][color_index[i]] ) * endPoint[subset_index][0]
                    + aWeight[step_selector][color_index[i]] * endPoint[subset_index][1] + 32 ) >> 6;
                pixel_r.a = 255;

                uint4 pixel = shared_temp[threadBase + i].pixel;                
                Ensure_A_Is_Larger( pixel_r, pixel );
                pixel_r -= pixel;
                p_error += ComputeError(pixel_r, pixel_r);
            }

            if (p_error < error)
            {
                error = p_error;
                rotation = p;    // Borrow rotation for p
            }
        }

        shared_temp[GI].error = error;
        shared_temp[GI].partition = partition;
        shared_temp[GI].rotation = rotation;
    }
    GroupMemoryBarrierWithGroupSync();

    if (threadInBlock < 32)
    {
        if ( shared_temp[GI].error > shared_temp[GI + 32].error )
        {
            shared_temp[GI].error = shared_temp[GI + 32].error;
            shared_temp[GI].partition = shared_temp[GI + 32].partition;
            shared_temp[GI].rotation = shared_temp[GI + 32].rotation;
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
            shared_temp[GI].partition = shared_temp[GI + 8].partition;
            shared_temp[GI].rotation = shared_temp[GI + 8].rotation;
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
        }

        if (g_InBuff[blockID].x > shared_temp[GI].error)
        {
            g_OutBuff[blockID] = uint4(shared_temp[GI].error, g_mode_id, shared_temp[GI].partition, shared_temp[GI].rotation); // rotation is actually p bit for mode 0. for mode 2, rotation is always 0
        }
        else
        {
            g_OutBuff[blockID] = g_InBuff[blockID];
        }
    }
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

    uint mode = g_InBuff[blockID].y & 0x7FFFFFFF;
    uint partition = g_InBuff[blockID].z;
    uint index_selector = (g_InBuff[blockID].y >> 31) & 1;
    uint rotation = g_InBuff[blockID].w;

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

    uint2x4 ep;
    ep[0] = MAX_UINT;
    ep[1] = MIN_UINT;
    uint2x4 ep_quantized;
    [unroll]
    for (int ii = 2; ii >= 0; -- ii)
    {
        if (threadInBlock < 16)
        {
            uint2x4 ep;
            ep[0] = MAX_UINT;
            ep[1] = MIN_UINT;

            uint4 pixel = shared_temp[GI].pixel;

            uint subset_index = ( bits >> threadInBlock ) & 0x01;
            uint subset_index2 = ( bits2 >> ( threadInBlock * 2 ) ) & 0x03;
            if (0 == ii)
            {
                if ((0 == mode) || (2 == mode))
                {
                    if (0 == subset_index2)
                    {
                        ep[0] = ep[1] = pixel;
                    }
                }
                else if ((1 == mode) || (3 == mode) || (7 == mode))
                {
                    if (0 == subset_index)
                    {
                        ep[0] = ep[1] = pixel;
                    }
                }
                else if ((4 == mode) || (5 == mode) || (6 == mode))
                {
                    ep[0] = ep[1] = pixel;
                }
            }
            else if (1 == ii)
            {
                if ((0 == mode) || (2 == mode))
                {
                    if (1 == subset_index2)
                    {
                        ep[0] = ep[1] = pixel;
                    }
                }
                else if ((1 == mode) || (3 == mode) || (7 == mode))
                {
                    if (1 == subset_index)
                    {
                        ep[0] = ep[1] = pixel;
                    }
                }
            }
            else
            {
                if ((0 == mode) || (2 == mode))
                {
                    if (2 == subset_index2)
                    {
                        ep[0] = ep[1] = pixel;
                    }
                }
            }

            shared_temp[GI].endPoint_low = ep[0];
            shared_temp[GI].endPoint_high = ep[1];
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

        if (ii == (int)threadInBlock)
        {
            ep[0] = shared_temp[threadBase].endPoint_low;
            ep[1] = shared_temp[threadBase].endPoint_high;
        }
    }

    if (threadInBlock < 3)
    {
        uint2 P;
        if (1 == mode)
        {
            P = (rotation >> threadInBlock) & 1;
        }
        else
        {
            P = uint2(rotation >> (threadInBlock * 2 + 0), rotation >> (threadInBlock * 2 + 1)) & 1;
        }

        if (0 == mode)
        {
            ep_quantized = compress_endpoints0( ep, P );
        }
        else if (1 == mode)
        {
            ep_quantized = compress_endpoints1( ep, P );
        }
        else if (2 == mode)
        {
            ep_quantized = compress_endpoints2( ep );
        }
        else if (3 == mode)
        {
            ep_quantized = compress_endpoints3( ep, P );
        }
        else if (4 == mode)
        {
            ep_quantized = compress_endpoints4( ep );
        }
        else if (5 == mode)
        {
            ep_quantized = compress_endpoints5( ep );
        }
        else if (6 == mode)
        {
            ep_quantized = compress_endpoints6( ep, P );
        }
        else //if (7 == mode)
        {
            ep_quantized = compress_endpoints7( ep, P );
        }

        int4 span = ep[1] - ep[0];
        if (mode < 4)
        {
            span.w = 0;
        }

        if ((4 == mode) || (5 == mode))
        {
            if (0 == threadInBlock)
            {
                int2 span_norm_sqr = uint2( dot( span.rgb, span.rgb ), span.a * span.a );
                int2 dotProduct = int2( dot( span.rgb, shared_temp[threadBase + 0].pixel.rgb - ep[0].rgb ), span.a * ( shared_temp[threadBase + 0].pixel.a - ep[0].a ) );
                if ( span_norm_sqr.x > 0 && dotProduct.x > 0 && uint( dotProduct.x * 63.49999 ) > uint( 32 * span_norm_sqr.x ) )
                {
                    swap(ep[0].rgb, ep[1].rgb);
                    swap(ep_quantized[0].rgb, ep_quantized[1].rgb);
                }
                if ( span_norm_sqr.y > 0 && dotProduct.y > 0 && uint( dotProduct.y * 63.49999 ) > uint( 32 * span_norm_sqr.y ) )
                {
                    swap(ep[0].a, ep[1].a);
                    swap(ep_quantized[0].a, ep_quantized[1].a);		    
                }
            }
        }
        else //if ((0 == mode) || (2 == mode) || (1 == mode) || (3 == mode) || (7 == mode) || (6 == mode))
        {
            int p;
            if (0 == threadInBlock)
            {
                p = 0;
            }
            else if (1 == threadInBlock)
            {
                p = candidateFixUpIndex1D[partition].x;
            }
            else //if (2 == threadInBlock)
            {
                p = candidateFixUpIndex1D[partition].y;
            }

            int span_norm_sqr = dot( span, span );
            int dotProduct = dot( span, shared_temp[threadBase + p].pixel - ep[0] );
            if ( span_norm_sqr > 0 && dotProduct > 0 && uint( dotProduct * 63.49999 ) > uint( 32 * span_norm_sqr ) )
            {
                swap(ep[0], ep[1]);
                swap(ep_quantized[0], ep_quantized[1]);		
            }
        }

        shared_temp[GI].endPoint_low = ep[0];
        shared_temp[GI].endPoint_high = ep[1];
        shared_temp[GI].endPoint_low_quantized = ep_quantized[0];
        shared_temp[GI].endPoint_high_quantized = ep_quantized[1];
    }
#ifdef REF_DEVICE
    GroupMemoryBarrierWithGroupSync();
#endif

    if (threadInBlock < 16)
    {
        uint color_index = 0;
        uint alpha_index = 0;

        uint2x4 ep;

        uint2 indexPrec;
        if ((0 == mode) || (1 == mode))
        {
            indexPrec = 1;
        }
        else if (6 == mode)
        {
            indexPrec = 0;
        }
        else if (4 == mode)
        {
            if (0 == index_selector)
            {
                indexPrec = uint2(2, 1);
            }
            else
            {
                indexPrec = uint2(1, 2);
            }
        }
        else
        {
            indexPrec = 2;
        }

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

        ep[0] = shared_temp[threadBase + subset_index].endPoint_low;
        ep[1] = shared_temp[threadBase + subset_index].endPoint_high;

        int4 span = ep[1] - ep[0];
        if (mode < 4)
        {
            span.w = 0;
        }

        if ((4 == mode) || (5 == mode))
        {
            int2 span_norm_sqr;
            span_norm_sqr.x = dot( span.rgb, span.rgb );
            span_norm_sqr.y = span.a * span.a;
            
            int dotProduct = dot( span.rgb, shared_temp[threadBase + threadInBlock].pixel.rgb - ep[0].rgb );
            color_index = ( span_norm_sqr.x <= 0 || dotProduct <= 0 ) ? 0
                    : ( ( dotProduct < span_norm_sqr.x ) ? aStep[indexPrec.x][ uint( dotProduct * 63.49999 / span_norm_sqr.x ) ] : aStep[indexPrec.x][63] );
            dotProduct = dot( span.a, shared_temp[threadBase + threadInBlock].pixel.a - ep[0].a );
            alpha_index = ( span_norm_sqr.y <= 0 || dotProduct <= 0 ) ? 0
                    : ( ( dotProduct < span_norm_sqr.y ) ? aStep[indexPrec.y][ uint( dotProduct * 63.49999 / span_norm_sqr.y ) ] : aStep[indexPrec.y][63] );

            if (index_selector)
            {
                swap(color_index, alpha_index);
            }
        }
        else
        {
            int span_norm_sqr = dot( span, span );

            int dotProduct = dot( span, shared_temp[threadBase + threadInBlock].pixel - ep[0] );
            color_index = ( span_norm_sqr <= 0 || dotProduct <= 0 ) ? 0
                    : ( ( dotProduct < span_norm_sqr ) ? aStep[indexPrec.x][ uint( dotProduct * 63.49999 / span_norm_sqr ) ] : aStep[indexPrec.x][63] );
        }

        shared_temp[GI].error = color_index;
        shared_temp[GI].mode = alpha_index;
    }
#ifdef REF_DEVICE
    GroupMemoryBarrierWithGroupSync();
#endif

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

        g_OutBuff[blockID] = block;
    }
}
