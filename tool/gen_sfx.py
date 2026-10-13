#!/usr/bin/env python3
"""Procedurally synthesize Funme's cartoon sound effects and the BGM loop.

Every cue is generated from code so the app ships no third-party audio and the
sounds stay stylistically consistent. Output: 22.05 kHz, mono, 16-bit PCM WAV.

Usage:
    python3 tool/gen_sfx.py            # writes assets/audio/*.wav
"""

import os
import sys
import wave

import numpy as np

SR = 22050
RNG = np.random.default_rng(20261008)
OUT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'assets', 'audio')


# ---------------------------------------------------------------------------
# Building blocks
# ---------------------------------------------------------------------------

def secs(d):
    return np.arange(int(SR * d)) / SR


def sweep(f0, f1, d, curve=1.0):
    """Sine whose frequency glides from f0 to f1 (curve > 1 = slow start)."""
    t = secs(d)
    x = (t / d) ** curve if d > 0 else t
    f = f0 + (f1 - f0) * x
    return np.sin(2 * np.pi * np.cumsum(f) / SR)


def tone(f, d, harmonics=((1, 1.0),)):
    t = secs(d)
    out = np.zeros_like(t)
    for mult, amp in harmonics:
        out += amp * np.sin(2 * np.pi * f * mult * t)
    return out


def tri(f, d):
    t = secs(d)
    return 2 * np.abs(2 * ((t * f) % 1) - 1) - 1


def noise(d):
    return RNG.uniform(-1, 1, int(SR * d))


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


def bandpass(x, lo, hi):
    return lowpass(highpass(x, lo), hi)


def decay(n_or_x, rate):
    n = n_or_x if isinstance(n_or_x, int) else len(n_or_x)
    return np.exp(-rate * np.arange(n) / SR)


def env(x, attack=0.004, release=0.02):
    n = len(x)
    e = np.ones(n)
    a = min(n, int(SR * attack))
    r = min(n, int(SR * release))
    if a > 0:
        e[:a] = np.linspace(0, 1, a)
    if r > 0:
        e[n - r:] *= np.linspace(1, 0, r)
    return x * e


def place(buf, x, at):
    i = int(SR * at)
    if i >= len(buf):
        return buf
    end = min(len(buf), i + len(x))
    buf[i:end] += x[: end - i]
    return buf


def blank(d):
    return np.zeros(int(SR * d))


def normalize(x, peak=0.89):
    m = np.max(np.abs(x))
    return x if m == 0 else x * (peak / m)


def note(name):
    names = {'C': -9, 'D': -7, 'E': -5, 'F': -4, 'G': -2, 'A': 0, 'B': 2}
    base = names[name[0]]
    rest = name[1:]
    acc = 0
    while rest and rest[0] in '#b':
        acc += 1 if rest[0] == '#' else -1
        rest = rest[1:]
    octave = int(rest)
    return 440.0 * 2 ** ((base + acc + (octave - 4) * 12) / 12)


def music_box(f, d, bright=1.0):
    t = secs(d)
    out = np.sin(2 * np.pi * f * t) * np.exp(-t * 3.2)
    out += 0.35 * bright * np.sin(2 * np.pi * f * 2 * t) * np.exp(-t * 6)
    out += 0.12 * bright * np.sin(2 * np.pi * f * 3 * t) * np.exp(-t * 9)
    return env(out, 0.003, 0.03)


def marimba(f, d):
    t = secs(d)
    out = np.sin(2 * np.pi * f * t) * np.exp(-t * 5)
    out += 0.25 * np.sin(2 * np.pi * f * 3.93 * t) * np.exp(-t * 18)
    return env(out, 0.002, 0.03)


# ---------------------------------------------------------------------------
# Cues
# ---------------------------------------------------------------------------

def sfx_tap():
    x = sweep(900, 480, 0.07, 0.6) * decay(int(SR * 0.07), 55)
    click = lowpass(noise(0.006), 4000) * 0.3
    return env(place(x, click, 0), 0.001, 0.01)


def sfx_select():
    x = sweep(560, 1250, 0.11, 0.8)
    x = x + 0.3 * sweep(1120, 2500, 0.11, 0.8)
    return env(x * decay(len(x), 18), 0.003, 0.03)


def sfx_place():
    d = 0.12
    t = secs(d)
    body = np.sin(2 * np.pi * 190 * t) * np.exp(-t * 45)
    body += 0.6 * np.sin(2 * np.pi * 560 * t) * np.exp(-t * 70)
    body += 0.25 * np.sin(2 * np.pi * 1230 * t) * np.exp(-t * 110)
    knock = lowpass(noise(d), 2500) * np.exp(-t * 160) * 0.8
    return env(body + knock, 0.0008, 0.02)


def sfx_move():
    d = 0.2
    t = secs(d)
    shape = np.sin(np.pi * t / d) ** 2
    whoosh = bandpass(noise(d), 500, 2600) * shape * 1.4
    slide = sweep(420, 300, d) * shape * 0.25
    return env(whoosh + slide, 0.005, 0.03)


def sfx_capture():
    d = 0.32
    t = secs(d)
    f = 340 * np.exp(-t * 3.5) + 120 + 22 * np.sin(2 * np.pi * 18 * t)
    boing = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 7)
    pop = sweep(500, 1500, 0.03) * decay(int(SR * 0.03), 60) * 0.6
    return env(place(boing, pop, 0), 0.002, 0.04)


def sfx_flip():
    out = blank(0.14)
    for at, amp in ((0.0, 0.8), (0.055, 0.55)):
        tick = highpass(noise(0.03), 1800) * decay(int(SR * 0.03), 120) * amp
        place(out, tick, at)
    swish = bandpass(noise(0.12), 1500, 6000) * np.sin(np.linspace(0, np.pi, int(SR * 0.12))) * 0.35
    place(out, swish, 0.01)
    return env(out, 0.001, 0.02)


def sfx_dice():
    out = blank(0.75)
    at = 0.0
    gap = 0.045
    for i in range(9):
        d = 0.04
        t = secs(d)
        clack = highpass(noise(d), 1200) * np.exp(-t * 140)
        clack += 0.5 * np.sin(2 * np.pi * RNG.uniform(1800, 3200) * t) * np.exp(-t * 90)
        place(out, clack * (1 - i * 0.07), at)
        at += gap
        gap *= 1.12
    return env(out, 0.001, 0.04)


def sfx_hop():
    x = sweep(380, 760, 0.1, 0.7) * decay(int(SR * 0.1), 20)
    x += 0.25 * sweep(760, 1520, 0.1, 0.7) * decay(int(SR * 0.1), 30)
    return env(x, 0.002, 0.02)


def sfx_fly():
    d = 0.7
    t = secs(d)
    shape = np.sin(np.pi * t / d) ** 1.5
    whoosh = bandpass(noise(d), 700, 4000) * shape
    rise = sweep(300, 1300, d, 1.4) * shape * 0.35
    return env(whoosh + rise, 0.01, 0.06)


def sfx_merge():
    out = blank(0.2)
    place(out, music_box(note('C5'), 0.12) * 0.8, 0)
    place(out, music_box(note('G5'), 0.16), 0.055)
    return env(out, 0.002, 0.03)


def sfx_clear():
    out = blank(0.6)
    for i, n in enumerate(('C6', 'E6', 'G6', 'C7', 'E7')):
        place(out, music_box(note(n), 0.35, 0.6) * (0.9 - i * 0.08), i * 0.045)
    shimmer = highpass(noise(0.5), 5000) * np.linspace(0.25, 0, int(SR * 0.5))
    place(out, shimmer, 0.02)
    return env(out, 0.002, 0.05)


def sfx_star():
    out = blank(0.42)
    place(out, tone(note('B5'), 0.07, ((1, 1), (2, 0.3))) * decay(int(SR * 0.07), 8), 0)
    t = secs(0.36)
    ding = (np.sin(2 * np.pi * note('E6') * t) + 0.4 * np.sin(2 * np.pi * note('E7') * t)) * np.exp(-t * 7)
    place(out, ding, 0.06)
    return env(out, 0.002, 0.04)


def sfx_error():
    out = blank(0.3)
    for at in (0.0, 0.14):
        d = 0.12
        x = lowpass(np.sign(sweep(230, 170, d)), 900) * decay(int(SR * d), 14)
        place(out, env(x, 0.004, 0.03) * 0.8, at)
    return out


def sfx_win():
    out = blank(1.6)
    seq = (('C5', 0.0), ('E5', 0.11), ('G5', 0.22), ('C6', 0.33))
    for n, at in seq:
        place(out, music_box(note(n), 0.3), at)
    t = secs(1.15)
    trem = 1 + 0.25 * np.sin(2 * np.pi * 7 * t)
    for n in ('C5', 'E5', 'G5', 'C6'):
        f = note(n)
        chord = (np.sin(2 * np.pi * f * t) + 0.3 * np.sin(2 * np.pi * 2 * f * t)) * np.exp(-t * 2.4) * trem
        place(out, chord * 0.35, 0.45)
    sparkle = highpass(noise(0.8), 6000) * np.linspace(0.18, 0, int(SR * 0.8))
    place(out, sparkle, 0.45)
    return env(out, 0.002, 0.1)


def sfx_lose():
    out = blank(1.35)
    seq = (('G4', 0.0, 0.26), ('F#4', 0.28, 0.26), ('F4', 0.56, 0.26), ('E4', 0.84, 0.5))
    for n, at, d in seq:
        t = secs(d)
        f = note(n) * (1 + (0.02 * np.sin(2 * np.pi * 6 * t) if n == 'E4' else 0))
        x = np.sin(2 * np.pi * np.cumsum(np.full_like(t, 1) * f) / SR)
        x = lowpass(np.clip(x * 1.6, -1, 1), 1600)
        place(out, env(x, 0.02, 0.08) * 0.7, at)
    return out


def sfx_tick():
    x = tone(1600, 0.03, ((1, 1), (2, 0.2))) * decay(int(SR * 0.03), 120)
    return env(x, 0.0005, 0.01)


def sfx_go():
    t = secs(0.32)
    x = (np.sin(2 * np.pi * note('C6') * t) + 0.3 * np.sin(2 * np.pi * note('C7') * t)) * np.exp(-t * 6)
    return env(x, 0.002, 0.05)


def sfx_eat():
    out = blank(0.16)
    for at in (0.0, 0.07):
        d = 0.06
        chomp = lowpass(noise(d), 1800) * decay(int(SR * d), 70)
        chomp += 0.7 * sweep(260, 620, d) * decay(int(SR * d), 40)
        place(out, chomp, at)
    return env(out, 0.001, 0.02)


def sfx_whack():
    d = 0.22
    t = secs(d)
    thump = np.sin(2 * np.pi * (150 * np.exp(-t * 8) + 60) * t) * np.exp(-t * 20)
    crack = highpass(noise(d), 1500) * np.exp(-t * 90) * 0.6
    ping = np.sin(2 * np.pi * 880 * t) * np.exp(-t * 30) * 0.4
    return env(thump + crack + ping, 0.0008, 0.03)


def sfx_pop():
    x = sweep(420, 1500, 0.045, 0.5) * decay(int(SR * 0.045), 40)
    return env(x, 0.001, 0.01)


def sfx_flap():
    d = 0.09
    t = secs(d)
    x = bandpass(noise(d), 400, 2200) * np.sin(np.pi * t / d) ** 2 * 1.3
    return env(x, 0.002, 0.01)


def sfx_crash():
    d = 0.4
    t = secs(d)
    thud = np.sin(2 * np.pi * (110 * np.exp(-t * 4) + 40) * t) * np.exp(-t * 9)
    rumble = lowpass(noise(d), 500) * np.exp(-t * 10) * 0.9
    return env(thud + rumble, 0.001, 0.05)


def sfx_check():
    out = blank(0.5)
    for i, n in enumerate(('A5', 'E5', 'A5', 'E5')):
        x = lowpass(np.sign(tone(note(n), 0.1)), 3000) * 0.5
        place(out, env(x, 0.003, 0.02), i * 0.11)
    return out


def sfx_slide():
    d = 0.09
    t = secs(d)
    x = bandpass(noise(d), 1200, 5000) * np.sin(np.pi * t / d) * 0.9
    return env(x, 0.002, 0.01)


def sfx_bomb():
    d = 0.8
    t = secs(d)
    boom = lowpass(noise(d), 700) * np.exp(-t * 5) * 1.2
    boom += np.sin(2 * np.pi * (70 * np.exp(-t * 2) + 35) * t) * np.exp(-t * 4)
    crackle = highpass(noise(d), 2500) * np.exp(-t * 14) * 0.35
    return env(boom + crackle, 0.001, 0.1)


def sfx_combo():
    out = blank(0.36)
    for i, n in enumerate(('G5', 'C6', 'E6')):
        place(out, music_box(note(n), 0.2), i * 0.07)
    return env(out, 0.002, 0.03)


def sfx_undo():
    d = 0.22
    t = secs(d)
    shape = np.sin(np.pi * t / d) ** 1.2
    whoosh = bandpass(noise(d), 600, 3000) * shape * 0.9
    glide = sweep(900, 360, d, 0.8) * shape * 0.45
    return env(whoosh + glide, 0.004, 0.04)


def sfx_hint():
    out = blank(0.5)
    for i, n in enumerate(('E6', 'G6', 'C7')):
        place(out, music_box(note(n), 0.3, 0.8) * (0.85 - i * 0.1), i * 0.09)
    shimmer = highpass(noise(0.3), 6500) * np.linspace(0.12, 0, int(SR * 0.3))
    place(out, shimmer, 0.05)
    return env(out, 0.002, 0.05)


def sfx_unlock():
    out = blank(0.45)
    place(out, marimba(note('G5'), 0.18) * 0.9, 0)
    place(out, marimba(note('C6'), 0.3), 0.09)
    return env(out, 0.002, 0.04)


def sfx_turn():
    t = secs(0.2)
    x = (np.sin(2 * np.pi * note('A5') * t) + 0.25 * np.sin(2 * np.pi * note('A6') * t)) * np.exp(-t * 14)
    return env(x * 0.8, 0.002, 0.04)


# Arcade cabinet cues use inharmonic partials for metal rather than melody.
def sfx_coin_contact():
    d = 0.18
    t = secs(d)
    x = sum(amp * np.sin(2 * np.pi * freq * t) * np.exp(-t * rate)
            for freq, amp, rate in ((2350, 0.6, 35), (3720, 0.35, 45), (5910, 0.2, 60)))
    return env(x, 0.001, 0.025)


def sfx_coin_slot():
    out = blank(0.3)
    place(out, sfx_coin_contact() * 0.6, 0)
    place(out, sfx_place() * 0.4, 0.08)
    return out


def sfx_coin_tray():
    out = blank(0.48)
    for at, amp in ((0, 1), (0.08, 0.7), (0.19, 0.45), (0.3, 0.2)):
        place(out, sfx_coin_contact() * amp, at)
    return out


def sfx_pusher_motor():
    d = 0.35
    t = secs(d)
    x = (np.sin(2 * np.pi * 95 * t) + 0.25 * np.sin(2 * np.pi * 190 * t))
    return env(x * np.sin(np.pi * t / d) ** 2, 0.03, 0.06)


# ---------------------------------------------------------------------------
# Background music: 8 bars, C major, I–vi–IV–V, seamless loop
# ---------------------------------------------------------------------------

def bgm():
    bpm = 112
    beat = 60 / bpm
    bars = 8
    total = bars * 4 * beat
    out = blank(total + 1.5)
    melody = [
        ('G5', 1), ('E5', .5), ('F5', .5), ('G5', 1), ('C6', 1),
        ('A5', 1), ('G5', .5), ('E5', .5), ('C5', 2),
        ('F5', 1), ('A5', .5), ('G5', .5), ('F5', 1), ('C5', 1),
        ('D5', 1), ('E5', .5), ('F5', .5), ('G5', 2),
        ('G5', 1), ('E5', .5), ('F5', .5), ('G5', 1), ('C6', 1),
        ('D6', 1), ('C6', .5), ('A5', .5), ('G5', 2),
        ('F5', 1), ('A5', 1), ('G5', .5), ('F5', .5), ('D5', 1),
        ('E5', 1), ('D5', 1), ('C5', 2),
    ]
    at = 0.0
    for n, beats in melody:
        place(out, music_box(note(n), max(0.5, beats * beat * 1.4)) * 0.42, at)
        at += beats * beat
    chords = [
        ('C3', ('C4', 'E4', 'G4')), ('A2', ('A3', 'C4', 'E4')),
        ('F2', ('F3', 'A3', 'C4')), ('G2', ('G3', 'B3', 'D4')),
        ('C3', ('C4', 'E4', 'G4')), ('A2', ('A3', 'C4', 'E4')),
        ('F2', ('F3', 'A3', 'C4')), ('G2', ('G3', 'B3', 'D4')),
    ]
    for bar, (bass, triad) in enumerate(chords):
        start = bar * 4 * beat
        for b in (0, 2):
            t = secs(beat * 1.8)
            f = note(bass)
            low = (np.sin(2 * np.pi * f * t) + 0.25 * np.sin(2 * np.pi * 2 * f * t)) * np.exp(-t * 2.2)
            place(out, env(low, 0.01, 0.05) * 0.32, start + b * beat)
        for b in (1, 3):
            for n in triad:
                place(out, marimba(note(n), beat * 0.9) * 0.11, start + b * beat)
        for e in range(8):
            d = 0.05
            sh = highpass(noise(d), 6000) * decay(int(SR * d), 80) * (0.05 if e % 2 else 0.08)
            place(out, sh, start + e * beat / 2)
    loop_len = int(SR * total)
    looped = out[:loop_len].copy()
    tail = out[loop_len:]
    looped[: len(tail)] += tail
    return normalize(looped, 0.7)


CUES = {
    'tap': sfx_tap, 'select': sfx_select, 'place': sfx_place, 'move': sfx_move,
    'capture': sfx_capture, 'flip': sfx_flip, 'dice': sfx_dice, 'hop': sfx_hop,
    'fly': sfx_fly, 'merge': sfx_merge, 'clear': sfx_clear, 'star': sfx_star,
    'error': sfx_error, 'win': sfx_win, 'lose': sfx_lose, 'tick': sfx_tick,
    'go': sfx_go, 'eat': sfx_eat, 'whack': sfx_whack, 'pop': sfx_pop,
    'flap': sfx_flap, 'crash': sfx_crash, 'check': sfx_check, 'slide': sfx_slide,
    'bomb': sfx_bomb, 'combo': sfx_combo, 'undo': sfx_undo, 'hint': sfx_hint,
    'unlock': sfx_unlock, 'turn': sfx_turn,
    'coinSlot': sfx_coin_slot, 'coinContact': sfx_coin_contact,
    'coinTray': sfx_coin_tray, 'pusherMotor': sfx_pusher_motor,
}


def write_wav(path, x):
    data = (np.clip(x, -1, 1) * 32767).astype('<i2')
    with wave.open(path, 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    only = set(sys.argv[1:])
    for name, fn in CUES.items():
        if only and name not in only:
            continue
        write_wav(os.path.join(OUT_DIR, f'{name}.wav'), normalize(fn()))
    if not only or 'bgm' in only:
        write_wav(os.path.join(OUT_DIR, 'bgm.wav'), bgm())
    print(f'wrote audio to {os.path.normpath(OUT_DIR)}')


if __name__ == '__main__':
    main()
