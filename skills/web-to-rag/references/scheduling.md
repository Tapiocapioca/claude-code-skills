# Scheduling Automatico - Guida Dettagliata

Questa guida descrive come Claude configura aggiornamenti automatici del RAG.

## Concetto

Lo scheduling permette di mantenere il RAG aggiornato automaticamente.
Claude crea script e configura il sistema operativo per eseguirli periodicamente.

---

## Workflow Guidato

Quando l'utente chiede di schedulare aggiornamenti:

### Step 1: Raccolta Informazioni

Claude chiede:

```
Per creare lo schedule automatico, ho bisogno di alcune informazioni:

1. Quale workspace aggiornare?
   [Lista workspace esistenti o nuovo nome]

2. Quale URL sorgente?
   [URL da cui fare scraping]

3. Frequenza di aggiornamento?
   - Giornaliero
   - Settimanale (quale giorno?)
   - Mensile (quale giorno del mese?)

4. Orario preferito?
   [Default: 3:00 AM]
```

### Step 2: Creazione Script

Claude crea uno script nella directory della skill:

**Windows:** `~/.claude/skills/web-to-rag/scripts/update-rag-{workspace}.ps1`
**Linux/macOS:** `~/.claude/skills/web-to-rag/scripts/update-rag-{workspace}.sh`

### Step 3: Configurazione Scheduler

**Windows:** Task Scheduler via PowerShell
**Linux/macOS:** crontab

### Step 4: Conferma

```
✅ Schedule creato con successo!

Dettagli:
- Workspace: fastapi-docs
- Sorgente: https://fastapi.tiangolo.com
- Frequenza: Ogni lunedì alle 3:00 AM
- Script: ~/.claude/skills/web-to-rag/scripts/update-rag-fastapi-docs.ps1
- Task ID: UpdateRAG-fastapi-docs

Log disponibili in: ~/.claude/logs/rag-updates.log

Per gestire lo schedule:
- "mostra schedule attivi"
- "pausa schedule fastapi-docs"
- "cancella schedule fastapi-docs"
```

---

## Script Template - Windows

```powershell
<#
.SYNOPSIS
    Aggiorna automaticamente il workspace RAG
.DESCRIPTION
    Script generato da web-to-rag skill per aggiornamenti schedulati
.NOTES
    Workspace: {WORKSPACE}
    Sorgente: {SOURCE_URL}
    Creato: {DATE}
#>

$ErrorActionPreference = "Stop"

# Configurazione
$WORKSPACE = "{WORKSPACE}"
$SOURCE_URL = "{SOURCE_URL}"
$ANYTHINGLLM_URL = "http://localhost:3001"
$ANYTHINGLLM_KEY = "{API_KEY}"
$CRAWL4AI_URL = "http://localhost:11235"
$LOG_FILE = "$env:USERPROFILE\.claude\logs\rag-updates.log"

# Crea directory log se non esiste
$logDir = Split-Path $LOG_FILE
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}

function Write-Log {
    param($Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp [$WORKSPACE] $Message" | Add-Content $LOG_FILE
    Write-Host $Message
}

Write-Log "=== Inizio aggiornamento RAG ==="

# Verifica Docker
Write-Log "Verifico Docker..."
$dockerStatus = docker info 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Log "Docker non attivo, provo ad avviare..."
    Start-Process "C:\Program Files\Docker\Docker\Docker Desktop.exe"
    Start-Sleep -Seconds 30
}

# Verifica container
$containers = docker ps --format "{{.Names}}"
if ($containers -notcontains "crawl4ai") {
    Write-Log "Avvio container crawl4ai..."
    docker start crawl4ai
}
if ($containers -notcontains "anythingllm") {
    Write-Log "Avvio container anythingllm..."
    docker start anythingllm
}

Start-Sleep -Seconds 10

# Scraping con Crawl4AI
Write-Log "Scraping di $SOURCE_URL..."
try {
    $crawlResult = Invoke-RestMethod -Uri "$CRAWL4AI_URL/crawl" -Method POST -ContentType "application/json" -Body (@{
        url = $SOURCE_URL
        output_format = "markdown"
    } | ConvertTo-Json)

    $content = $crawlResult.markdown
    Write-Log "Ottenuti $($content.Length) caratteri"
} catch {
    Write-Log "ERRORE scraping: $_"
    exit 1
}

# Embedding in AnythingLLM
Write-Log "Embedding nel workspace $WORKSPACE..."
try {
    $headers = @{
        "Authorization" = "Bearer $ANYTHINGLLM_KEY"
        "Content-Type" = "application/json"
    }

    $embedResult = Invoke-RestMethod -Uri "$ANYTHINGLLM_URL/api/v1/workspace/$WORKSPACE/embed-text" -Method POST -Headers $headers -Body (@{
        texts = @($content)
    } | ConvertTo-Json)

    Write-Log "Embedding completato"
} catch {
    Write-Log "ERRORE embedding: $_"
    exit 1
}

Write-Log "=== Aggiornamento completato con successo ==="
```

---

## Script Template - Linux/macOS

```bash
#!/bin/bash
#
# Aggiorna automaticamente il workspace RAG
# Workspace: {WORKSPACE}
# Sorgente: {SOURCE_URL}
# Creato: {DATE}
#

set -e

# Configurazione
WORKSPACE="{WORKSPACE}"
SOURCE_URL="{SOURCE_URL}"
ANYTHINGLLM_URL="http://localhost:3001"
ANYTHINGLLM_KEY="{API_KEY}"
CRAWL4AI_URL="http://localhost:11235"
LOG_FILE="$HOME/.claude/logs/rag-updates.log"

# Crea directory log se non esiste
mkdir -p "$(dirname "$LOG_FILE")"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$WORKSPACE] $1" | tee -a "$LOG_FILE"
}

log "=== Inizio aggiornamento RAG ==="

# Verifica Docker
log "Verifico Docker..."
if ! docker info &> /dev/null; then
    log "Docker non attivo, provo ad avviare..."
    if [[ "$OSTYPE" == "darwin"* ]]; then
        open -a Docker
    else
        sudo systemctl start docker
    fi
    sleep 30
fi

# Verifica container
if ! docker ps --format '{{.Names}}' | grep -q "^crawl4ai$"; then
    log "Avvio container crawl4ai..."
    docker start crawl4ai
fi
if ! docker ps --format '{{.Names}}' | grep -q "^anythingllm$"; then
    log "Avvio container anythingllm..."
    docker start anythingllm
fi

sleep 10

# Scraping con Crawl4AI
log "Scraping di $SOURCE_URL..."
CONTENT=$(curl -s -X POST "$CRAWL4AI_URL/crawl" \
    -H "Content-Type: application/json" \
    -d "{\"url\": \"$SOURCE_URL\", \"output_format\": \"markdown\"}" \
    | jq -r '.markdown')

if [ -z "$CONTENT" ]; then
    log "ERRORE: Scraping fallito, contenuto vuoto"
    exit 1
fi

log "Ottenuti ${#CONTENT} caratteri"

# Embedding in AnythingLLM
log "Embedding nel workspace $WORKSPACE..."
EMBED_RESULT=$(curl -s -X POST "$ANYTHINGLLM_URL/api/v1/workspace/$WORKSPACE/embed-text" \
    -H "Authorization: Bearer $ANYTHINGLLM_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"texts\": [\"$CONTENT\"]}")

if echo "$EMBED_RESULT" | jq -e '.error' &> /dev/null; then
    log "ERRORE embedding: $(echo $EMBED_RESULT | jq -r '.error')"
    exit 1
fi

log "=== Aggiornamento completato con successo ==="
```

---

## Comandi Task Scheduler Windows

### Creare Task
```powershell
$action = New-ScheduledTaskAction -Execute "pwsh" -Argument "-File `"$scriptPath`""

# Settimanale
$trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Monday -At 3am

# Giornaliero
$trigger = New-ScheduledTaskTrigger -Daily -At 3am

# Mensile (primo del mese)
$trigger = New-ScheduledTaskTrigger -Weekly -WeeksInterval 4 -DaysOfWeek Monday -At 3am

Register-ScheduledTask -TaskName "UpdateRAG-$WORKSPACE" -Action $action -Trigger $trigger -Description "Aggiorna workspace RAG: $WORKSPACE"
```

### Gestire Task
```powershell
# Lista task RAG
Get-ScheduledTask | Where-Object { $_.TaskName -like "UpdateRAG-*" }

# Pausa task
Disable-ScheduledTask -TaskName "UpdateRAG-$WORKSPACE"

# Riprendi task
Enable-ScheduledTask -TaskName "UpdateRAG-$WORKSPACE"

# Elimina task
Unregister-ScheduledTask -TaskName "UpdateRAG-$WORKSPACE" -Confirm:$false

# Esegui manualmente
Start-ScheduledTask -TaskName "UpdateRAG-$WORKSPACE"

# Vedi ultima esecuzione
Get-ScheduledTaskInfo -TaskName "UpdateRAG-$WORKSPACE"
```

---

## Comandi crontab Linux/macOS

### Creare Entry
```bash
# Settimanale (lunedì alle 3:00)
(crontab -l 2>/dev/null; echo "0 3 * * 1 $SCRIPT_PATH") | crontab -

# Giornaliero (alle 3:00)
(crontab -l 2>/dev/null; echo "0 3 * * * $SCRIPT_PATH") | crontab -

# Mensile (primo del mese alle 3:00)
(crontab -l 2>/dev/null; echo "0 3 1 * * $SCRIPT_PATH") | crontab -
```

### Gestire Entry
```bash
# Lista crontab
crontab -l

# Rimuovi entry specifico
crontab -l | grep -v "$WORKSPACE" | crontab -

# Modifica crontab manualmente
crontab -e
```

---

## Gestione da Claude

### Lista Schedule Attivi

```
Utente: "mostra schedule attivi"

Claude esegue:
- Windows: Get-ScheduledTask | Where-Object { $_.TaskName -like "UpdateRAG-*" }
- Linux: crontab -l | grep update-rag

Output:
Schedule RAG attivi:

1. fastapi-docs
   - Frequenza: Settimanale (Lunedì 3:00)
   - Ultima esecuzione: 2026-01-06 03:00
   - Stato: Attivo

2. react-docs
   - Frequenza: Giornaliero (3:00)
   - Ultima esecuzione: 2026-01-10 03:00
   - Stato: In pausa
```

### Cancella Schedule

```
Utente: "cancella schedule fastapi-docs"

Claude esegue:
1. Rimuove task scheduler/crontab
2. Elimina script
3. Conferma: "Schedule fastapi-docs eliminato"
```

### Modifica Frequenza

```
Utente: "cambia frequenza fastapi-docs a giornaliero"

Claude esegue:
1. Rimuove vecchio trigger
2. Crea nuovo trigger giornaliero
3. Conferma: "Frequenza aggiornata a giornaliero alle 3:00"
```

---

## Limitazioni

1. **Docker deve essere attivo** - Lo script prova ad avviarlo ma potrebbe fallire
2. **API dirette** - Non usa Claude Code interattivo
3. **Nessun feedback** - Solo log file
4. **Single URL** - Uno script per URL sorgente
5. **Credenziali** - API key salvata nello script (considerare secrets manager)

---

## Best Practices

1. **Orari notturni** - Schedule alle 3:00 AM per non interferire
2. **Monitora log** - Controlla periodicamente ~/.claude/logs/
3. **Backup workspace** - Prima di aggiornamenti massivi
4. **Test manuale** - Esegui script una volta prima di schedulare
5. **Rate limiting** - Non schedulare troppi update contemporanei

---

*Ultimo aggiornamento: Gennaio 2026*
