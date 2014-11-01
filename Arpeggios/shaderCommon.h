//
//  shaderCommon.h
//  Arpeggios
//
//  Created by Marcin Pędzimąż on 22.10.2014.
//  Copyright (c) 2014 Marcin Pedzimaz. All rights reserved.
//

#include <metal_stdlib>
#include <metal_graphics>
#include <metal_texture>
#include <metal_matrix>
#include <metal_math>

using namespace metal;

//common

struct modelMatrices
{
    float4x4 projectionMatrix;
    float4x4 modelViewMatrix;
    float4x4 normalMatrix;
};

struct sunData
{
    packed_float3 sunDirection;
    packed_float3 sunColor;
};

//vertex stuff

struct Vertex
{
    packed_float3 position;
    packed_float3 normal;
    packed_float2 texcoord;
};

struct VertexOutput
{
    float4  v_position [[position]];
    float3  v_normal;
    float2  v_texcoord;
    float3  v_sun;
    float3  v_sunColor;
};