require "dxruby"

dot = Image.load("dot.png")
base = Image.load("background-base.png")
target = RenderTarget.new(base.width, base.height)

target.draw_tile(0, 0, [[0]], [dot], 0, 0, base.width, base.height)

target.to_image.save("dot-tile.png")

puts "done"
