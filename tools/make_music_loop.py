"""Cut a seamless music loop out of a full-length track and write it as OGG.

  python tools/make_music_loop.py <in.wav|mp3> <out.ogg> [--min 45] [--max 110] [--start-after 0.5] [--report] [--keep-intro]

--keep-intro: write the track from its very beginning to the loop end, so
the intro plays once; the printed LOOP OFFSET (seconds) is where the
engine should jump back to (Audio's MUSIC entry "loop_offset").

How it picks the loop (no listening involved, so it goes by the numbers):
  1. Beat grid: an onset envelope (spectral flux) autocorrelated over 60-180
     BPM gives the tempo; beats are then placed by tracking the envelope.
  2. Loop START = the first strong beat after --start-after seconds (skips a
     soft intro swell).
  3. Loop END = the beat, a whole number of 4-bar phrases later and between
     --min and --max seconds long, whose lead-in (the four beats before it)
     sounds most like the lead-in to the start - measured on log spectra -
     so the music arriving at the join matches the music leaving it.
  4. Seam: the last 60 ms of the loop crossfade into the audio that naturally
     precedes the start, so the restart continues without a click.
  5. Peak-normalised to -1 dBFS, written as OGG Vorbis (quality ~0.6).

Prints tempo, the chosen points and how good the join is (lower is better;
under ~0.25 is a musical match, above ~0.5 is a jump).
"""
import sys
import numpy as np
import soundfile as sf


def onset_envelope(mono, sr, hop=512, win=2048):
    n = (len(mono) - win) // hop
    window = np.hanning(win)
    prev = None
    env = np.zeros(n)
    for i in range(n):
        frame = mono[i * hop:i * hop + win] * window
        mag = np.abs(np.fft.rfft(frame))
        mag = np.log1p(mag)
        if prev is not None:
            env[i] = np.maximum(mag - prev, 0.0).sum()
        prev = mag
    env -= env.mean()
    env /= (env.std() + 1e-9)
    return env, sr / hop


def estimate_tempo(env, fps, lo=60.0, hi=180.0):
    lag_min = int(fps * 60.0 / hi)
    lag_max = int(fps * 60.0 / lo)
    best, best_lag = -1e9, lag_min
    for lag in range(lag_min, lag_max + 1):
        c = np.dot(env[:-lag], env[lag:]) / (len(env) - lag)
        # favour moderate tempos slightly against their double/half
        if c > best:
            best, best_lag = c, lag
    return 60.0 * fps / best_lag, best_lag


def track_beats(env, fps, lag):
    """Greedy beat tracking: start at the strongest onset in the first two
    bars, then step one period at a time snapping to the nearest peak."""
    first = int(np.argmax(env[:lag * 8]))
    beats = [first]
    tol = max(2, lag // 8)
    while beats[-1] + lag < len(env):
        target = beats[-1] + lag
        lo, hi = max(0, target - tol), min(len(env), target + tol + 1)
        beats.append(lo + int(np.argmax(env[lo:hi])))
    return np.array(beats)


def features(mono, sr, centre, win=4096):
    a = max(0, centre - win // 2)
    frame = mono[a:a + win]
    if len(frame) < win:
        frame = np.pad(frame, (0, win - len(frame)))
    mag = np.log1p(np.abs(np.fft.rfft(frame * np.hanning(win))))
    return mag / (np.linalg.norm(mag) + 1e-9)


def main():
    args = sys.argv[1:]
    opts = {"--min": 45.0, "--max": 110.0, "--start-after": 0.5}
    for k in list(opts):
        if k in args:
            i = args.index(k)
            opts[k] = float(args[i + 1])
            del args[i:i + 2]
    report = "--report" in args
    if report:
        args.remove("--report")
    keep_intro = "--keep-intro" in args
    if keep_intro:
        args.remove("--keep-intro")
    src, dst = args
    audio, sr = sf.read(src, dtype="float32", always_2d=True)
    mono = audio.mean(axis=1)
    env, fps = onset_envelope(mono, sr)
    bpm, lag = estimate_tempo(env, fps)
    beats = track_beats(env, fps, lag)
    beat_samples = (beats * sr / fps).astype(int)
    print("duration %.1f s, %d Hz, tempo ~%.1f BPM, %d beats tracked" % (len(mono) / sr, sr, bpm, len(beats)))

    # loop start: the first beat (with four beats of lead-in before it, and
    # on a 4-bar phrase boundary from the first beat) where the music has
    # arrived - the bar after it is at least 70% as loud as the track's
    # median bar - so a soft intro swell is skipped rather than looped.
    beat_len = beat_samples[1] - beat_samples[0]
    bar_rms = []
    for i in range(len(beats) - 4):
        seg = mono[beat_samples[i]:beat_samples[i] + 4 * beat_len]
        bar_rms.append(np.sqrt((seg ** 2).mean()) if len(seg) else 0.0)
    bar_rms = np.array(bar_rms)
    median_bar = np.median(bar_rms[bar_rms > 0])
    start_i = None
    for i in range(4, len(bar_rms)):
        if (i % 16) == 0 and beats[i] / fps >= opts["--start-after"] and bar_rms[i] >= 0.7 * median_bar:
            start_i = i
            break
    if start_i is None:
        start_i = 16
    start = beat_samples[start_i]
    lead_in = [features(mono, sr, beat_samples[start_i - k]) for k in range(1, 5)]

    best = None
    for end_i in range(start_i + 16, len(beats)):
        if (end_i - start_i) % 16 != 0:  # whole 4-bar phrases (4/4)
            continue
        length = (beat_samples[end_i] - start) / sr
        if length < opts["--min"]:
            continue
        if length > opts["--max"]:
            break
        lead = [features(mono, sr, beat_samples[end_i - k]) for k in range(1, 5)]
        dist = float(np.mean([np.linalg.norm(a - b) for a, b in zip(lead_in, lead)]))
        # the exact join: last 50 ms before end vs last 50 ms before start
        w = int(sr * 0.05)
        tail = mono[beat_samples[end_i] - w:beat_samples[end_i]]
        pre = mono[start - w:start]
        rms_gap = abs(np.sqrt((tail ** 2).mean()) - np.sqrt((pre ** 2).mean()))
        score = dist + rms_gap * 2.0
        if report:
            print("  candidate end beat %d at %.2f s (loop %.1f s): lead-in distance %.3f, level gap %.3f" % (end_i, beat_samples[end_i] / sr, length, dist, rms_gap))
        if best is None or score < best[0]:
            best = (score, end_i, dist)
    if best is None:
        raise SystemExit("no loop candidate in the length range - widen --min/--max")
    score, end_i, dist = best
    end = beat_samples[end_i]
    file_start = 0 if keep_intro else start
    loop = audio[file_start:end].copy()
    # seam: fade the tail into the natural lead-in to the loop start
    fade = int(sr * 0.06)
    pre = audio[start - fade:start]
    t = np.linspace(0.0, 1.0, fade, dtype=np.float32)[:, None]
    loop[-fade:] = loop[-fade:] * np.cos(t * np.pi / 2) + pre * np.sin(t * np.pi / 2)
    peak = float(np.abs(loop).max())
    loop *= (10 ** (-1.0 / 20.0)) / max(peak, 1e-6)
    # libsndfile's Vorbis writer crashed on a minute-long stereo loop, so
    # write a WAV and let the bundled ffmpeg (imageio-ffmpeg) encode the OGG.
    import os, subprocess, tempfile
    tmp = os.path.join(tempfile.gettempdir(), "music_loop_tmp.wav")
    sf.write(tmp, loop, sr, subtype="PCM_16")
    try:
        import imageio_ffmpeg
        ffmpeg = imageio_ffmpeg.get_ffmpeg_exe()
        subprocess.run([ffmpeg, "-y", "-loglevel", "error", "-i", tmp, "-c:a", "libvorbis", "-q:a", "5", dst], check=True)
    except ImportError:
        sf.write(dst, loop, sr, format="OGG", subtype="VORBIS")
    print("loop: start %.2f s (beat %d) -> end %.2f s (beat %d), %.1f s long, join score %.3f, peak normalised from %.2f" % (start / sr, start_i, end / sr, end_i, (end - start) / sr, score, peak))
    if keep_intro:
        print("LOOP OFFSET %.3f s (intro kept: file runs %.1f s, repeats from the offset)" % (start / sr, (end - file_start) / sr))
    print("wrote", dst)


if __name__ == "__main__":
    main()
