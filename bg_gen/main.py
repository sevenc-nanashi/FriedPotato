import os
from PIL import Image, ImageOps
from io import BytesIO
import requests
from flask import Flask
import sys

dir = os.path.dirname(__file__)
base_normal = Image.open(dir + "/background-base.png")
base_extra = Image.open(dir + "/background-base-extra.png")
mask_img = Image.open(dir + "/mask.png").convert("L")
side_mask = Image.open(dir + "/side-mask.png")
dot_tile = Image.open(dir + "/dot-tilea.png")


def alpha(img, al):
    imga = img.copy()
    imga.putalpha(round(255 * al))
    return imga


class Deformer:
    def __init__(self, dist):
        self.dist = dist

    def getmesh(self, im):
        return [((0, 0, *im.size), self.dist)]


app = Flask(__name__)


@app.route("/generate/<string:name>")
def generate(name: str):
    base_name = name.removesuffix(".extra")
    if os.path.exists(path := (dir + f"/../overrides/{base_name}/thumbnail.png")):
        jacket = Image.open(path)
    else:
        if name.startswith("l_"):
            url = f"https://PurplePalette.github.io/sonolus/repository/levels/{base_name[2:]}/jacket.jpg"
        else:
            url = f"https://servers.purplepalette.net/repository/{base_name}/cover.png"
        response = requests.get(url)
        jacket = Image.open(BytesIO(response.content))
    jacket.convert("RGBA")
    if name.endswith(".extra"):
        base = base_extra.copy().convert("RGBA")
    else:
        base = base_normal.copy().convert("RGBA")
    base2 = Image.new("RGBA", base.size, (0, 0, 0, 0))
    base3 = Image.new("RGBA", base.size, (0, 0, 0, 0))
    shift = -30
    base3.paste(
        alpha(
            ImageOps.deform(
                jacket,
                deformer=Deformer(
                    (0, 0, 0, jacket.height, jacket.width, jacket.height - shift * 2, jacket.width, -shift * 2)
                ),
            ).resize((650, 650)),
            0.8,
        ),
        (461, 135),
    )
    base3.paste(
        alpha(
            ImageOps.deform(
                jacket,
                deformer=Deformer(
                    (0, 0, 0, jacket.height, jacket.width, jacket.height - shift * 2, jacket.width, -shift * 2)
                ),
            ).resize((700, 700)),
            0.8,
        ),
        (939, 80),
    )
    shift = 10
    base2.paste(
        alpha(
            ImageOps.deform(
                jacket,
                deformer=Deformer((0, 0, -shift, jacket.height, jacket.width + shift, jacket.height, jacket.width, 0)),
            ).resize((470, 450)),
            0.8,
        ),
        (787, 189),
    )
    base2.paste(
        alpha(
            ImageOps.deform(
                jacket,
                deformer=Deformer((0, jacket.height, -shift, 0, jacket.width + shift, 0, jacket.width, jacket.height)),
            ).resize((450, 450)),
            0.7,
        ),
        (797, 683),
    )

    # base.save(dir + f"/../dist/bg/{name}.png")
    # base.paste(base2, (0, 0), mask=mask_img)
    buffer = Image.alpha_composite(base, base2)
    buffer.paste(base3, (0, 0), mask=side_mask)
    buffer = Image.alpha_composite(buffer, dot_tile)
    res = Image.new("RGBA", mask_img.size)
    diff = (buffer.height - mask_img.height) // 2
    # print(buffer.crop((0, diff, base.width, base.height - diff)).size, mask_img.size)
    res.paste(base.crop((0, diff, base.width, base.height - diff - 1)), (0, 0))
    res.paste(buffer.crop((0, diff, base.width, base.height - diff - 1)), (0, 0), mask=mask_img)
    res.save(dir + f"/../dist/bg/{name}.png")

    return {"status": "ok"}

app.run(port=int(sys.argv[1]))
