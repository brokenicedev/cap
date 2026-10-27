# CAP — roadmap

## Già in MVP (0.1.0)

- App solo menu bar (`LSUIElement`)
- Monitor pasteboard (polling)
- Storico SQLite in `~/Library/Application Support/CAP/`
- Ricerca, star, incolla con riattivazione app + ⌘V (Accessibilità)
- Pannello unico: toolbar e ⌘⇧V
- Gruppi personalizzati (nome, colore, ⌘1–9)
- Preferenze: limite storologia, shortcut “torna a Generale”, chiudi dopo incolla, avvio al login
- Sandbox base

## Prossime fasi (ordine suggerito)

### Fase 1 — UX clipboard

- [ ] Incolla come solo testo
- [ ] Anteprima immagini e RTF più ricca nella lista
- [ ] Deduplica intelligente e regole auto-delete
- [ ] Riordino gruppi (drag)

### Fase 2 — Shortcut

- [ ] Hotkey ⌘⇧V configurabile
- [ ] Altri shortcut personalizzabili

### Fase 3 — Dati avanzati

- [ ] Payload multi-tipo per clipping (schema interno, es. JSON/Codable)
- [ ] Export/import backup (formato **.cap** — CAP Archive Package)
- [ ] Link metadata (LPMetadataProvider)

### Fase 4 — Sync (opzionale)

- [ ] CloudKit con container dedicato (`iCloud.com.francesco.CAP`)
- [ ] Changelog / merge remoto (design nuovo)

## Note prodotto

Codice, asset, formati di backup e sync sono **originali** del progetto. Obiettivo: clipboard manager completo e manutenibile.
