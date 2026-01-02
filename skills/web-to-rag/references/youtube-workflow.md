# YouTube Workflow - Guida Dettagliata

Questa guida descrive il workflow completo per importare transcript YouTube nel RAG.

## Prerequisiti

### yt-dlp (obbligatorio)
```bash
# Verifica installazione
which yt-dlp || command -v yt-dlp

# Installazione
pip install yt-dlp
# oppure
brew install yt-dlp  # macOS
```

### Whisper (opzionale - per video senza sottotitoli)
```bash
# Verifica installazione
which whisper || command -v whisper

# Installazione (~1-3GB per i modelli)
pip install openai-whisper
```

---

## Workflow Completo

### Step 1: Estrai Info Video

```bash
# Ottieni titolo video
VIDEO_TITLE=$(yt-dlp --print "%(title)s" "YOUTUBE_URL")

# Ottieni durata
DURATION=$(yt-dlp --print "%(duration)s" "YOUTUBE_URL")

# Ottieni ID video
VIDEO_ID=$(yt-dlp --print "%(id)s" "YOUTUBE_URL")
```

### Step 2: Verifica Sottotitoli Disponibili

```bash
yt-dlp --list-subs "YOUTUBE_URL"
```

Output esempio:
```
[info] Available subtitles for VIDEO_ID:
Language  formats
en        vtt, ttml, srv3, srv2, srv1
it        vtt (auto-generated)
```

### Step 3: Scarica Sottotitoli

**Priorità: Manuali > Auto-generati**

```bash
# Prova sottotitoli manuali
yt-dlp --write-sub --skip-download --sub-langs en -o "transcript" "YOUTUBE_URL"

# Se fallisce, prova auto-generati
yt-dlp --write-auto-sub --skip-download --sub-langs en -o "transcript" "YOUTUBE_URL"
```

### Step 4: Pulisci VTT (Rimuovi Duplicati)

I file VTT di YouTube contengono righe duplicate per l'effetto "typing".

```python
import re

def clean_vtt(vtt_file, output_file):
    seen = set()
    with open(vtt_file, 'r', encoding='utf-8') as f:
        lines = f.readlines()

    clean_lines = []
    for line in lines:
        line = line.strip()
        # Salta metadata VTT
        if not line or line.startswith('WEBVTT') or line.startswith('Kind:') or line.startswith('Language:'):
            continue
        # Salta timestamp
        if '-->' in line:
            continue
        # Rimuovi tag HTML
        clean = re.sub('<[^>]*>', '', line)
        clean = clean.replace('&amp;', '&').replace('&gt;', '>').replace('&lt;', '<')
        # Deduplica
        if clean and clean not in seen:
            clean_lines.append(clean)
            seen.add(clean)

    with open(output_file, 'w', encoding='utf-8') as f:
        f.write('\n'.join(clean_lines))
```

### Step 5: Fallback Whisper (se necessario)

```bash
# 1. Scarica solo audio
yt-dlp -x --audio-format mp3 -o "audio_%(id)s.%(ext)s" "YOUTUBE_URL"

# 2. Trascrivi con Whisper
whisper audio_VIDEO_ID.mp3 --model base --output_format txt --language en

# 3. Pulisci file audio
rm audio_VIDEO_ID.mp3
```

**Modelli Whisper disponibili:**
| Modello | Dimensione | Velocità | Qualità |
|---------|------------|----------|---------|
| tiny | ~39MB | Velocissimo | Bassa |
| base | ~74MB | Veloce | Media |
| small | ~244MB | Medio | Buona |
| medium | ~769MB | Lento | Ottima |
| large | ~1.5GB | Molto lento | Eccellente |

Raccomandato: `base` per un buon compromesso.

### Step 6: Embed in RAG

```
mcp__anythingllm__embed_text
  slug: "workspace-name"
  texts: [
    "---\nsource: https://youtube.com/watch?v=VIDEO_ID\ntitle: Video Title\ntype: youtube-transcript\nduration: 15 minutes\n---\n\n[transcript content here]"
  ]
```

---

## Script Completo Bash

```bash
#!/bin/bash
# youtube-to-rag.sh - Scarica transcript YouTube e prepara per embedding

URL="$1"
WORKSPACE="$2"

if [ -z "$URL" ] || [ -z "$WORKSPACE" ]; then
    echo "Usage: youtube-to-rag.sh <youtube_url> <workspace>"
    exit 1
fi

# Verifica yt-dlp
if ! command -v yt-dlp &> /dev/null; then
    echo "yt-dlp non trovato. Installa con: pip install yt-dlp"
    exit 1
fi

# Ottieni info video
VIDEO_TITLE=$(yt-dlp --print "%(title)s" "$URL" | tr '/' '_' | tr ':' '-')
VIDEO_ID=$(yt-dlp --print "%(id)s" "$URL")
DURATION=$(yt-dlp --print "%(duration)s" "$URL")
DURATION_MIN=$((DURATION / 60))

echo "Video: $VIDEO_TITLE"
echo "Durata: ${DURATION_MIN} minuti"

# Prova sottotitoli manuali
echo "Cercando sottotitoli..."
if yt-dlp --write-sub --skip-download --sub-langs en -o "temp_transcript" "$URL" 2>/dev/null; then
    echo "Sottotitoli manuali trovati"
    VTT_FILE="temp_transcript.en.vtt"
elif yt-dlp --write-auto-sub --skip-download --sub-langs en -o "temp_transcript" "$URL" 2>/dev/null; then
    echo "Sottotitoli auto-generati trovati"
    VTT_FILE="temp_transcript.en.vtt"
else
    echo "Nessun sottotitolo disponibile"

    # Chiedi per Whisper
    read -p "Vuoi usare Whisper per trascrivere? (y/n) " USE_WHISPER
    if [ "$USE_WHISPER" = "y" ]; then
        if ! command -v whisper &> /dev/null; then
            echo "Whisper non trovato. Installa con: pip install openai-whisper"
            exit 1
        fi

        echo "Scaricando audio..."
        yt-dlp -x --audio-format mp3 -o "audio_${VIDEO_ID}.mp3" "$URL"

        echo "Trascrivendo con Whisper..."
        whisper "audio_${VIDEO_ID}.mp3" --model base --output_format txt

        TRANSCRIPT_FILE="audio_${VIDEO_ID}.txt"
        rm "audio_${VIDEO_ID}.mp3"
    else
        echo "Operazione annullata"
        exit 0
    fi
fi

# Pulisci VTT se presente
if [ -n "$VTT_FILE" ] && [ -f "$VTT_FILE" ]; then
    python3 -c "
import sys, re
seen = set()
with open('$VTT_FILE', 'r') as f:
    for line in f:
        line = line.strip()
        if line and not line.startswith('WEBVTT') and not line.startswith('Kind:') and not line.startswith('Language:') and '-->' not in line:
            clean = re.sub('<[^>]*>', '', line)
            clean = clean.replace('&amp;', '&').replace('&gt;', '>').replace('&lt;', '<')
            if clean and clean not in seen:
                print(clean)
                seen.add(clean)
" > "${VIDEO_TITLE}.txt"

    rm "$VTT_FILE"
    TRANSCRIPT_FILE="${VIDEO_TITLE}.txt"
fi

echo ""
echo "Transcript salvato: $TRANSCRIPT_FILE"
echo "Pronto per embedding nel workspace: $WORKSPACE"
```

---

## Gestione Errori

| Errore | Causa | Soluzione |
|--------|-------|-----------|
| "No subtitles" | Video senza sottotitoli | Usa Whisper |
| "Video unavailable" | Video privato/geo-bloccato | Non estraibile |
| "yt-dlp not found" | Tool non installato | `pip install yt-dlp` |
| Whisper OOM | RAM insufficiente | Usa modello più piccolo |

---

## Best Practices

1. **Sempre pulire i VTT** - I duplicati sprecano token nel RAG
2. **Aggiungere metadata** - source, title, duration nel documento
3. **Chunking per video lunghi** - Split ogni 15 minuti per video > 1h
4. **Verificare lingua** - Specificare `--sub-langs` correttamente
5. **Usare base model** - Per Whisper, `base` è il miglior compromesso

---

*Ultimo aggiornamento: Gennaio 2026*
