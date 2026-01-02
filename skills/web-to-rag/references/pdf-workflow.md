# PDF Workflow - Guida Dettagliata

Questa guida descrive il workflow completo per importare documenti PDF nel RAG.

## Prerequisiti

### pdftotext (da poppler)

**Windows:**
```powershell
choco install poppler -y
```

**macOS:**
```bash
brew install poppler
```

**Linux:**
```bash
sudo apt install poppler-utils
```

Verifica installazione:
```bash
which pdftotext || command -v pdftotext
pdftotext -v
```

---

## Workflow Completo

### Step 1: Scarica PDF (se URL remoto)

```bash
# Con curl
curl -L -o document.pdf "https://example.com/file.pdf"

# Con wget
wget -O document.pdf "https://example.com/file.pdf"
```

### Step 2: Estrai Testo

```bash
# Estrazione base
pdftotext document.pdf output.txt

# Con layout preservato (meglio per tabelle)
pdftotext -layout document.pdf output.txt

# Solo alcune pagine
pdftotext -f 1 -l 10 document.pdf output.txt  # Pagine 1-10
```

### Step 3: Verifica Contenuto

```bash
# Controlla se ha contenuto
wc -l output.txt

# Se 0 righe o quasi vuoto, probabilmente è una scansione
```

### Step 4: Chunking (per PDF grandi)

Per PDF con molto testo (> 50KB), dividi in chunks:

```python
def chunk_text(text, chunk_size=10000, overlap=500):
    """Divide il testo in chunks con overlap."""
    chunks = []
    start = 0

    while start < len(text):
        end = start + chunk_size

        # Trova fine frase più vicina
        if end < len(text):
            # Cerca punto, punto interrogativo, o newline
            for i in range(end, max(start, end - 500), -1):
                if text[i] in '.?!\n':
                    end = i + 1
                    break

        chunks.append(text[start:end])
        start = end - overlap

    return chunks
```

### Step 5: Embed in RAG

**Documento singolo:**
```
mcp__anythingllm__embed_text
  slug: "workspace-name"
  texts: [
    "---\nsource: https://example.com/doc.pdf\ntitle: Document Title\ntype: pdf\n---\n\n[content here]"
  ]
```

**Documento chunked:**
```
mcp__anythingllm__embed_text
  slug: "workspace-name"
  texts: [
    "---\nsource: doc.pdf\ntitle: Doc Title\ntype: pdf\nchunk: 1/5\npages: 1-20\n---\n\n[chunk 1]",
    "---\nsource: doc.pdf\ntitle: Doc Title\ntype: pdf\nchunk: 2/5\npages: 21-40\n---\n\n[chunk 2]",
    ...
  ]
```

---

## Script Completo Bash

```bash
#!/bin/bash
# pdf-to-rag.sh - Estrae testo da PDF e prepara per embedding

PDF_PATH="$1"
WORKSPACE="$2"

if [ -z "$PDF_PATH" ] || [ -z "$WORKSPACE" ]; then
    echo "Usage: pdf-to-rag.sh <pdf_path_or_url> <workspace>"
    exit 1
fi

# Verifica pdftotext
if ! command -v pdftotext &> /dev/null; then
    echo "pdftotext non trovato."
    echo "Installa con:"
    echo "  Windows: choco install poppler"
    echo "  macOS: brew install poppler"
    echo "  Linux: apt install poppler-utils"
    exit 1
fi

# Scarica se URL
if [[ "$PDF_PATH" == http* ]]; then
    echo "Scaricando PDF..."
    FILENAME=$(basename "$PDF_PATH")
    curl -L -o "$FILENAME" "$PDF_PATH"
    PDF_PATH="$FILENAME"
    REMOTE=true
fi

# Estrai nome file
BASENAME=$(basename "$PDF_PATH" .pdf)

# Estrai testo
echo "Estraendo testo..."
pdftotext -layout "$PDF_PATH" "${BASENAME}.txt"

# Verifica contenuto
LINES=$(wc -l < "${BASENAME}.txt")
SIZE=$(wc -c < "${BASENAME}.txt")

if [ "$LINES" -lt 10 ]; then
    echo "ATTENZIONE: Il PDF sembra essere una scansione (poche righe estratte)"
    echo "Considera l'uso di un servizio OCR."
    exit 1
fi

echo "Estratte $LINES righe ($SIZE bytes)"

# Chunking se necessario
if [ "$SIZE" -gt 50000 ]; then
    echo "Documento grande, splitting in chunks..."
    # Python chunking
    python3 << EOF
import os

def chunk_file(filepath, chunk_size=10000):
    with open(filepath, 'r', encoding='utf-8', errors='ignore') as f:
        text = f.read()

    chunks = []
    start = 0
    chunk_num = 1

    while start < len(text):
        end = min(start + chunk_size, len(text))

        # Trova fine paragrafo
        if end < len(text):
            for i in range(end, max(start, end - 500), -1):
                if text[i] == '\n' and (i + 1 >= len(text) or text[i + 1] == '\n'):
                    end = i + 1
                    break

        chunk_text = text[start:end].strip()
        if chunk_text:
            chunk_file = f"${BASENAME}_chunk{chunk_num}.txt"
            with open(chunk_file, 'w', encoding='utf-8') as f:
                f.write(chunk_text)
            print(f"Chunk {chunk_num}: {len(chunk_text)} chars -> {chunk_file}")
            chunk_num += 1

        start = end

chunk_file("${BASENAME}.txt")
EOF
    echo "Chunks creati: ${BASENAME}_chunk*.txt"
else
    echo "Documento pronto: ${BASENAME}.txt"
fi

# Cleanup se scaricato
if [ "$REMOTE" = true ]; then
    read -p "Eliminare PDF scaricato? (y/n) " DEL_PDF
    if [ "$DEL_PDF" = "y" ]; then
        rm "$PDF_PATH"
    fi
fi

echo ""
echo "Pronto per embedding nel workspace: $WORKSPACE"
```

---

## Gestione Errori

| Errore | Causa | Soluzione |
|--------|-------|-----------|
| "No text extracted" | PDF scansionato | Usa OCR (Tesseract) |
| "Encoding error" | Caratteri speciali | Usa `errors='ignore'` |
| "pdftotext not found" | Poppler non installato | Installa poppler |
| "Permission denied" | PDF protetto | Non estraibile senza password |

### PDF Protetti

```bash
# Se il PDF ha password di lettura
pdftotext -upw "password" document.pdf output.txt

# Se il PDF ha solo protezione copia (spesso aggirabile)
pdftotext document.pdf output.txt  # Potrebbe funzionare comunque
```

### PDF Scansionati (OCR)

Per PDF che sono immagini scansionate, serve OCR:

```bash
# Installa Tesseract
# Windows: choco install tesseract
# macOS: brew install tesseract
# Linux: apt install tesseract-ocr

# Converti PDF in immagini e OCR
pdftoppm -png document.pdf page
for img in page-*.png; do
    tesseract "$img" "${img%.png}" -l ita+eng
done
cat page-*.txt > document.txt
```

---

## Best Practices

1. **Verifica sempre l'estrazione** - Controlla che il testo sia leggibile
2. **Usa `-layout` per tabelle** - Preserva meglio la struttura
3. **Chunk documenti lunghi** - Evita documenti > 50KB per chunk
4. **Aggiungi metadata** - source, title, pages nel documento
5. **Pulisci whitespace** - Rimuovi righe vuote eccessive
6. **Specifica pagine** - Se solo alcune sezioni sono rilevanti

---

## Metadata Consigliati

```yaml
---
source: https://example.com/whitepaper.pdf
title: Company Whitepaper 2024
type: pdf
pages: 1-50
chunk: 1/3  # se chunked
extracted: 2026-01-01
---
```

---

*Ultimo aggiornamento: Gennaio 2026*
