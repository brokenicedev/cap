# CAP

**CAP** — *Copy And Paste*: clipboard history per macOS (menu bar), cronologia, gruppi personalizzati, incolla rapido nell’app precedente.

- Progetto: `CAP.xcodeproj` → app **CAP** (`CAP.app`)
- Bundle ID: `com.francesco.CAP`
- Dati: `~/Library/Application Support/CAP/`

> Se aggiorni da una build con bundle `com.francesco.CopyAndPaste`, cronologia e preferenze vengono migrate al primo avvio; in **Privacy → Accessibilità** va riattivato il toggle per la nuova app (e eventualmente **Avvio al login** nelle impostazioni).

## Requisiti

- macOS 14+
- Xcode 15+

## Build e run

```text
CAP/                    ← root del repository (cartella progetto)
  CAP.xcodeproj
  CAP/                  ← sorgenti Swift (non è l’app compilata)
    App/
    Models/
    Services/
    Controllers/
    Views/
    Utilities/
    Assets.xcassets, Info.plist, CAP.entitlements
  Scripts/
  docs/
  build/                ← output locale (gitignored)
```

Dettaglio: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

Da terminale, dalla root del repo:

```bash
cd ~/Francesco/CAP
./dev.sh
```

(`dev.sh` chiude eventuali istanze in esecuzione, compila in **Debug** e avvia **CAP Debug** da `build/DerivedData/`.)

Se sei dentro `~/Francesco/CAP/CAP` (sorgenti), torna su: `cd ..`.

Oppure apri `CAP.xcodeproj` in Xcode e premi **Run**.

### Release e installazione in Applicazioni

```bash
cd ~/Francesco/CAP
./release.sh
```

Usa **solo** `/Applications/CAP.app` dal Launchpad (icona normale, nome **CAP**).

La build **Debug** ha **barra gialla** sull’icona e si chiama **CAP Debug** — solo per sviluppo.

## Uso

- **Click sinistro** sull’icona menu bar — apre la finestra history sotto l’icona
- **Click destro** sull’icona — menu con **Impostazioni** e **Esci da CAP** (anche **⌘Q** dal menu)
- **⌘⇧V** — pannello flottante vicino al cursore (stessa UI)
- **Click** o **Invio** su un elemento per incollarlo (opzione: chiudi il pannello dopo l’incolla)
- **Generale** — tutto ciò che non è in un gruppo; **Cerca** e **Svuota** solo qui
- **⌘1 … ⌘9** — passa al gruppo corrispondente (nel pannello aperto)
- **⌘⇧,** (⌘&lt;) — torna a **Generale** (scelta alternativa in Impostazioni)
- Menu contestuale — sposta elementi tra **Generale** e i gruppi
- **Impostazioni** — crea gruppi (nome e colore), limite cronologia, avvio al login

## Roadmap

Vedi [docs/ROADMAP.md](docs/ROADMAP.md).
