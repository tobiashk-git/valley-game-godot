"""Trim a one-shot sting (victory fanfare, jingle) out of a generated track.

  python tools/make_sting.py <in.wav> <out.ogg> [--max 8]

Takes the audio from its first sound to the point the level has died away
after the loudest part (capped at --max seconds), fades the last 250 ms
out, peak-normalises to -1 dBFS and writes OGG via the bundled ffmpeg.
"""
import os, subprocess, sys, tempfile
import numpy as np
import soundfile as sf


def main():
    args = sys.argv[1:]
    max_s = 8.0
    if "--max" in args:
        i = args.index("--max")
        max_s = float(args[i + 1])
        del args[i:i + 2]
    src, dst = args
    audio, sr = sf.read(src, dtype="float32", always_2d=True)
    mono = np.abs(audio).mean(axis=1)
    # 20 ms RMS envelope
    hop = int(sr * 0.02)
    env = np.array([np.sqrt((mono[i:i + hop] ** 2).mean()) for i in range(0, len(mono) - hop, hop)])
    db = 20 * np.log10(np.maximum(env, 1e-6))
    start = int(np.argmax(db > -35.0))
    peak_i = int(np.argmax(db))
    end = peak_i
    quiet = 0
    for i in range(peak_i, len(db)):
        if db[i] < db[peak_i] - 30.0:
            quiet += 1
            if quiet >= 10:  # 200 ms of quiet after the peak
                end = i
                break
        else:
            quiet = 0
            end = i
    s0 = start * hop
    s1 = min(len(mono), (end + 1) * hop + int(sr * 0.2), s0 + int(sr * max_s))
    clip = audio[s0:s1].copy()
    fade = min(int(sr * 0.25), len(clip))
    ramp = np.linspace(1.0, 0.0, fade, dtype=np.float32)[:, None]
    clip[-fade:] *= ramp
    peak = float(np.abs(clip).max())
    clip *= (10 ** (-1.0 / 20.0)) / max(peak, 1e-6)
    tmp = os.path.join(tempfile.gettempdir(), "sting_tmp.wav")
    sf.write(tmp, clip, sr, subtype="PCM_16")
    import imageio_ffmpeg
    subprocess.run([imageio_ffmpeg.get_ffmpeg_exe(), "-y", "-loglevel", "error", "-i", tmp, "-c:a", "libvorbis", "-q:a", "5", dst], check=True)
    print("source %.1f s -> sting %.2f s (from %.2f s), peak was %.2f" % (len(mono) / sr, len(clip) / sr, s0 / sr, peak))
    print("wrote", dst)


if __name__ == "__main__":
    main()
