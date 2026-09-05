"""Prepare a sound effect for the game: trim leading/trailing silence,
peak-normalise to -3 dBFS, write 16-bit mono WAV (Godot imports it as an
AudioStreamWAV, which also plays through the web build's sample path).

  python tools/make_sfx.py <in.wav> <out.wav> [--gain-db -3] [--max 3.0]
"""
import sys
import numpy as np
import soundfile as sf


def main():
    args = sys.argv[1:]
    gain_db = -3.0
    max_s = 3.0
    if "--gain-db" in args:
        i = args.index("--gain-db"); gain_db = float(args[i + 1]); del args[i:i + 2]
    if "--max" in args:
        i = args.index("--max"); max_s = float(args[i + 1]); del args[i:i + 2]
    src, dst = args
    audio, sr = sf.read(src, dtype="float32", always_2d=True)
    mono = audio.mean(axis=1)
    thresh = 10 ** (-50.0 / 20.0)
    loud = np.where(np.abs(mono) > thresh)[0]
    if len(loud) == 0:
        raise SystemExit("silent file")
    s0 = max(0, int(loud[0]) - int(sr * 0.005))
    s1 = min(len(mono), int(loud[-1]) + int(sr * 0.05), s0 + int(sr * max_s))
    clip = mono[s0:s1].copy()
    # tiny fades so the ends never click
    f = min(int(sr * 0.004), len(clip) // 4)
    if f > 0:
        clip[:f] *= np.linspace(0.0, 1.0, f, dtype=np.float32)
        clip[-f:] *= np.linspace(1.0, 0.0, f, dtype=np.float32)
    peak = float(np.abs(clip).max())
    clip *= (10 ** (gain_db / 20.0)) / max(peak, 1e-6)
    sf.write(dst, clip, sr, subtype="PCM_16")
    print("%s: %.3f s, %d Hz, peak %.2f -> %.1f dBFS, wrote %s" % (src.split("\\")[-1], len(clip) / sr, sr, peak, gain_db, dst))


if __name__ == "__main__":
    main()
