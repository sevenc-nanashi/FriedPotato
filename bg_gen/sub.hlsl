texture tex0;
texture mask;
float alpha;

sampler Samp0 = sampler_state { Texture = <tex0>; };

sampler Samp1 = sampler_state { Texture = <mask>; };

float4 PS(float2 input : TEXCOORD0) : COLOR0 {
  float4 output;
  float4 output2;
  float4 output3;
  float tmpalpha;

  output = tex2D(Samp0, input);
  output2 = tex2D(Samp1, input);
  output3 = 0, 0, 0, 0;
  tmpalpha = (output2.r + output2.g + output2.b) / 3.0;
  // output3.r = output.r * (1.0 - tmpalpha);
  // output3.g = output.g * (1.0 - tmpalpha);
  // output3.b = output.b * (1.0 - tmpalpha);
  // output3.a = output.a;
  output.a *= 1.0 - tmpalpha * 3;
  output.a *= alpha;
  // output.rgb = 1.0 - tmpalpha * alpha;
  return output;
}

technique {
  pass { PixelShader = compile ps_2_0 PS(); }
}