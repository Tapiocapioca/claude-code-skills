# Ottimizzazione Script Installazione Prerequisites

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Migliorare robustezza, manutenibilità e UX dello script `install-prerequisites.ps1`

**Architecture:** Refactoring in funzioni riutilizzabili, aggiunta health checks, miglioramento error handling, eliminazione codice duplicato

**Tech Stack:** PowerShell 5.1+, Docker, Git

---

## Problemi Identificati

| # | Problema | Linee | Impatto |
|---|----------|-------|---------|
| 1 | Codice duplicato per container Docker | 252-340 | Manutenibilità |
| 2 | Nessun health check dopo creazione container | 342-345 | Affidabilità |
| 3 | Build Docker sopprime output (`Out-Null`) | 275, 283, 320, 328 | Debug difficile |
| 4 | Clone repository duplicato per yt-dlp e whisper | 281, 326 | Spreco risorse |
| 5 | Nessun timeout per attesa Docker | 161-162 | Può bloccarsi |
| 6 | `refreshenv` non sempre funziona in PowerShell | 108, 122, 136 | PATH non aggiornato |
| 7 | Link PREREQUISITES.md errato nel messaggio finale | 557 | UX |
| 8 | Manca verifica health endpoint container | 456-493 | Falsi positivi |

---

## Task 1: Creare Funzione Helper per Container Docker

**Files:**
- Modify: `skills/web-to-rag/install-prerequisites.ps1:36-39`

**Step 1: Aggiungere funzioni helper dopo le funzioni Write-***

```powershell
function Test-ContainerExists {
    param([string]$Name)
    $exists = docker ps -a --format '{{.Names}}' | Select-String -Pattern "^$Name$"
    return $null -ne $exists
}

function Test-ContainerRunning {
    param([string]$Name)
    $running = docker ps --format '{{.Names}}' | Select-String -Pattern "^$Name$"
    return $null -ne $running
}

function Start-ContainerIfStopped {
    param([string]$Name)
    if (-not (Test-ContainerRunning $Name)) {
        Write-Warn "Starting $Name container..."
        docker start $Name
        return $true
    }
    return $false
}

function Test-ContainerHealth {
    param(
        [string]$Name,
        [string]$HealthUrl,
        [int]$TimeoutSeconds = 60,
        [int]$IntervalSeconds = 5
    )

    $elapsed = 0
    while ($elapsed -lt $TimeoutSeconds) {
        try {
            $response = Invoke-WebRequest -Uri $HealthUrl -TimeoutSec 5 -UseBasicParsing -ErrorAction Stop
            if ($response.StatusCode -eq 200) {
                return $true
            }
        } catch {
            # Container not ready yet
        }
        Start-Sleep -Seconds $IntervalSeconds
        $elapsed += $IntervalSeconds
    }
    return $false
}
```

**Step 2: Verificare che lo script sia sintatticamente corretto**

Run: `powershell -NoProfile -Command "& { $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content 'skills/web-to-rag/install-prerequisites.ps1' -Raw), [ref]$null) }"`
Expected: No output (no syntax errors)

**Step 3: Commit**

```bash
git add skills/web-to-rag/install-prerequisites.ps1
git commit -m "refactor: add container helper functions"
```

---

## Task 2: Refactoring Setup Container con Funzione Generica

**Files:**
- Modify: `skills/web-to-rag/install-prerequisites.ps1:196-345`

**Step 1: Aggiungere funzione generica per setup container**

Aggiungere dopo le funzioni helper del Task 1:

```powershell
function Install-DockerContainer {
    param(
        [string]$Name,
        [string]$Image,
        [string]$Port,
        [string]$HealthUrl,
        [hashtable]$ExtraArgs = @{},
        [string]$BuildContext = $null
    )

    Write-Step "Setting up $Name container..."

    if (Test-ContainerExists $Name) {
        Write-OK "$Name container exists"
        Start-ContainerIfStopped $Name
    } else {
        if ($BuildContext) {
            Write-Warn "Building $Name container..."
            $buildResult = docker build -t $Name $BuildContext 2>&1
            if ($LASTEXITCODE -ne 0) {
                Write-Err "Failed to build $Name: $buildResult"
                return $false
            }
            $Image = $Name
        } else {
            Write-Warn "Creating $Name container..."
        }

        # Build docker run command
        $runArgs = @("-d", "--name", $Name, "-p", $Port, "--restart", "unless-stopped")

        foreach ($key in $ExtraArgs.Keys) {
            $runArgs += $key
            if ($ExtraArgs[$key]) {
                $runArgs += $ExtraArgs[$key]
            }
        }

        $runArgs += $Image

        $runResult = docker run @runArgs 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Err "Failed to create $Name: $runResult"
            return $false
        }
        Write-OK "$Name container created"
    }

    # Health check
    if ($HealthUrl) {
        Write-Host "  Waiting for $Name to be healthy..."
        if (Test-ContainerHealth -Name $Name -HealthUrl $HealthUrl -TimeoutSeconds 60) {
            Write-OK "$Name is healthy"
        } else {
            Write-Warn "$Name health check failed (may still be starting)"
        }
    }

    return $true
}
```

**Step 2: Verificare sintassi**

Run: `powershell -NoProfile -Command "& { $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content 'skills/web-to-rag/install-prerequisites.ps1' -Raw), [ref]$null) }"`
Expected: No output

**Step 3: Commit**

```bash
git add skills/web-to-rag/install-prerequisites.ps1
git commit -m "refactor: add generic Install-DockerContainer function"
```

---

## Task 3: Refactoring Creazione Container Crawl4AI e AnythingLLM

**Files:**
- Modify: `skills/web-to-rag/install-prerequisites.ps1:199-250`

**Step 1: Sostituire codice Crawl4AI con chiamata funzione**

Sostituire linee 199-217 con:

```powershell
if (-not $SkipDocker) {
    # Crawl4AI
    Install-DockerContainer `
        -Name "crawl4ai" `
        -Image "unclecode/crawl4ai:latest" `
        -Port "11235:11235" `
        -HealthUrl "http://localhost:11235/health"
```

**Step 2: Sostituire codice AnythingLLM**

Sostituire linee 219-250 con:

```powershell
    # AnythingLLM - needs storage volume
    $storageDir = "$env:USERPROFILE\.anythingllm\storage"
    if (-not (Test-Path $storageDir)) {
        New-Item -ItemType Directory -Path $storageDir -Force | Out-Null
    }

    Install-DockerContainer `
        -Name "anythingllm" `
        -Image "mintplexlabs/anythingllm:latest" `
        -Port "3001:3001" `
        -HealthUrl "http://localhost:3001/api/health" `
        -ExtraArgs @{
            "-e" = "STORAGE_DIR=/app/server/storage"
            "-v" = "${storageDir}:/app/server/storage"
        }
```

**Step 3: Verificare sintassi**

Run: `powershell -NoProfile -Command "& { $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content 'skills/web-to-rag/install-prerequisites.ps1' -Raw), [ref]$null) }"`
Expected: No output

**Step 4: Commit**

```bash
git add skills/web-to-rag/install-prerequisites.ps1
git commit -m "refactor: use Install-DockerContainer for crawl4ai and anythingllm"
```

---

## Task 4: Refactoring Container yt-dlp e whisper con Build Locale

**Files:**
- Modify: `skills/web-to-rag/install-prerequisites.ps1:252-340`

**Step 1: Aggiungere funzione per build locale**

```powershell
function Get-LocalBuildContext {
    param(
        [string]$ContainerName,
        [string]$SubPath
    )

    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    $localPath = Join-Path $scriptDir $SubPath

    if (Test-Path (Join-Path $localPath "Dockerfile")) {
        return $localPath
    }

    # Clone repo if needed
    $tempDir = "$env:TEMP\claude-code-skills-temp"
    if (-not (Test-Path $tempDir)) {
        Write-Host "  Cloning repository for build..."
        git clone --depth 1 https://github.com/Tapiocapioca/claude-code-skills.git $tempDir 2>&1 | Out-Null
    }

    return Join-Path $tempDir "skills\web-to-rag\$SubPath"
}
```

**Step 2: Sostituire codice yt-dlp-server e whisper-server**

```powershell
    # yt-dlp-server
    $ytdlpContext = Get-LocalBuildContext -ContainerName "yt-dlp-server" -SubPath "infrastructure\docker\yt-dlp"
    Install-DockerContainer `
        -Name "yt-dlp-server" `
        -Image "yt-dlp-server" `
        -Port "8001:8001" `
        -HealthUrl "http://localhost:8001/health" `
        -BuildContext $ytdlpContext

    # whisper-server
    $whisperContext = Get-LocalBuildContext -ContainerName "whisper-server" -SubPath "infrastructure\docker\whisper"
    Install-DockerContainer `
        -Name "whisper-server" `
        -Image "whisper-server" `
        -Port "8002:8002" `
        -HealthUrl "http://localhost:8002/health" `
        -BuildContext $whisperContext

    # Cleanup temp clone
    $tempDir = "$env:TEMP\claude-code-skills-temp"
    if (Test-Path $tempDir) {
        Remove-Item -Recurse -Force $tempDir
    }
}
```

**Step 3: Rimuovere attesa fissa 30 secondi (ora abbiamo health checks)**

Rimuovere linee 342-345:
```powershell
    # Wait for containers to be healthy
    Write-Host "Waiting for containers to become healthy..."
    Start-Sleep -Seconds 30
```

**Step 4: Verificare sintassi e commit**

```bash
git add skills/web-to-rag/install-prerequisites.ps1
git commit -m "refactor: use Install-DockerContainer for yt-dlp and whisper with health checks"
```

---

## Task 5: Migliorare Refresh Environment

**Files:**
- Modify: `skills/web-to-rag/install-prerequisites.ps1:108,122,136`

**Step 1: Aggiungere funzione robusta per refresh PATH**

Dopo le funzioni Write-*, aggiungere:

```powershell
function Update-PathEnvironment {
    $machinePath = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
    $userPath = [System.Environment]::GetEnvironmentVariable("Path", "User")
    $env:Path = "$machinePath;$userPath"

    # Also try refreshenv if available (from Chocolatey)
    if (Get-Command refreshenv -ErrorAction SilentlyContinue) {
        try { refreshenv } catch { }
    }
}
```

**Step 2: Sostituire `refreshenv` con `Update-PathEnvironment`**

Sostituire tutte le occorrenze di `refreshenv` (linee 108, 122, 136) con:
```powershell
Update-PathEnvironment
```

**Step 3: Commit**

```bash
git add skills/web-to-rag/install-prerequisites.ps1
git commit -m "fix: use robust PATH refresh instead of refreshenv"
```

---

## Task 6: Migliorare Verifica Finale con Health Checks

**Files:**
- Modify: `skills/web-to-rag/install-prerequisites.ps1:456-521`

**Step 1: Sostituire verifica container con health checks reali**

```powershell
# =============================================================================
# STEP 9: Verify Installation
# =============================================================================
Write-Step "Verifying installation..."

$allOK = $true

# Check Docker containers with health endpoints
if (-not $SkipDocker) {
    $containers = @(
        @{ Name = "crawl4ai"; Url = "http://localhost:11235/health"; Desc = "Crawl4AI" }
        @{ Name = "anythingllm"; Url = "http://localhost:3001/api/health"; Desc = "AnythingLLM" }
        @{ Name = "yt-dlp-server"; Url = "http://localhost:8001/health"; Desc = "yt-dlp-server (YouTube)" }
        @{ Name = "whisper-server"; Url = "http://localhost:8002/health"; Desc = "whisper-server (audio)" }
    )

    foreach ($container in $containers) {
        if (Test-ContainerRunning $container.Name) {
            try {
                $response = Invoke-WebRequest -Uri $container.Url -TimeoutSec 5 -UseBasicParsing -ErrorAction Stop
                if ($response.StatusCode -eq 200) {
                    Write-OK "$($container.Desc) running and healthy"
                } else {
                    Write-Warn "$($container.Desc) running but health check returned $($response.StatusCode)"
                }
            } catch {
                Write-Warn "$($container.Desc) running but health endpoint not responding"
            }
        } else {
            Write-Err "$($container.Desc) NOT running"
            $allOK = $false
        }
    }
}
```

**Step 2: Commit**

```bash
git add skills/web-to-rag/install-prerequisites.ps1
git commit -m "feat: add real health checks in verification step"
```

---

## Task 7: Correggere Link Finale

**Files:**
- Modify: `skills/web-to-rag/install-prerequisites.ps1:557`

**Step 1: Correggere URL PREREQUISITES.md**

Sostituire:
```powershell
Write-Host "https://github.com/Tapiocapioca/claude-code-skills/blob/master/PREREQUISITES.md"
```

Con:
```powershell
Write-Host "https://github.com/Tapiocapioca/claude-code-skills/blob/master/skills/web-to-rag/PREREQUISITES.md"
```

**Step 2: Commit**

```bash
git add skills/web-to-rag/install-prerequisites.ps1
git commit -m "fix: correct PREREQUISITES.md link in final message"
```

---

## Task 8: Test Completo

**Files:**
- Test: `skills/web-to-rag/install-prerequisites.ps1`

**Step 1: Verificare sintassi PowerShell**

```powershell
$null = [System.Management.Automation.PSParser]::Tokenize((Get-Content 'skills/web-to-rag/install-prerequisites.ps1' -Raw), [ref]$null)
```

**Step 2: Test dry-run (con -WhatIf se supportato, altrimenti review manuale)**

Verificare che:
- [ ] Lo script si avvia senza errori di sintassi
- [ ] Le funzioni helper sono definite correttamente
- [ ] I container esistenti vengono rilevati
- [ ] I health checks funzionano

**Step 3: Commit finale**

```bash
git add -A
git commit -m "test: verify installer refactoring complete"
```

---

## Riepilogo Modifiche

| Task | Descrizione | LOC Stimate |
|------|-------------|-------------|
| 1 | Funzioni helper container | +40 |
| 2 | Funzione Install-DockerContainer | +50 |
| 3 | Refactor crawl4ai/anythingllm | -50, +20 |
| 4 | Refactor yt-dlp/whisper | -90, +30 |
| 5 | Update-PathEnvironment | +10, -3 |
| 6 | Health checks in verifica | -30, +25 |
| 7 | Fix link | +1, -1 |
| 8 | Test | 0 |

**Riduzione netta stimata:** ~50 linee (da 559 a ~510)
**Miglioramenti:** DRY, health checks reali, error handling, manutenibilità
