# Strategie di Crawl

Guida alle strategie di crawling per diversi tipi di sito.

---

## Strategia 1: Documentazione con Sitemap

### Quando usare
- Sito ha `/sitemap.xml` accessibile
- Documentazione tecnica strutturata
- Esempi: docs.python.org, fastapi.tiangolo.com

### Workflow

```
1. Fetch sitemap
   GET {base_url}/sitemap.xml

2. Parsa XML
   Estrai tutti gli <loc> tags

3. Filtra URL
   - Mantieni: /docs/, /guide/, /tutorial/, /reference/
   - Escludi: /api/, /changelog/, /blog/, /news/

4. Ordina per path
   Raggruppa per sezione (getting-started, advanced, api-ref)

5. Crawl in batch
   - 3 URL per batch (rate limit)
   - Aspetta risposta
   - Prossimo batch
```

### Esempio sitemap parsing
```xml
<urlset>
  <url><loc>https://docs.example.com/intro</loc></url>
  <url><loc>https://docs.example.com/guide/basics</loc></url>
  <url><loc>https://docs.example.com/api/reference</loc></url>
</urlset>
```

Estrai: `["/intro", "/guide/basics", "/api/reference"]`

---

## Strategia 2: Documentazione Strutturata (no sitemap)

### Quando usare
- URL contiene `/docs/` o `/documentation/`
- Pagina ha sidebar/TOC con link
- Sitemap non disponibile

### Workflow

```
1. Identifica pagina indice
   - /docs/
   - /docs/index
   - /documentation/

2. Estrai link dalla sidebar
   Cerca elementi: nav, aside, .sidebar, .toc

3. Filtra link
   - Solo stesso dominio
   - Solo path /docs/*
   - No anchor links (#section)

4. Deduplica
   Normalizza URL (rimuovi trailing slash, query params)

5. Crawl in ordine di apparizione
   Mantiene struttura logica del docs
```

### Pattern comuni di sidebar
```html
<!-- Pattern 1: nav con lista -->
<nav class="sidebar">
  <ul>
    <li><a href="/docs/intro">Intro</a></li>
    <li><a href="/docs/setup">Setup</a></li>
  </ul>
</nav>

<!-- Pattern 2: nested sections -->
<aside>
  <section>
    <h3>Getting Started</h3>
    <a href="/docs/install">Install</a>
  </section>
</aside>
```

---

## Strategia 3: Siti Generici (BFS)

### Quando usare
- Nessun sitemap
- Nessuna struttura docs riconoscibile
- Blog, siti aziendali, wiki

### Workflow

```
1. Inizia da URL fornito (seed)

2. Fetch pagina
   mcp__crawl4ai__md(url)

3. Estrai link interni
   - Stesso dominio
   - No assets (.css, .js, .png, .jpg, .svg, .pdf)
   - No mailto:, tel:, javascript:

4. Aggiungi a coda (BFS)
   - Se non già visitato
   - Se depth < max_depth

5. Continua fino a:
   - Coda vuota
   - max_pages raggiunto
   - max_depth raggiunto
```

### Parametri consigliati
| Tipo sito | max_depth | max_pages |
|-----------|-----------|-----------|
| Blog piccolo | 2 | 50 |
| Sito aziendale | 2 | 100 |
| Wiki | 3 | 200 |
| Documentazione | 3 | 150 |

---

## Strategia 4: Single Page Application (SPA)

### Quando usare
- Sito usa React, Vue, Angular
- Contenuto caricato via JavaScript
- Crawl4AI restituisce contenuto vuoto

### Workflow

```
1. Usa Playwright invece di Crawl4AI

2. Navigate
   browser_navigate(url)

3. Aspetta rendering
   browser_wait_for(text: "contenuto atteso")
   oppure
   browser_wait_for(time: 3)

4. Snapshot
   browser_snapshot → ottieni struttura

5. Estrai contenuto
   Analizza snapshot per testo principale

6. Chiudi
   browser_close
```

### Limitazioni
- Più lento (5-10s per pagina vs 1-2s)
- Non parallelizzabile facilmente
- Usa per siti problematici, non come default

---

## Rate Limiting

### Vincoli CLAUDE.md
```
⚠️ 10 RPM (richieste/minuto) verso provider AI
⚠️ Max 4 tool calls paralleli
```

### Implementazione pratica
```
Batch size: 3 URL
Wait: risposta completa prima del prossimo batch
Delay extra: 1s se > 30 pagine totali
```

### Esempio timing
```
Batch 1: url1, url2, url3 → ~3 secondi
Batch 2: url4, url5, url6 → ~3 secondi
...
50 pagine ≈ 17 batch ≈ 1-2 minuti
```

---

## Deduplicazione

### Normalizzazione URL
```
Rimuovi:
- Trailing slash: /page/ → /page
- Fragment: /page#section → /page
- Query params non significativi: ?ref=twitter

Mantieni:
- Query params di paginazione: ?page=2
- Query params di contenuto: ?id=123
```

### Deduplicazione contenuto
```
Se due pagine hanno contenuto > 90% simile:
- Mantieni solo la prima
- Log la duplicata come "skipped"
```

---

## Robots.txt

### Quando rispettarlo
- Siti pubblici con robots.txt esplicito
- Crawling massivo (> 100 pagine)
- Siti che bloccano senza motivo apparente

### Parsing
```
User-agent: *
Disallow: /admin/
Disallow: /private/
Allow: /docs/

→ Escludi /admin/*, /private/*
→ Includi /docs/*
```

### Nota
La maggior parte dei docs pubblici non blocca crawling.
Rispetta robots.txt solo se problemi o per cortesia.

---

## Gestione Errori per Strategia

| Errore | Azione |
|--------|--------|
| 404 Not Found | Skip, log warning |
| 403 Forbidden | Prova Playwright, poi skip |
| 429 Rate Limit | Pausa 60s, riduci batch |
| 500 Server Error | Retry 1x, poi skip |
| Timeout | Retry 1x con timeout doppio |
| Contenuto vuoto | Prova Playwright |

---

## Esempi Completi

### Esempio: FastAPI docs
```
URL: https://fastapi.tiangolo.com
Tipo: docs-sitemap
Sitemap: https://fastapi.tiangolo.com/sitemap.xml
Pagine: ~80
Tempo stimato: 3-4 minuti
```

### Esempio: Blog medio
```
URL: https://blog.example.com
Tipo: generic
Strategia: BFS depth=2
Pagine stimate: 30-50
Tempo stimato: 1-2 minuti
```

### Esempio: SPA React
```
URL: https://app.example.com/docs
Tipo: spa
Strategia: Playwright
Pagine: variabile
Tempo stimato: 5-10 minuti (più lento)
```
