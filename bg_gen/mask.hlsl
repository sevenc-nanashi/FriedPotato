texture tex0;
texture mask;
float alpha;

sampler Samp0 = sampler_state { Texture = <tex0>; };

sampler Samp1 = sampler_state { Texture = <mask>; };

float4 PS(float2 input : TEXCOORD0) : COLOR0 {
  float4 output;
  float4 mask;

  output = tex2D(Samp0, input);
  mask = tex2D(Samp1, input);
  output.a *= mask.a * alpha;
  return output;
}

float4 PS2(float2 input : TEXCOORD0) : COLOR0 {
  float4 output;
  float4 mask;

  output = tex2D(Samp0, input);
  mask = tex2D(Samp1, input);
  output.a *= mask.r * alpha;
  return output;
}
technique render_alpha {
  pass { PixelShader = compile ps_2_0 PS(); }
}
technique render_red {
  pass { PixelShader = compile ps_2_0 PS2(); }
}