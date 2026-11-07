#!/usr/bin/env python3
"""Synthesises PLACEHOLDER sound effects into assets/audio/sfx/ so the
sound system works before real sounds exist. Replace any file with a real
sound of the same name (WAV or same-name MP3 after changing Sfx.file).

Usage: python3 tools/audio/make_placeholder_sfx.py <project_root>
"""
import sys
import wave
from pathlib import Path

import numpy as np

SR = 22050
rng = np.random.default_rng(7)


def t(sec):
    return np.arange(int(SR * sec)) / SR


def env(n, attack=0.005, decay=0.15):
    x = np.arange(n) / SR
    a = np.clip(x / max(attack, 1e-4), 0, 1)
    return a * np.exp(-np.maximum(x - attack, 0) / decay)


def lowpass(x, cutoff):
    a = np.exp(-2 * np.pi * cutoff / SR)
    y = np.zeros_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc = (1 - a) * v + a * acc
        y[i] = acc
    return y


def highpass(x, cutoff):
    return x - lowpass(x, cutoff)


def noise(sec):
    return rng.uniform(-1, 1, int(SR * sec))


def tone(freq, sec, kind="sine"):
    ph = 2 * np.pi * np.cumsum(np.broadcast_to(freq, int(SR * sec)) / SR)
    if kind == "square":
        return np.sign(np.sin(ph))
    if kind == "saw":
        return 2 * ((ph / (2 * np.pi)) % 1) - 1
    return np.sin(ph)


def sweep(f0, f1, sec):
    return np.linspace(f0, f1, int(SR * sec))


def pluck(freq, sec, damp=0.996):
    n = int(SR * sec)
    p = int(SR / freq)
    buf = rng.uniform(-1, 1, p)
    out = np.zeros(n)
    for i in range(n):
        out[i] = buf[i % p]
        buf[i % p] = damp * 0.5 * (buf[i % p] + buf[(i + 1) % p])
    return out


def mix(*parts):
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[: len(p)] += p
    return out


def at(x, sec):
    return np.concatenate([np.zeros(int(SR * sec)), x])


def thud(freq=110, sec=0.25, decay=0.08):
    return tone(sweep(freq * 1.6, freq * 0.7, sec), sec) * env(int(SR * sec), 0.002, decay)


def whoosh(sec=0.22, lo=400, hi=2200):
    n = noise(sec)
    b = highpass(lowpass(n, hi), lo)
    shape = np.sin(np.linspace(0, np.pi, len(b))) ** 2
    return b * shape * 1.6


def chord(freqs, sec, decay=0.5):
    return sum(tone(f, sec) for f in freqs) / len(freqs) * env(int(SR * sec), 0.01, decay)


def sounds():
    s = {}
    s["tap"] = tone(sweep(1400, 900, 0.05), 0.05) * env(int(SR * 0.05), 0.001, 0.015) * 0.6
    s["denied"] = mix(tone(160, 0.09, "square") * env(int(SR * .09), .002, .05) * .4,
                      at(tone(130, 0.11, "square") * env(int(SR * .11), .002, .06) * .4, 0.1))
    s["train"] = tone(sweep(500, 900, 0.09), 0.09) * env(int(SR * .09), .003, .04) * .7
    s["swing_light"] = whoosh(0.16, 700, 3000)
    s["swing_heavy"] = mix(whoosh(0.26, 250, 1400) * 1.2, at(thud(90, .2, .06) * .5, .18))
    s["throw_stone"] = whoosh(0.14, 900, 3500) * .8
    s["catapult"] = mix(lowpass(tone(70, .18, "saw"), 600) * env(int(SR * .18), .01, .08) * .6,
                        at(whoosh(.3, 300, 1800), .08))
    s["bow"] = mix(pluck(196, .35, .993) * env(int(SR * .35), .001, .12) * .9, whoosh(.12, 1500, 5000) * .3)
    s["ballista"] = mix(pluck(98, .45, .995) * env(int(SR * .45), .001, .15), at(thud(70, .25, .07) * .6, .02),
                        whoosh(.2, 600, 2500) * .4)
    crack = highpass(noise(.12), 1800) * env(int(SR * .12), .0005, .025)
    s["musket"] = mix(crack * 1.2, thud(160, .18, .05) * .6, at(lowpass(noise(.3), 1500) * env(int(SR * .3), .01, .1) * .3, .03))
    s["cannon"] = mix(thud(48, 1.0, .32) * 1.4, lowpass(noise(.9), 700) * env(int(SR * .9), .002, .28),
                      highpass(noise(.06), 2500) * env(int(SR * .06), .0005, .015) * .5)
    burst = np.zeros(int(SR * 0.5))
    for k in range(6):
        c = mix(crack * .9, thud(170, .08, .03) * .5)
        o = int(SR * k * 0.07)
        burst[o:o + len(c)] += c[: len(burst) - o]
    s["machine_gun"] = burst
    s["tank_gun"] = mix(thud(40, 1.1, .35) * 1.5, lowpass(noise(1.0), 600) * env(int(SR * 1.0), .002, .3),
                        highpass(noise(.08), 2000) * env(int(SR * .08), .0005, .02) * .7)
    s["rocket"] = mix(lowpass(noise(.7), 2500) * env(int(SR * .7), .01, .25) * .8, whoosh(.6, 400, 3000) * .7,
                      thud(90, .2, .05) * .5)
    s["flame"] = lowpass(noise(1.0), 1200) * np.sin(np.linspace(0, np.pi, int(SR * 1.0))) ** .5 * .8
    spin = np.zeros(int(SR * 0.9))
    for k in range(14):
        c = mix(crack * .6, thud(150, .05, .02) * .4)
        o = int(SR * k * 0.055)
        spin[o:o + len(c)] += c[: len(spin) - o]
    s["minigun"] = mix(spin, tone(sweep(120, 300, .9), .9, "saw") * .08)
    s["jet"] = lowpass(noise(1.6), 1800) * np.sin(np.linspace(0, np.pi, int(SR * 1.6))) ** 2 * .9
    s["hit"] = mix(thud(140, .14, .04), lowpass(noise(.06), 2500) * env(int(SR * .06), .001, .015) * .7)
    s["death"] = mix(thud(80, .35, .12), tone(sweep(300, 120, .3), .3) * env(int(SR * .3), .01, .12) * .25)
    s["coin"] = mix(tone(1320, .08) * env(int(SR * .08), .001, .04), at(tone(1760, .16) * env(int(SR * .16), .001, .07), .06)) * .5
    s["base_hit"] = mix(thud(60, .45, .15) * 1.2, lowpass(noise(.4), 900) * env(int(SR * .4), .005, .12) * .6)
    s["meteor_cast"] = mix(lowpass(noise(1.0), sweep(300, 2500, 1.0).mean()) * np.linspace(0, 1, int(SR * 1.0)) ** 2 * .8,
                           tone(sweep(80, 160, 1.0), 1.0) * .2)
    s["meteor_impact"] = mix(thud(45, .9, .3) * 1.3, lowpass(noise(.8), 1200) * env(int(SR * .8), .003, .25))
    vol = np.zeros(int(SR * 0.9))
    for k in range(7):
        w = whoosh(.25, 900, 4000) * .5
        o = int(SR * k * 0.08)
        vol[o:o + len(w)] += w[: len(vol) - o]
    s["volley_cast"] = mix(vol, pluck(150, .4, .992) * env(int(SR * .4), .001, .1) * .6)
    s["arrow_impact"] = mix(lowpass(noise(.07), 3000) * env(int(SR * .07), .001, .02), thud(220, .1, .03) * .6)
    hammer = thud(300, .08, .02) + lowpass(noise(.08), 4000) * env(int(SR * .08), .001, .01) * .5
    s["build"] = mix(hammer, at(hammer, .16), at(hammer * 1.1, .32))
    s["sell"] = mix(s["coin"], at(s["coin"] * .8, .1))
    s["upgrade"] = mix(*[at(tone(f, .2) * env(int(SR * .2), .002, .08) * .5, i * .07)
                         for i, f in enumerate([523, 659, 784, 1047])])
    s["evolve"] = mix(chord([262, 330, 392], 1.4, .7) * .9, at(chord([349, 440, 523, 698], 1.4, .8) * .7, .35),
                      whoosh(1.2, 300, 3000) * .3)
    s["victory"] = mix(*[at(chord([f, f * 1.25, f * 1.5], .5 if i < 3 else 1.4, .3 if i < 3 else .8) * .9, i * .18)
                         for i, f in enumerate([392, 440, 494, 523])])
    s["defeat"] = mix(*[at(chord([f, f * 1.2, f * 1.5], .6 if i < 2 else 1.4, .4 if i < 2 else .9) * .8, i * .3)
                        for i, f in enumerate([392, 349, 262])])
    return s


def write(path, x):
    x = np.asarray(x, dtype=np.float64)
    peak = np.max(np.abs(x)) or 1
    x = x / peak * 0.9
    fade = min(len(x), int(SR * 0.01))
    x[-fade:] *= np.linspace(1, 0, fade)
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((x * 32767).astype("<i2").tobytes())


def main():
    """Usage: make_placeholder_sfx.py <project_root> [name ...] (only those)."""
    out = Path(sys.argv[1]) / "assets/audio/sfx"
    out.mkdir(parents=True, exist_ok=True)
    only = set(sys.argv[2:])
    for name, x in sounds().items():
        if only and name not in only:
            continue
        write(out / f"{name}.wav", x)
        print(f"{name}.wav  {len(x) / SR:.2f}s")


if __name__ == "__main__":
    main()
