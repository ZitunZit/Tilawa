#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Tilawa — Nettoyage d'une récitation par ancrage vocal (Vosk, 100% hors-ligne).

Détecte, dans l'enregistrement, les repères parlés qui délimitent la récitation :
  - « Bismillah ar-rahman ar-rahim »  -> DÉBUT d'un passage à garder
  - « Allahu Akbar » (takbir)          -> FIN du passage (transition, à couper)
  - « As-salamu alaykum » (taslim)     -> fin de prière (à couper)

Puis reconstruit un audio ne contenant que les récitations (Fatiha + sourate de
chaque cycle), sans les formules ni les silences.

Ne nécessite AUCUN pré-enregistrement de l'imam : le modèle Vosk est générique.
Fonctionne entièrement en local, sans connexion internet une fois le modèle
téléchargé.

------------------------------------------------------------------------------
INSTALLATION (une fois)
------------------------------------------------------------------------------
    pip install vosk
    # ffmpeg doit être installé (https://ffmpeg.org) et dans le PATH.

    # Modèle arabe Vosk (à télécharger une fois, ~1.3 Go) :
    #   https://alphacephei.com/vosk/models
    #   -> "vosk-model-ar-mgb2-0.4"  (recommandé)
    # Décompressez-le, par ex. dans ./models/vosk-model-ar-mgb2-0.4

------------------------------------------------------------------------------
UTILISATION
------------------------------------------------------------------------------
    python clean_with_vosk.py \
        --input  "Taraweeh.mp3" \
        --model  "models/vosk-model-ar-mgb2-0.4" \
        --output "Taraweeh_nettoye.mp3"

    # Options utiles :
    #   --keep-fatiha-min 25   durée min (s) d'un passage gardé (doit contenir Fatiha)
    #   --dump-transcript out.json   sauvegarde la transcription horodatée
    #   --hybrid               combine ancres + densité (recommandé si l'ASR rate des ancres)
"""
import argparse, json, os, subprocess, sys, tempfile, wave
import numpy as np

# --- Normalisation arabe : retire diacritiques et unifie alef/hamza ---
_DIAC = ''.join(chr(c) for c in list(range(0x0610, 0x061B)) +
                list(range(0x064B, 0x0660)) + [0x0670, 0x0640])
_TRANS = str.maketrans({'أ': 'ا', 'إ': 'ا', 'آ': 'ا', 'ٱ': 'ا',
                        'ة': 'ه', 'ى': 'ي', 'ؤ': 'و', 'ئ': 'ي'})

def norm(s: str) -> str:
    s = ''.join(ch for ch in s if ch not in _DIAC)
    return s.translate(_TRANS).strip()

# Mots-clés (formes normalisées, sans diacritiques)
TAKBIR_TOKENS = {'اكبر'}          # « akbar » ; précédé de « allah »
BISM_TOKENS   = {'بسم'}           # « bism » (+ « الله »)
ALLAH_TOKENS  = {'الله', 'اللاه'}
SALAM_TOKENS  = {'السلام', 'سلام'}


def to_wav16k(path: str) -> str:
    """Convertit n'importe quel audio en WAV mono 16 kHz (requis par Vosk)."""
    tmp = tempfile.mktemp(suffix='.wav')
    subprocess.run(['ffmpeg', '-y', '-i', path, '-ac', '1', '-ar', '16000',
                    '-acodec', 'pcm_s16le', tmp, '-loglevel', 'error'],
                   check=True)
    return tmp


def transcribe(wav_path: str, model_dir: str):
    """Retourne la liste des mots {word, start, end} via Vosk."""
    from vosk import Model, KaldiRecognizer, SetLogLevel
    SetLogLevel(-1)
    model = Model(model_dir)
    wf = wave.open(wav_path, 'rb')
    rec = KaldiRecognizer(model, wf.getframerate())
    rec.SetWords(True)
    words = []
    while True:
        data = wf.readframes(4000)
        if len(data) == 0:
            break
        if rec.AcceptWaveform(data):
            r = json.loads(rec.Result())
            words += r.get('result', [])
    r = json.loads(rec.FinalResult())
    words += r.get('result', [])
    for w in words:
        w['norm'] = norm(w['word'])
    return words


def find_anchors(words):
    """Repère les instants (s) des takbir, bismillah et salam."""
    takbir, bism, salam = [], [], []
    for i, w in enumerate(words):
        nw = w['norm']
        prev = words[i - 1]['norm'] if i > 0 else ''
        if nw in TAKBIR_TOKENS and prev in ALLAH_TOKENS:
            takbir.append(w['start'])
        elif nw in ALLAH_TOKENS and i + 1 < len(words) and words[i + 1]['norm'] in TAKBIR_TOKENS:
            takbir.append(w['start'])
        if nw in BISM_TOKENS:
            bism.append(w['start'])
        if nw in SALAM_TOKENS:
            salam.append(w['start'])
    # dédoublonne les takbir proches (< 2 s)
    def dedup(a):
        out = []
        for t in sorted(a):
            if not out or t - out[-1] > 2.0:
                out.append(t)
        return out
    return dedup(takbir), dedup(bism), dedup(salam)


def keep_intervals(words, takbir, bism, total_dur, min_keep):
    """
    Construit les intervalles à GARDER : de chaque « Bismillah » jusqu'au
    « Allahu Akbar » suivant (exclu). Robuste si des bismillah manquent :
    à défaut, on part du début de parole après le takbir précédent.
    """
    starts = sorted(bism)
    cuts = sorted(takbir)
    intervals = []
    for s in starts:
        # premier takbir après ce bismillah
        end = next((t for t in cuts if t > s + 5), None)
        if end is None:
            end = total_dur
        intervals.append((s, end))
    # fusion des chevauchements
    intervals.sort()
    merged = []
    for a, b in intervals:
        if merged and a <= merged[-1][1] + 1:
            merged[-1] = (merged[-1][0], max(merged[-1][1], b))
        else:
            merged.append((a, b))
    # garde seulement les passages assez longs pour contenir la Fatiha
    merged = [(a, b) for a, b in merged if b - a >= min_keep]
    return merged


def density_blocks(x, sr, min_keep):
    """Repli heuristique (densité de parole) si l'ASR fournit peu d'ancres."""
    win = int(0.02 * sr); n = len(x) // win
    rms = np.sqrt((x[:n * win].reshape(n, win) ** 2).mean(1))
    voiced = (rms >= np.percentile(rms, 99) * 0.06).astype(np.float32)
    W = int(8 / 0.02)
    dens = np.convolve(voiced, np.ones(W) / W, mode='same')
    rec = dens >= 0.5
    idx = np.where(rec)[0]
    if len(idx) == 0:
        return []
    cores = []; s = idx[0]; p = idx[0]
    for i in idx[1:]:
        if (i - p) * 0.02 > 2.0:
            cores.append((s, p)); s = i
        p = i
    cores.append((s, p))

    def snap(f, back, fwd):
        lo = max(0, f - int(back / 0.02)); hi = min(n - 1, f + int(fwd / 0.02))
        return lo + int(np.argmin(rms[lo:hi + 1]))
    blocks = [(snap(a, 2.5, 0.5) * 0.02, snap(b, 0.3, 1.5) * 0.02) for a, b in cores]
    return [(a, b) for a, b in blocks if b - a >= min_keep]


def render(x, sr, intervals, out_path):
    pad = int(0.12 * sr); fade = int(0.03 * sr); w = np.linspace(0, 1, fade)
    parts = []
    for a, b in intervals:
        A = max(0, int(a * sr) - pad); B = min(len(x), int(b * sr) + pad)
        seg = x[A:B].astype(np.float32).copy()
        if len(seg) > 2 * fade:
            seg[:fade] *= w; seg[-fade:] *= w[::-1]
        parts.append(seg)
    y = np.concatenate(parts) if parts else np.zeros(1, np.float32)
    tmp = tempfile.mktemp(suffix='.wav')
    import scipy.io.wavfile as wavio
    wavio.write(tmp, sr, np.clip(y, -1, 1).astype(np.float32))
    # export dans le format demandé via ffmpeg
    subprocess.run(['ffmpeg', '-y', '-i', tmp, out_path, '-loglevel', 'error'],
                   check=True)
    return len(y) / sr


def main():
    ap = argparse.ArgumentParser(description='Nettoyage récitation par ancrage Vosk.')
    ap.add_argument('--input', required=True)
    ap.add_argument('--model', required=True, help='dossier du modèle Vosk arabe')
    ap.add_argument('--output', required=True)
    ap.add_argument('--keep-fatiha-min', type=float, default=25.0)
    ap.add_argument('--hybrid', action='store_true',
                    help='fusionne ancres ASR + densité')
    ap.add_argument('--dump-transcript', default=None)
    args = ap.parse_args()

    if not os.path.isdir(args.model):
        sys.exit(f'Modèle introuvable: {args.model}\n'
                 'Téléchargez "vosk-model-ar-mgb2-0.4" sur '
                 'https://alphacephei.com/vosk/models')

    print('· Conversion audio -> 16 kHz mono…')
    wav16 = to_wav16k(args.input)
    import scipy.io.wavfile as wavio
    sr, x = wavio.read(wav16); x = x.astype(np.float32) / 32768.0
    total = len(x) / sr

    print('· Transcription Vosk (peut prendre quelques minutes)…')
    words = transcribe(wav16, args.model)
    if args.dump_transcript:
        json.dump(words, open(args.dump_transcript, 'w', encoding='utf-8'),
                  ensure_ascii=False, indent=2)

    takbir, bism, salam = find_anchors(words)
    print(f'  Ancres détectées — bismillah:{len(bism)}  takbir:{len(takbir)}  salam:{len(salam)}')

    intervals = keep_intervals(words, takbir, bism, total, args.keep_fatiha_min)

    # Repli / hybride : si trop peu d'ancres, on complète par la densité.
    if args.hybrid or len(intervals) < 3:
        print('· Complément par heuristique de densité…')
        dens = density_blocks(x, sr, args.keep_fatiha_min)
        intervals = sorted(set(intervals) | set(dens))
        # re-fusion
        merged = []
        for a, b in intervals:
            if merged and a <= merged[-1][1] + 1:
                merged[-1] = (merged[-1][0], max(merged[-1][1], b))
            else:
                merged.append((a, b))
        intervals = merged

    # retire tout ce qui suit le premier salam final (fin de prière)
    if salam:
        last = salam[-1]
        intervals = [(a, min(b, last)) for a, b in intervals if a < last]

    kept = render(x, sr, intervals, args.output)
    print(f'\n✓ {args.output}')
    print(f'  {len(intervals)} passage(s) de récitation — {kept/60:.1f} min '
          f'(sur {total/60:.1f} min, soit -{(total-kept)/60:.1f} min).')

    os.remove(wav16)


if __name__ == '__main__':
    main()
