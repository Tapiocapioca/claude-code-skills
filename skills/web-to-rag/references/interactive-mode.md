# Modalità Interattiva - Guida Dettagliata

Questa guida descrive la selezione interattiva delle pagine prima del crawl.

## Quando Attivare

La modalità interattiva si attiva quando:

1. **Utente lo richiede esplicitamente:**
   - "Mostrami le pagine prima di importare"
   - "Voglio scegliere quali pagine scaricare"
   - "Fammi vedere cosa c'è prima"

2. **Sito ha molte pagine (> 20):**
   - Claude chiede: "Ho trovato 45 pagine. Vuoi selezionare quali importare?"

3. **Utente vuole escludere sezioni:**
   - "Importa ma escludi il changelog"
   - "Solo la documentazione API"

---

## Workflow Interattivo

### Step 1: Crawl Solo Link

Prima di scaricare contenuti, estrai solo i link:

```bash
# Con Crawl4AI - ottieni solo link
mcp__crawl4ai__crawl
  url: "https://example.com/docs"
  params: { "only_links": true, "max_depth": 2 }
```

### Step 2: Mostra Lista Numerata

Presenta all'utente una lista chiara:

```
Trovate 45 pagine su docs.example.com:

 #  Path                          Sezione
────────────────────────────────────────────
[x]  1. /getting-started          Intro
[x]  2. /installation             Intro
[x]  3. /quickstart               Intro
[x]  4. /api/overview             API
[x]  5. /api/authentication       API
[x]  6. /api/endpoints            API
[x]  7. /api/errors               API
[ ]  8. /changelog                Meta
[ ]  9. /changelog/2024           Meta
[ ] 10. /blog/announcement        Blog
[ ] 11. /blog/tips                Blog
...
[ ] 45. /community                Community

[x] = selezionata (default)
[ ] = deselezionata

Seleziona (default: tutte):
```

### Step 3: Interpreta Input Utente

L'utente può usare diversi formati:

| Input | Azione |
|-------|--------|
| `1,3,5` | Seleziona pagine 1, 3, 5 |
| `1-10` | Seleziona pagine da 1 a 10 |
| `1-10,15,20-25` | Combina range e singole |
| `api/*` | Seleziona tutte con /api/ nel path |
| `docs/*` | Seleziona tutte con /docs/ |
| `escludi changelog` | Deseleziona pagine con "changelog" |
| `escludi blog,community` | Deseleziona multiple sezioni |
| `solo api` | Solo pagine con "api" |
| `tutte` | Seleziona tutte le pagine |
| `nessuna` | Deseleziona tutte |
| `inverti` | Inverti selezione corrente |
| `Enter` (vuoto) | Usa default (tutte selezionate) |

### Step 4: Conferma Selezione

```
Hai selezionato 12 pagine:
- /getting-started
- /installation
- /quickstart
- /api/overview
- /api/authentication
- /api/endpoints
- /api/errors
- /guides/basic
- /guides/advanced
- /guides/troubleshooting
- /faq
- /support

Procedo con il download? (s/n)
```

### Step 5: Procedi con Selezione

Solo le pagine selezionate vengono crawlate ed embeddate.

---

## Logica di Pattern Matching

### Implementazione Pattern

```python
import re
from fnmatch import fnmatch

def match_pattern(path, pattern):
    """Verifica se un path matcha un pattern."""

    # Pattern glob (con *)
    if '*' in pattern:
        return fnmatch(path, pattern)

    # Contiene stringa
    return pattern.lower() in path.lower()


def parse_selection(input_str, total_pages):
    """Parsa input utente e ritorna set di indici selezionati."""

    selected = set()

    # Comandi speciali
    if input_str.lower() == 'tutte':
        return set(range(1, total_pages + 1))
    if input_str.lower() == 'nessuna':
        return set()

    parts = input_str.split(',')
    for part in parts:
        part = part.strip()

        # Range (es. "1-10")
        if '-' in part and not part.startswith('-'):
            try:
                start, end = part.split('-')
                selected.update(range(int(start), int(end) + 1))
            except ValueError:
                pass

        # Singolo numero
        elif part.isdigit():
            selected.add(int(part))

    return selected


def apply_filters(pages, filters):
    """Applica filtri include/exclude."""

    result = set(range(len(pages)))

    for f in filters:
        f = f.strip().lower()

        if f.startswith('escludi '):
            pattern = f[8:]  # Rimuovi "escludi "
            result = {i for i in result if not match_pattern(pages[i], pattern)}

        elif f.startswith('solo '):
            pattern = f[5:]  # Rimuovi "solo "
            result = {i for i in result if match_pattern(pages[i], pattern)}

        elif '*' in f or '/' in f:
            # Pattern glob o path
            result = {i for i in result if match_pattern(pages[i], f)}

    return result
```

### Esempi di Pattern

| Pattern | Match | Non Match |
|---------|-------|-----------|
| `api/*` | /api/auth, /api/users | /docs/api |
| `*/api/*` | /docs/api/ref | /api-docs |
| `escludi blog` | - | /blog/*, /blog-post |
| `solo docs` | /docs/* | /api/*, /blog/* |
| `*authentication*` | /api/authentication | /auth |

---

## Gestione Interazione

### Iterazioni Multiple

L'utente può affinare la selezione:

```
> escludi blog
Rimosse 5 pagine. Selezionate: 40

> escludi changelog
Rimosse 3 pagine. Selezionate: 37

> mostra api
Pagine con "api":
  4. /api/overview
  5. /api/authentication
  6. /api/endpoints
  7. /api/errors

> solo api
Selezionate: 4

> aggiungi 1-3
Aggiunte intro. Selezionate: 7

> ok
Procedo con 7 pagine...
```

### Comandi Disponibili

| Comando | Descrizione |
|---------|-------------|
| `mostra [pattern]` | Mostra pagine che matchano |
| `aggiungi [selezione]` | Aggiungi alla selezione |
| `rimuovi [selezione]` | Rimuovi dalla selezione |
| `reset` | Torna a default (tutte) |
| `conta` | Mostra conteggio attuale |
| `lista` | Mostra selezione corrente |
| `ok` / `procedi` | Conferma e procedi |
| `annulla` | Annulla operazione |

---

## Best Practices

1. **Default sensato** - Inizia con tutte selezionate
2. **Preview chiara** - Raggruppa per sezione/categoria
3. **Conferma prima di procedere** - Mostra riepilogo finale
4. **Permetti iterazioni** - L'utente può affinare la selezione
5. **Ricorda preferenze** - Per aggiornamenti futuri, suggerisci stessa selezione

---

## Integrazione con Workspace

Se il workspace esiste già e ha documenti:

```
Il workspace "docs-example" esiste già con 30 documenti.

Opzioni:
1. Aggiungi nuove pagine (mantieni esistenti)
2. Sostituisci tutto (cancella e reimporta)
3. Aggiorna solo modificate (confronta date)
4. Annulla

Scelta:
```

---

*Ultimo aggiornamento: Gennaio 2026*
