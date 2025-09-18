import sys, os, struct
from PIL import Image, ImageDraw

def parse_mdl_header(f):
    ident = f.read(4)
    if ident != b'IDST':
        raise ValueError("Not a valid Half-Life MDL file")
    version = struct.unpack('i', f.read(4))[0]
    if version not in (10, 11):  # HL suele usar 10, algunos 11
        raise ValueError(f"Unsupported MDL version: {version}")
    return {"ident": ident, "version": version}

def mdl2png(mdl_path, png_path):
    try:
        os.makedirs(os.path.dirname(png_path), exist_ok=True)

        with open(mdl_path, 'rb') as f:
            header = parse_mdl_header(f)

        # Placeholder preview con info
        img = Image.new("RGB", (200, 200), (30, 30, 40))
        draw = ImageDraw.Draw(img)
        draw.text((10, 10), f"MDL v{header['version']}", fill=(200, 200, 255))
        draw.text((10, 30), os.path.basename(mdl_path), fill=(200, 200, 0))
        img.save(png_path, "PNG")
        return True

    except Exception as e:
        os.makedirs(os.path.dirname(png_path), exist_ok=True)
        img = Image.new("RGB", (200, 200), (40, 0, 0))
        draw = ImageDraw.Draw(img)
        draw.text((10, 90), f"MDL Error", fill=(255, 255, 255))
        draw.text((10, 110), str(e), fill=(255, 255, 0))
        img.save(png_path, "PNG")
        return False

if __name__ == "__main__":
    if len(sys.argv) != 2 and len(sys.argv) != 3:
        print("Usage: mdl2png.py <input.mdl> <output.png>")
        sys.exit(1)
    mdl2png(sys.argv[1], sys.argv[2])
