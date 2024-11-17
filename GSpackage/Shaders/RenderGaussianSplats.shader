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
            ZWrite Off //���� ���ۿ� ���� ��Ȱ��ȭ��. ���� ������Ʈ�� ZWrite�� �����־���� �����߳�
            Blend OneMinusDstAlpha One // ������ �����ϱ� ���� ���� ���, ��� �ȼ��� ���İ��� �������� ����
            Cull Off //������Ʈ�� ��� ��� ������
            
CGPROGRAM
#pragma vertex vert //�Լ����ε��ϴ� �κ��Դϴ� (ex. ���� ���̴��� vert �Լ��� ���)
#pragma fragment frag
#pragma require compute // ��ǻƮ ���̴� ����� �ʿ���
#pragma use_dxc // DXC(DX �����Ϸ�)�� ����ϵ��� ����

#include "GaussianSplatting.hlsl"

StructuredBuffer<uint> _OrderBuffer; //���÷����� ������ ������ ����
StructuredBuffer<float3> _NormalVectors; //normal vector���� �����ϴ� ����


struct v2f
{
    half4 col : COLOR0;
    float2 pos : TEXCOORD0;
    float4 vertex : SV_POSITION;
	float3 normal : NORMAL;
};

StructuredBuffer<SplatViewData> _SplatViewData; //�� ���÷��� �� �����͸� �����ϴ� ����ȭ�� ����
ByteAddressBuffer _SplatSelectedBits; // �� ���÷��� ���� ���¸� �����ϴ� ��Ʈ �÷��� ����
uint _SplatBitsValid; //���� ��Ʈ�� ��ȿ���� ���θ� ��Ÿ���� �÷���

// ���� ���� ����
float4 _LightColor;
float4 _LightDirection;
float4 _LightPosition;
float4 _CameraPosition;
float _SpecularIntensity;
float _SpecularPower;

// ���� ���̴� (vert �Լ�)
v2f vert (uint vtxID : SV_VertexID, uint instID : SV_InstanceID)
{
    v2f o = (v2f)0;
    instID = _OrderBuffer[instID];
	SplatViewData view = _SplatViewData[instID];

	o.normal = _NormalVectors[instID]; // fragment shader�� normal vector ����

	float4 centerClipPos = view.pos;
	bool behindCam = centerClipPos.w <= 0;
	if (behindCam)
	{
		o.vertex = asfloat(0x7fc00000); // NaN discards the primitive
	}
	else
	{
		o.col.r = f16tof32(view.color.x >> 16); //���÷��� ������ ����
		o.col.g = f16tof32(view.color.x);
		o.col.b = f16tof32(view.color.y >> 16);
		o.col.a = f16tof32(view.color.y);

		uint idx = vtxID;
		float2 quadPos = float2(idx&1, (idx>>1)&1) * 2.0 - 1.0; //���÷��� ȭ�鿡 �簢������ �׸��� ���� 2D ��ǥ�� ����
		quadPos *= 2;

		o.pos = quadPos;

		float2 deltaScreenPos = (quadPos.x * view.axis1 + quadPos.y * view.axis2) * 2 / _ScreenParams.xy; //ȭ�� �󿡼� ���÷��� ��ġ�� ����
		o.vertex = centerClipPos;
		o.vertex.xy += deltaScreenPos * centerClipPos.w;

		// is this splat selected?
		if (_SplatBitsValid) //Ȱ��ȭ�Ǿ� ������ ���õ� ���÷��� Ȯ���ϰ�, ���õ� ��� ���� ���� -1�� ����
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

// �����׸�Ʈ ���̴� (frag �Լ�)
half4 frag (v2f i) : SV_Target
{
	float power = -dot(i.pos, i.pos); //���÷��� ȭ��󿡼��� ��ġ�� ������� ������ ����. �߽ɿ��� �־������� ������ Ŀ���ٰ� �����
	half alpha = exp(power); // ������ ���÷��� �߽��� �� �������ϰ� �����ڸ��� ������ ������������ ����
	if (i.col.a >= 0)
	{
		alpha = saturate(alpha * i.col.a);
	}
	else // i.col.a ���� ������ ���, ���õ� ���÷��̹Ƿ�
	{
		// "selected" splat: magenta outline, increase opacity, magenta tint
		half3 selectedColor = half3(1,0,1);
		if (alpha > 7.0/255.0)
		{
			if (alpha < 10.0/255.0)
			{
				alpha = 1;
				i.col.rgb = selectedColor; //���õ� ���÷��� ���� �������� ���̰� ����Ƽ�� �������� ����
			}
			alpha = saturate(alpha + 0.3);
		}
		i.col.rgb = lerp(i.col.rgb, selectedColor, 0.5);
	}
	
	
	//�ϴ� directional light object�� ����
	float3 lightDir = normalize(_LightDirection.xyz);
	float3 lightCol = normalize(_LightColor.rgb);

	//point light object�� ����� �Ʒ�ó�� ����
	//float3 currentPos = i.vertex.xyz;
	//float3 lightDir = normalize(_LightPosition.xyz - currentPos);

	//normal vector ���� �ʿ�
	//���� vertex�� ������ vertex�� ����� ���� �ﰢ���� normal vector�� ���ϴ½�����
	float3 normal = i.normal;

	// float3 viewDir = normalize(_CameraPosition - i.worldPos); //ī�޶󿡼� ���÷������� ����
	// float3 reflectDir = reflect(-lightDir, normal); // �ݻ�� ���� ����(���� ǥ�鿡 ��� �ݻ�� ������ ���)

	// diffuse ���
	float diffuse = max(dot(normal, lightDir), 0.0);
	float3 diffuseColor = _LightColor.rgb * diffuse;
	
	// ���ݻ�� (phongshading) ��� �߰�
	// float specular = pow(max(dot(viewDir, reflectDir), 0.0), _SpecularPower); //����ŧ�� ���� ��� (ī�޶� �ü� ����� �ݻ�� ���� ���� ���̿� ���� ���ݻ籤�� ���)
	// float3 specularColor = _LightColor.rgb * specular * _SpecularIntensity; //����ŧ�� ���� ����

	i.col.rgb *= diffuseColor;

	// i.col.rgb *=  (_LightColor.rgb + diffuseColor);
	// i.col.rgb *= (diffuseColor + specularColor);

    if (alpha < 1.0/255.0); //������ 1/255 �����̸� �ش� �����׸�Ʈ�� ���������� ����

    half4 res = half4(i.col.rgb * alpha, alpha);
    return res;
}
ENDCG
        }
    }
}
