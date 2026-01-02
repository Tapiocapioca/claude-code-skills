# Troubleshooting web-to-rag

Guida alla risoluzione dei problemi comuni.

---

## Crawl4AI non raggiungibile

### Sintomo
```
❌ Crawl4AI: non raggiungibile
```
oppure timeout su `mcp__crawl4ai__md`

### Causa
Docker non avviato o container `crawl4ai` fermo.

### Fix

1. **Verifica Docker Desktop sia avviato**
   - Windows: icona Docker nella system tray
   - Se non c'è, avvia Docker Desktop

2. **Verifica container**
   ```bash
   docker ps | grep crawl4ai
   ```

3. **Se container non presente o fermo**
   ```bash
   docker start crawl4ai
   ```

4. **Se container non esiste**
   ```bash
   docker run -d --name crawl4ai -p 11235:11235 unclecode/crawl4ai
   ```

5. **Test connessione**
   ```bash
   curl http://localhost:11235/health
   ```

---

## AnythingLLM non raggiungibile

### Sintomo
```
❌ AnythingLLM: non raggiungibile
```
oppure errore su operazioni workspace

### Causa
Container `anythingllm` fermo o porta 3001 occupata.

### Fix

1. **Verifica container**
   ```bash
   docker ps | grep anythingllm
   ```

2. **Se fermo**
   ```bash
   docker start anythingllm
   ```

3. **Se porta occupata**
   ```bash
   # Trova processo sulla porta
   netstat -ano | findstr :3001

   # Su Linux/Mac
   lsof -i :3001
   ```

4. **Test connessione**
   ```bash
   curl http://localhost:3001/api/health
   ```

---

## Errore "Client not initialized"

### Sintomo
```
Error: AnythingLLM client not initialized
```

### Causa
Il server MCP AnythingLLM richiede inizializzazione ad ogni sessione.

### Fix
Esegui:
```
mcp__anythingllm__initialize_anythingllm
  apiKey: "TZZAC6K-Q8K4DJ6-NBP90YN-DY52YAQ"
  baseUrl: "http://localhost:3001"
```

---

## Errore 403 Forbidden durante scraping

### Sintomo
Crawl4AI restituisce 403 su alcune pagine.

### Causa
Il sito blocca bot/scraper automatici.

### Fix

1. **Prova con headers custom** (se Crawl4AI lo supporta)

2. **Usa Playwright come fallback**
   ```
   mcp__plugin_playwright_playwright__browser_navigate
     url: "https://sito-bloccato.com"

   mcp__plugin_playwright_playwright__browser_snapshot
   ```

3. **Rispetta robots.txt**
   - Alcuni siti lo richiedono
   - Verifica: `https://sito.com/robots.txt`

---

## Rate Limit Exceeded (429)

### Sintomo
Errore 429 o flickering della console.

### Causa
Troppe richieste parallele (superato limite 10 RPM).

### Fix

1. **STOP immediato** - non fare altre richieste
2. **Attendi 60 secondi**
3. **Riduci parallelismo**
   - Max 3 URL per batch (non 4+)
   - Aspetta risposta prima del prossimo batch

---

## Contenuto vuoto dopo scraping

### Sintomo
Crawl4AI restituisce markdown vuoto o quasi.

### Causa
- Sito usa JavaScript pesante per rendering
- Contenuto caricato dinamicamente
- Anti-bot attivo

### Fix

1. **Usa Playwright** per rendering JavaScript
   ```
   browser_navigate → browser_snapshot
   ```

2. **Aspetta caricamento** con Playwright
   ```
   mcp__plugin_playwright_playwright__browser_wait_for
     text: "contenuto atteso"
   ```

---

## Workspace non trovato

### Sintomo
```
Workspace 'nome' not found
```

### Fix

1. **Lista workspace esistenti**
   ```
   mcp__anythingllm__list_workspaces
   ```

2. **Verifica nome esatto** (case-sensitive, usa slug)

3. **Crea se non esiste**
   ```
   mcp__anythingllm__create_workspace
     name: "nome-workspace"
   ```

---

## Docker Desktop non si avvia

### Sintomo
Docker Desktop non parte o crasha.

### Fix Windows

1. **Riavvia servizio Docker**
   ```powershell
   Restart-Service docker
   ```

2. **Verifica virtualizzazione attiva** nel BIOS

3. **WSL2 aggiornato**
   ```bash
   wsl --update
   ```

4. **Reset Docker Desktop**
   - Settings → Troubleshoot → Reset to factory defaults

---

## Embedding fallisce silenziosamente

### Sintomo
`embed_text` sembra funzionare ma documenti non appaiono.

### Fix

1. **Verifica workspace corretto**
   ```
   mcp__anythingllm__list_documents
     slug: "nome-workspace"
   ```

2. **Contenuto troppo grande?**
   - Split in chunks < 50KB

3. **Formato testo corretto?**
   - Deve essere array di stringhe: `["testo1", "testo2"]`
