<#
.SYNOPSIS
    Template per aggiornamento automatico workspace RAG
.DESCRIPTION
    Questo script viene copiato e personalizzato da Claude quando l'utente
    richiede uno schedule di aggiornamento.

    NON MODIFICARE questo file - Claude creerà copie personalizzate.
.NOTES
    Placeholder da sostituire:
    - {WORKSPACE}: nome del workspace
    - {SOURCE_URL}: URL sorgente
    - {API_KEY}: chiave API AnythingLLM
    - {DATE}: data creazione
#>

$ErrorActionPreference = "Stop"

# ============================================
# CONFIGURAZIONE - Sostituita da Claude
# ============================================
$WORKSPACE = "{WORKSPACE}"
$SOURCE_URL = "{SOURCE_URL}"
$ANYTHINGLLM_URL = "http://localhost:3001"
$ANYTHINGLLM_KEY = "{API_KEY}"
$CRAWL4AI_URL = "http://localhost:11235"
$LOG_FILE = "$env:USERPROFILE\.claude\logs\rag-updates.log"

# ============================================
# FUNZIONI HELPER
# ============================================

# Crea directory log se non esiste
$logDir = Split-Path $LOG_FILE
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}

function Write-Log {
    param($Message, [switch]$Error)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $level = if ($Error) { "ERROR" } else { "INFO" }
    "$timestamp [$WORKSPACE] [$level] $Message" | Add-Content $LOG_FILE
    if ($Error) {
        Write-Host $Message -ForegroundColor Red
    } else {
        Write-Host $Message
    }
}

function Test-DockerRunning {
    $dockerInfo = docker info 2>&1
    return $LASTEXITCODE -eq 0
}

function Start-DockerDesktop {
    $dockerPath = "C:\Program Files\Docker\Docker\Docker Desktop.exe"
    if (Test-Path $dockerPath) {
        Start-Process $dockerPath
        Write-Log "Avviato Docker Desktop, attendo 30 secondi..."
        Start-Sleep -Seconds 30
        return Test-DockerRunning
    }
    return $false
}

function Start-Container {
    param($Name)
    $running = docker ps --format "{{.Names}}" | Select-String -Pattern "^$Name$"
    if (-not $running) {
        Write-Log "Avvio container $Name..."
        docker start $Name 2>&1 | Out-Null
        Start-Sleep -Seconds 5
    }
}

# ============================================
# MAIN
# ============================================

Write-Log "=========================================="
Write-Log "Inizio aggiornamento RAG"
Write-Log "Workspace: $WORKSPACE"
Write-Log "Sorgente: $SOURCE_URL"
Write-Log "=========================================="

# Step 1: Verifica Docker
Write-Log "Verifico Docker..."
if (-not (Test-DockerRunning)) {
    Write-Log "Docker non attivo, provo ad avviare..."
    if (-not (Start-DockerDesktop)) {
        Write-Log "Impossibile avviare Docker" -Error
        exit 1
    }
}
Write-Log "Docker OK"

# Step 2: Verifica container
Start-Container "crawl4ai"
Start-Container "anythingllm"
Write-Log "Container OK"

# Step 3: Scraping
Write-Log "Scraping di $SOURCE_URL..."
try {
    $crawlBody = @{
        url = $SOURCE_URL
        output_format = "markdown"
        max_depth = 2
        same_domain = $true
    } | ConvertTo-Json

    $crawlResult = Invoke-RestMethod -Uri "$CRAWL4AI_URL/crawl" `
        -Method POST `
        -ContentType "application/json" `
        -Body $crawlBody `
        -TimeoutSec 300

    if ($crawlResult.markdown) {
        $content = $crawlResult.markdown
        Write-Log "Ottenuti $($content.Length) caratteri"
    } else {
        Write-Log "Scraping fallito: risposta vuota" -Error
        exit 1
    }
} catch {
    Write-Log "Errore scraping: $_" -Error
    exit 1
}

# Step 4: Verifica contenuto
if ($content.Length -lt 100) {
    Write-Log "Contenuto troppo corto ($($content.Length) chars), possibile errore" -Error
    exit 1
}

# Step 5: Embedding
Write-Log "Embedding nel workspace $WORKSPACE..."
try {
    $headers = @{
        "Authorization" = "Bearer $ANYTHINGLLM_KEY"
        "Content-Type" = "application/json"
    }

    # Aggiungi metadata
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $contentWithMeta = @"
---
source: $SOURCE_URL
updated: $timestamp
type: scheduled-update
---

$content
"@

    $embedBody = @{
        texts = @($contentWithMeta)
    } | ConvertTo-Json -Depth 10

    $embedResult = Invoke-RestMethod -Uri "$ANYTHINGLLM_URL/api/v1/workspace/$WORKSPACE/embed-text" `
        -Method POST `
        -Headers $headers `
        -Body $embedBody `
        -TimeoutSec 120

    Write-Log "Embedding completato"
} catch {
    Write-Log "Errore embedding: $_" -Error
    exit 1
}

# Step 6: Completamento
Write-Log "=========================================="
Write-Log "Aggiornamento completato con successo!"
Write-Log "=========================================="

exit 0
