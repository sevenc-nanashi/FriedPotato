require "dxruby"
require "httparty"

base = Image.load("bg_gen/background-base.png")

core_mask = Shader::Core.new(File.read("bg_gen/mask.hlsl"), { mask: :texture, alpha: :float })
core_sub = Shader::Core.new(File.read("bg_gen/sub.hlsl"), { mask: :texture, alpha: :float })

jacket = Image.load_from_file_in_memory(
  HTTParty.get("https://servers.purplepalette.net/repository/#{name}/cover.png").body
)
mask_img = Image.load("bg_gen/mask-white.png")
mask_img_sub = base
dot_tile = Image.load("bg_gen/dot-tile.png")
mask = Shader.new(core_mask, "render_alpha")
mask.mask = mask_img
mask.alpha = 0.3

side_mask = Shader.new(core_mask, "render_alpha")
side_mask.mask = Image.load("bg_gen/side-mask.png")
side_mask.alpha = 0.8

bottom_mask = Shader.new(core_mask, "render_red")
bottom_mask.mask = Image.load("bg_gen/bottom_mask.png")
bottom_mask.alpha = 0.7

sub_mask = Shader.new(core_sub)
sub_mask.mask = mask_img_sub
sub_mask.alpha = 0.8

orig = Image.load("bg_gen/orig.jpg")

rt = RenderTarget.new(base.width, base.height)
center_rt = RenderTarget.new(base.width, base.height)
side_rt = RenderTarget.new(base.width, base.height)
side_sub_rt = RenderTarget.new(base.width, base.height)
bottom_rt = RenderTarget.new(base.width, base.height)
bottom_trans_rt = RenderTarget.new(base.width, base.height)
final_rt = RenderTarget.new(orig.width, orig.height)

# 795 1255/193
# 804 1245/628

rt.draw(0, 0, base)

center_rt.draw_morph(798, 193, 1252, 193, 1246, 635, 801, 635, jacket)

rt.draw_shader(0, 0, center_rt, sub_mask)

#449,194 : 1136,99 : 1152, 789 : 465 804

side_rt.draw_morph(449, 114, 1136, 99, 1152, 789, 465, 804, jacket)

# 1040, 145 : 1663, 70 : 1619, 707 : 1628, 622

side_rt.draw_morph(1018, 92, 1635, 51, 1630, 740, 1026, 756, jacket)

side_sub_rt.draw_shader(0, 0, side_rt, side_mask)

rt.draw_shader(0, 0, side_sub_rt, sub_mask)
# rt.draw(0, 0, rt4)

bottom_rt.draw_morph(795, 1152, 1252, 1152, 1252, 713, 795, 713, jacket)

bottom_trans_rt.draw_shader(0, 0, bottom_rt, bottom_mask)
# bottom_trans_rt.draw_alpha(0, 0, bottom_rt, 256 * 0.)

rt.draw(0, 0, bottom_trans_rt)

rt.draw_shader(0, 0, dot_tile, mask)

final_rt.draw(orig.width - base.width, (orig.height - base.height) / 2, rt)

final_rt.to_image.save("dist/#{name}.png")
