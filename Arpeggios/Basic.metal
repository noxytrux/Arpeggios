//
//  Basic.metal
//  Arpeggios
//
//  Created by Marcin Pędzimąż on 22.10.2014.
//  Copyright (c) 2014 Marcin Pedzimaz. All rights reserved.
//

#include "shaderCommon.h"

vertex VertexOutput basicRenderVertex(device Vertex *vertexData [[ buffer(0) ]],
                                      constant modelMatrices &matrices [[ buffer(1) ]],
                                      constant sunData &sunInfo [[ buffer(2) ]],
                                      uint vid [[vertex_id]])
{
    VertexOutput outVertex;
    Vertex vData = vertexData[vid];
    
    float4 position = float4(vData.position,1.0);
    float4 normal = float4(vData.normal, 1.0);
    float4 sunDirection = float4(sunInfo.sunDirection, 1.0);

    outVertex.v_position = matrices.projectionMatrix * matrices.modelViewMatrix * position;
    outVertex.v_normal   = (matrices.normalMatrix * normal).xyz;
    outVertex.v_texcoord = vData.texcoord;
    outVertex.v_sun = normalize((matrices.modelViewMatrix * sunDirection).xyz) - normalize((matrices.modelViewMatrix * position).xyz);
    outVertex.v_sunColor = sunInfo.sunColor;
    
    return outVertex;
};

fragment float4 basicRenderFragment(VertexOutput inFrag [[stage_in]],
                                    texture2d<float> diffuseTexture [[ texture(0) ]])
{
    constexpr sampler linear_sampler(min_filter::linear, mag_filter::linear);
    
    float4 outColor = diffuseTexture.sample(linear_sampler, inFrag.v_texcoord);
    
    if(outColor.a < 0.5) {
        
        discard_fragment();
    }
    
    float3 ambientColor = float3(0.4,0.4,0.4);
    float diffuseFactor = max( dot(inFrag.v_sun, inFrag.v_normal), 0.0);
    
    return float4( float3( (ambientColor+inFrag.v_sunColor * diffuseFactor) * outColor.rgb ), outColor.a);
};


