import sys, os, wave, numpy as np
from PIL import Image, ImageDraw

def wav2waveform(wav_path, png_path):
    try:
        os.makedirs(os.path.dirname(png_path), exist_ok=True)

        with wave.open(wav_path, "rb") as w:
            n_channels = w.getnchannels()
            sampwidth = w.getsampwidth()
            framerate = w.getframerate()
            n_frames = w.getnframes()
            frames = w.readframes(min(n_frames, 200000))  # limitar para no explotar RAM

        if sampwidth == 1:
            data = np.frombuffer(frames, dtype=np.uint8).astype(np.int16) - 128
        elif sampwidth == 2:
            data = np.frombuffer(frames, dtype=np.int16)
        else:
            data = np.frombuffer(frames, dtype=np.int16)

        if n_channels > 1:
            data = data.reshape(-1, n_channels).mean(axis=1)

        img = Image.new("RGB", (800, 300), (20, 20, 30))
        draw = ImageDraw.Draw(img)
        if len(data) > 0:
            data = data / (np.max(np.abs(data)) or 1)
            step = max(1, len(data) // 800)
            for x in range(800):
                seg = data[x*step:(x+1)*step]
                if len(seg) == 0: continue
                vmin, vmax = np.min(seg), np.max(seg)
                y1 = int((1-vmax)*150)
                y2 = int((1-vmin)*150)
                draw.line([(x, y1), (x, y2)], fill=(0,200,255))
        img.save(png_path, "PNG")
        return True

    except Exception as e:
        os.makedirs(os.path.dirname(png_path), exist_ok=True)
        img = Image.new("RGB", (400, 100), (40, 0, 0))
        draw = ImageDraw.Draw(img)
        draw.text((10, 40), f"WAV Error: {str(e)}", fill=(255,255,0))
        img.save(png_path, "PNG")
        return False

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: wav2waveform.py <input.wav> <output.png>")
        sys.exit(1)
    wav2waveform(sys.argv[1], sys.argv[2])
