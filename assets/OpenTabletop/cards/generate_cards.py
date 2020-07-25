# This script uses the Pillow library to generate a full set of playing card
# textures automatically.

from PIL import Image, ImageDraw, ImageFont, ImageOps

FONT = "NotoSerifCJKjp-Black.otf"
FONT_SIZE_LARGE = 100
FONT_SIZE_SMALL = 50
MARGIN = 10
SIZE = (250, 350)
VERTICAL_CORRECTION = -15

LONG_NAMES = {
    "A": "Ace",
    "2": "Two",
    "3": "Three",
    "4": "Four",
    "5": "Five",
    "6": "Six",
    "7": "Seven",
    "8": "Eight",
    "9": "Nine",
    "10": "Ten",
    "J": "Jack",
    "Q": "Queen",
    "K": "King",
    "♠": "Spades",
    "♥": "Hearts",
    "♦": "Diamonds",
    "♣": "Clubs"
}

def create_card_image(number, suit, large_font, small_font):

    image = Image.new("RGBA", SIZE)
    draw = ImageDraw.Draw(image)

    draw.rectangle([(0, 0), (SIZE[0]/2, SIZE[1])], fill="#ffffffff")

    color = "#000000ff"
    if suit == "♥" or suit == "♦":
        color = "#ff0000ff"

    draw.text((MARGIN, MARGIN), number + "\n" + suit, align="center", fill=color, font=small_font)

    flipped = ImageOps.flip(image)
    flipped = ImageOps.mirror(flipped)
    image = Image.alpha_composite(image, flipped)
    draw = ImageDraw.Draw(image)

    size = draw.textsize(suit, font=large_font)
    draw.text(((SIZE[0]-size[0])/2, (SIZE[1]-size[1])/2 + VERTICAL_CORRECTION), suit, fill=color, font=large_font)

    image = ImageOps.pad(image, (SIZE[0]*2, SIZE[1]), color="#ff0000ff", centering=(0, 0.5))

    file_name = LONG_NAMES[number] + " of " + LONG_NAMES[suit] + ".png"
    print("    \"" + file_name + "\",")

    image.save(file_name)

large_font = ImageFont.truetype(FONT, FONT_SIZE_LARGE)
small_font = ImageFont.truetype(FONT, FONT_SIZE_SMALL)

print("[")

for suit in ["♠", "♥", "♦", "♣"]:
    for number in range(1, 14):
        number = str(number)

        if number == "1":
            number = "A"
        elif number == "11":
            number = "J"
        elif number == "12":
            number = "Q"
        elif number == "13":
            number = "K"

        create_card_image(number, suit, large_font, small_font)

print("]")
