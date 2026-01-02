#!/bin/bash
#
# Template per aggiornamento automatico workspace RAG
#
# Questo script viene copiato e personalizzato da Claude quando l'utente
# richiede uno schedule di aggiornamento.
#
# NON MODIFICARE questo file - Claude creerà copie personalizzate.
#
# Placeholder da sostituire:
# - {WORKSPACE}: nome del workspace
# - {SOURCE_URL}: URL sorgente
# - {API_KEY}: chiave API AnythingLLM
# - {DATE}: data creazione
#

set -e

# ============================================
# CONFIGURAZIONE - Sostituita da Claude
# ============================================
WORKSPACE="{WORKSPACE}"
SOURCE_URL="{SOURCE_URL}"
ANYTHINGLLM_URL="http://localhost:3001"
ANYTHINGLLM_KEY="{API_KEY}"
CRAWL4AI_URL="http://localhost:11235"
LOG_FILE="$HOME/.claude/logs/rag-updates.log"

# ============================================
# FUNZIONI HELPER
# ============================================

# Crea directory log se non esiste
mkdir -p "$(dirname "$LOG_FILE")"

log() {
    local level="${2:-INFO}"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$WORKSPACE] [$level] $1" | tee -a "$LOG_FILE"
}

log_error() {
    log "$1" "ERROR"
}

check_docker() {
    docker info &> /dev/null
    return $?
}

start_docker() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        open -a Docker
    else
        # Linux
        sudo systemctl start docker 2>/dev/null || true
    fi
    log "Avviato Docker, attendo 30 secondi..."
    sleep 30
}

start_container() {
    local name="$1"
    if ! docker ps --format '{{.Names}}' | grep -q "^${name}$"; then
        log "Avvio container $name..."
        docker start "$name" 2>/dev/null || true
        sleep 5
    fi
}

# ============================================
# MAIN
# ============================================

log "=========================================="
log "Inizio aggiornamento RAG"
log "Workspace: $WORKSPACE"
log "Sorgente: $SOURCE_URL"
log "=========================================="

# Step 1: Verifica Docker
log "Verifico Docker..."
if ! check_docker; then
    log "Docker non attivo, provo ad avviare..."
    start_docker
    if ! check_docker; then
        log_error "Impossibile avviare Docker"
        exit 1
    fi
fi
log "Docker OK"

# Step 2: Verifica container
start_container "crawl4ai"
start_container "anythingllm"
log "Container OK"

# Step 3: Scraping
log "Scraping di $SOURCE_URL..."

CRAWL_RESPONSE=$(curl -s --max-time 300 -X POST "$CRAWL4AI_URL/crawl" \
    -H "Content-Type: application/json" \
    -d "{
        \"url\": \"$SOURCE_URL\",
        \"output_format\": \"markdown\",
        \"max_depth\": 2,
        \"same_domain\": true
    }")

CONTENT=$(echo "$CRAWL_RESPONSE" | jq -r '.markdown // empty')

if [ -z "$CONTENT" ]; then
    log_error "Scraping fallito: risposta vuota"
    echo "$CRAWL_RESPONSE" >> "$LOG_FILE"
    exit 1
fi

CONTENT_LENGTH=${#CONTENT}
log "Ottenuti $CONTENT_LENGTH caratteri"

# Step 4: Verifica contenuto
if [ "$CONTENT_LENGTH" -lt 100 ]; then
    log_error "Contenuto troppo corto ($CONTENT_LENGTH chars), possibile errore"
    exit 1
fi

# Step 5: Embedding
log "Embedding nel workspace $WORKSPACE..."

TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# Prepara contenuto con metadata (escape per JSON)
CONTENT_WITH_META="---
source: $SOURCE_URL
updated: $TIMESTAMP
type: scheduled-update
---

$CONTENT"

# Escape per JSON
CONTENT_JSON=$(echo "$CONTENT_WITH_META" | jq -Rs '.')

EMBED_RESPONSE=$(curl -s --max-time 120 -X POST "$ANYTHINGLLM_URL/api/v1/workspace/$WORKSPACE/embed-text" \
    -H "Authorization: Bearer $ANYTHINGLLM_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"texts\": [$CONTENT_JSON]}")

# Verifica errori
if echo "$EMBED_RESPONSE" | jq -e '.error' &> /dev/null; then
    ERROR_MSG=$(echo "$EMBED_RESPONSE" | jq -r '.error')
    log_error "Errore embedding: $ERROR_MSG"
    exit 1
fi

log "Embedding completato"

# Step 6: Completamento
log "=========================================="
log "Aggiornamento completato con successo!"
log "=========================================="

exit 0
