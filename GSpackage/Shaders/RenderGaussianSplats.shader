// SPDX-License-Identifier: MIT
Shader "Gaussian Splatting/Render Splats"
{

	Properties
		{
			_LightDirection ("Light Direction", Vector) = (0, 0, -1, 0)
			_LightPositon ("Light Position", Vector) = (0, 0, 0, 0)
			_LightColor ("Light Color", Color) = (1, 1, 1, 1)
			_SpecularIntensity ("Specular Intensity", float) = 0.5
			_SpecularPower ("Specular Power", float) = 32.0
			_CameraPosition ("Camera Position", Vector) = (0, 0, 0, 0)
		}

    SubShader
    {
        Tags { "RenderType"="Transparent" "Queue"="Transparent" }

        Pass
        {
            ZWrite Off //깊이 버퍼에 쓰기 비활성화합. 투명 오브젝트는 ZWrite가 꺼져있어야함 깜빡했네
            Blend OneMinusDstAlpha One // 투명도를 조절하기 위한 블렌딩 모드, 대상 픽셀의 알파값을 기준으로 블렌딩
            Cull Off //오브젝트의 양면 모두 렌더링
            
CGPROGRAM
#pragma vertex vert //함수바인딩하는 부분입니다 (ex. 정점 셰이더는 vert 함수를 사용)
#pragma fragment frag
#pragma require compute // 컴퓨트 셰이더 기능이 필요함
#pragma use_dxc // DXC(DX 컴파일러)를 사용하도록 설정

#include "GaussianSplatting.hlsl"

StructuredBuffer<uint> _OrderBuffer; //스플랫들의 렌더링 순서를 정의
StructuredBuffer<float3> _NormalVectors; //normal vector들을 저장하는 버퍼


struct v2f
{
    half4 col : COLOR0;
    float2 pos : TEXCOORD0;
    float4 vertex : SV_POSITION;
	float3 normal : NORMAL;
};

StructuredBuffer<SplatViewData> _SplatViewData; //각 스플랫의 뷰 데이터를 저장하는 구조화된 버퍼
ByteAddressBuffer _SplatSelectedBits; // 각 스플랫의 선택 상태를 저장하는 비트 플래그 버퍼
uint _SplatBitsValid; //선택 비트가 유효한지 여부를 나타내는 플래그

// 조명 관련 변수
float4 _LightColor;
float4 _LightDirection;
float4 _LightPosition;
float4 _CameraPosition;
float _SpecularIntensity;
float _SpecularPower;

// 정점 셰이더 (vert 함수)
v2f vert (uint vtxID : SV_VertexID, uint instID : SV_InstanceID)
{
    v2f o = (v2f)0;
    instID = _OrderBuffer[instID];
	SplatViewData view = _SplatViewData[instID];

	o.normal = _NormalVectors[instID]; // fragment shader에 normal vector 전달

	float4 centerClipPos = view.pos;
	bool behindCam = centerClipPos.w <= 0;
	if (behindCam)
	{
		o.vertex = asfloat(0x7fc00000); // NaN discards the primitive
	}
	else
	{
		o.col.r = f16tof32(view.color.x >> 16); //스플랫의 색상을 설정
		o.col.g = f16tof32(view.color.x);
		o.col.b = f16tof32(view.color.y >> 16);
		o.col.a = f16tof32(view.color.y);

		uint idx = vtxID;
		float2 quadPos = float2(idx&1, (idx>>1)&1) * 2.0 - 1.0; //스플랫을 화면에 사각형으로 그리기 위해 2D 좌표를 설정
		quadPos *= 2;

		o.pos = quadPos;

		float2 deltaScreenPos = (quadPos.x * view.axis1 + quadPos.y * view.axis2) * 2 / _ScreenParams.xy; //화면 상에서 스플랫의 위치를 조정
		o.vertex = centerClipPos;
		o.vertex.xy += deltaScreenPos * centerClipPos.w;

		// is this splat selected?
		if (_SplatBitsValid) //활성화되어 있으면 선택된 스플랫을 확인하고, 선택된 경우 알파 값을 -1로 설정
		{
			uint wordIdx = instID / 32;
			uint bitIdx = instID & 31;
			uint selVal = _SplatSelectedBits.Load(wordIdx * 4);
			if (selVal & (1 << bitIdx))
			{
				o.col.a = -1;				
			}
		}
	}
    return o;
}

// 프래그먼트 셰이더 (frag 함수)
half4 frag (v2f i) : SV_Target
{
	float power = -dot(i.pos, i.pos); //스플랫의 화면상에서의 위치를 기반으로 투명도를 결정. 중심에서 멀어질수록 투명도가 커진다고 보면됨
	half alpha = exp(power); // 투명도는 스플랫의 중심이 더 불투명하고 가장자리로 갈수록 투명해지도록 설정
	if (i.col.a >= 0)
	{
		alpha = saturate(alpha * i.col.a);
	}
	else // i.col.a 값이 음수인 경우, 선택된 스플랫이므로
	{
		// "selected" splat: magenta outline, increase opacity, magenta tint
		half3 selectedColor = half3(1,0,1);
		if (alpha > 7.0/255.0)
		{
			if (alpha < 10.0/255.0)
			{
				alpha = 1;
				i.col.rgb = selectedColor; //선택된 스플랫에 대해 불투명도를 높이고 셀렉티드 색상으로 변경
			}
			alpha = saturate(alpha + 0.3);
		}
		i.col.rgb = lerp(i.col.rgb, selectedColor, 0.5);
	}
	
	
	//일단 directional light object로 진행
	float3 lightDir = normalize(_LightDirection.xyz);
	float3 lightCol = normalize(_LightColor.rgb);

	//point light object로 변경시 아래처럼 변경
	//float3 currentPos = i.vertex.xyz;
	//float3 lightDir = normalize(_LightPosition.xyz - currentPos);

	//normal vector 수정 필요
	//현재 vertex와 인접한 vertex를 사용해 만든 삼각형의 normal vector를 구하는식으로
	float3 normal = i.normal;

	// float3 viewDir = normalize(_CameraPosition - i.worldPos); //카메라에서 스플랫까지의 방향
	// float3 reflectDir = reflect(-lightDir, normal); // 반사된 빛의 방향(원이 표면에 닿아 반사된 방향을 계산)

	// diffuse 계산
	float diffuse = max(dot(normal, lightDir), 0.0);
	float3 diffuseColor = _LightColor.rgb * diffuse;
	
	// 정반사관 (phongshading) 계산 추가
	// float specular = pow(max(dot(viewDir, reflectDir), 0.0), _SpecularPower); //스페큘러 강도 계산 (카메라 시선 방향과 반사된 빛의 각도 차이에 따른 정반사광을 계산)
	// float3 specularColor = _LightColor.rgb * specular * _SpecularIntensity; //스페큘러 색상 적용

	i.col.rgb *= diffuseColor;

	// i.col.rgb *=  (_LightColor.rgb + diffuseColor);
	// i.col.rgb *= (diffuseColor + specularColor);

    if (alpha < 1.0/255.0); //투명도가 1/255 이하이면 해당 프래그먼트를 렌더링하지 않음

    half4 res = half4(i.col.rgb * alpha, alpha);
    return res;
}
ENDCG
        }
    }
}
