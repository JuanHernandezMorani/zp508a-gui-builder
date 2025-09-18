import sys, os, struct
from PIL import Image, ImageDraw

def parse_spr_header(f):
    ident = f.read(4)
    if ident != b'IDSP':
        raise ValueError("Not a valid Half-Life SPR file")
    version = struct.unpack('i', f.read(4))[0]
    if version not in (2,):  # HL usa v2 casi siempre
        raise ValueError(f"Unsupported SPR version: {version}")
    header = {
        "version": version,
        "type": struct.unpack('i', f.read(4))[0],
        "tex_format": struct.unpack('i', f.read(4))[0],
        "radius": struct.unpack('f', f.read(4))[0],
        "width": struct.unpack('i', f.read(4))[0],
        "height": struct.unpack('i', f.read(4))[0],
        "frames": struct.unpack('i', f.read(4))[0],
    }
    f.read(8)  # beamlen+synctype
    return header

def spr2png(spr_path, png_path):
    try:
        os.makedirs(os.path.dirname(png_path), exist_ok=True)
        with open(spr_path, "rb") as f:
            header = parse_spr_header(f)

        # Placeholder seguro
        img = Image.new("RGB", (header["width"], header["height"]), (50, 50, 70))
        draw = ImageDraw.Draw(img)
        draw.text((5, 5), f"SPR {header['width']}x{header['height']}", fill=(255, 255, 0))
        draw.text((5, 20), f"Frames: {header['frames']}", fill=(200, 200, 200))
        img.save(png_path, "PNG")
        return True

    except Exception as e:
        os.makedirs(os.path.dirname(png_path), exist_ok=True)
        img = Image.new("RGB", (200, 200), (40, 0, 0))
        draw = ImageDraw.Draw(img)
        draw.text((10, 90), "SPR Error", fill=(255, 255, 255))
        draw.text((10, 110), str(e), fill=(255, 255, 0))
        img.save(png_path, "PNG")
        return False

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: spr2png.py <input.spr> <output.png>")
        sys.exit(1)
    spr2png(sys.argv[1], sys.argv[2])
