# This script uses the Pillow library to generate a full set of poker chip
# textures automatically.

from PIL import Image, ImageDraw, ImageFont, ImageOps

FONT = "../NotoSerifCJKjp-Black.otf"
FONT_SIZE = 80
SIZE = (200, 200)
VERTICAL_CORRECTION = -16

BACKGROUND_COLOURS = {
    1: "#ffffffff",
    5: "#ff0000ff",
    10: "#0000ffff",
    25: "#00ff00ff",
    100: "#000000ff"
}

FOREGROUND_COLOURS = {
    1: "#000000ff",
    5: "#ffffffff",
    10: "#ffffffff",
    25: "#000000ff",
    100: "#ffffffff",
}

def create_chip_image(amount, font):
    
    image = Image.new("RGBA", SIZE)
    draw = ImageDraw.Draw(image)

    draw.ellipse([(0, 0), SIZE], fill=BACKGROUND_COLOURS[amount])
    
    size = draw.textsize(str(amount), font=font)
    draw.text(((SIZE[0] - size[0])/2, (SIZE[1] - size[1])/2 + VERTICAL_CORRECTION), str(amount), fill=FOREGROUND_COLOURS[amount], font=font)

    opposite = image.copy()
    image = ImageOps.pad(image, (SIZE[0]*2, SIZE[1]), centering=(0, 0.5))
    opposite = ImageOps.pad(opposite, (SIZE[0]*2, SIZE[1]), centering=(1, 0.5))

    image = Image.alpha_composite(image, opposite)
    image = ImageOps.pad(image, (SIZE[0]*2, SIZE[1]*2), centering=(0.5, 1))
    draw = ImageDraw.Draw(image)

    draw.rectangle([(0, 0), (SIZE[0]*2, SIZE[1])], fill=BACKGROUND_COLOURS[amount])

    image.save(str(amount) + ".png")

font = ImageFont.truetype(FONT, FONT_SIZE)

for amount in [1, 5, 10, 25, 100]:
    create_chip_image(amount, font)
