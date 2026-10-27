# Rilasciare una nuova versione di CAP

CAP si distribuisce fuori dall'App Store come **DMG firmato Developer ID e notarizzato**, pubblicato sulle **GitHub Releases**.
Gli utenti ricevono gli aggiornamenti in-app tramite **[Sparkle 2](https://sparkle-project.org)**.

```text
Scripts/release-dmg.sh
  archive Release ─► export Developer ID ─► notarizza + staple app
  ─► create-dmg ─► firma + notarizza + staple DMG
  ─► sign_update (EdDSA Sparkle) ─► nuovo <item> in appcast.xml
  ─► (--publish) GitHub Release vX.Y.Z + push di appcast.xml su main
```

| Cosa | Dove |
|---|---|
| Feed Sparkle | [`appcast.xml`](../appcast.xml) → `https://raw.githubusercontent.com/brokenicedev/cap/main/appcast.xml` (`SUFeedURL` in `CAP/Info.plist`) |
| DMG | `https://github.com/brokenicedev/cap/releases/download/vX.Y.Z/CAP-X.Y.Z.dmg` |
| Chiave pubblica Sparkle | `SUPublicEDKey` in `CAP/Info.plist` |
| Chiave privata Sparkle | Portachiavi (account `cap`) + backup in `secrets/sparkle/` (gitignored) |

> Il repository deve essere **pubblico**: l'app scarica `appcast.xml` e i DMG senza autenticazione.

## Una tantum

1. **Strumenti**

   ```bash
   brew install create-dmg gh
   gh auth login
   ```

2. **Certificato Developer ID** — in Xcode: *Settings → Accounts → Brokenice Srl → Manage Certificates → + → Developer ID Application* (oppure lascia che Xcode lo gestisca: lo script usa `-allowProvisioningUpdates`).

3. **Credenziali per la notarizzazione** — crea una *password specifica per app* su [appleid.apple.com](https://appleid.apple.com), poi:

   ```bash
   xcrun notarytool store-credentials cap-notary \
     --apple-id "tua-email@example.com" \
     --team-id 9V7GQ329MP \
     --password "xxxx-xxxx-xxxx-xxxx"
   ```

4. **Chiavi Sparkle** — già generate. Su un nuovo Mac importa il backup:

   ```bash
   generate_keys --account cap -f secrets/sparkle/ed25519-priv.key
   ```

   Per generarle da zero: `./Scripts/generate-sparkle-keys.sh` (scrive anche `SUPublicEDKey` in Info.plist).

   ⚠️ **Non perdere la chiave privata**: senza, le installazioni esistenti non potranno più aggiornarsi. Tienine una copia in un password manager.

## Ogni rilascio

```bash
# 1. Versione + build (la build deve crescere sempre, Sparkle confronta quella)
./Scripts/bump-version.sh 0.2.0

# 2. Build, DMG, notarizzazione, appcast — e pubblicazione
./Scripts/release-dmg.sh --notes "Incolla come solo testo. Hotkey configurabile." --publish
```

Con `--publish` lo script crea la GitHub Release `v0.2.0` con il DMG, poi fa commit e push di `appcast.xml` (e della versione) su `main`. Da quel momento gli utenti ricevono l'aggiornamento.

Senza `--publish` lo script si ferma prima e stampa i comandi da eseguire a mano — **prima** la GitHub Release, **poi** il push di `appcast.xml`, altrimenti Sparkle proverebbe a scaricare un DMG che non esiste ancora.

Note lunghe: `--notes-file note.md` (paragrafi separati da una riga vuota).

### Alternativa: archive e notarizzazione da Xcode

Non servono le credenziali `cap-notary`: Xcode notarizza con il tuo account.

1. `./Scripts/bump-version.sh 0.2.0`
2. Xcode → scheme **CAP**, destinazione **Any Mac** → **Product → Archive**
3. Organizer → **Distribute App → Direct Distribution** → attendi la notarizzazione → **Export** (es. sul Desktop)
4. Lo script fa DMG, firma Sparkle, appcast e pubblicazione:

   ```bash
   ./Scripts/release-dmg.sh --app ~/Desktop/CAP/CAP.app --notes "Novità…" --publish
   ```

### Prova locale

```bash
./Scripts/release-dmg.sh --skip-notarize
```

Crea `dist/CAP-X.Y.Z.dmg` firmato ma non notarizzato e **non** tocca `appcast.xml`.

## Problemi comuni

| Problema | Soluzione |
|---|---|
| `La build N è già in appcast.xml` | Esegui `./Scripts/bump-version.sh` |
| `No Keychain password item found for profile: cap-notary` | Vedi *Credenziali per la notarizzazione* sopra |
| Notarizzazione rifiutata | `xcrun notarytool log <submission-id> --keychain-profile cap-notary` |
| `sign_update` non trova la chiave | Importa il backup con `generate_keys --account cap -f …` oppure `SPARKLE_KEY_FILE=… ./Scripts/release-dmg.sh` |
| Aggiornamento non proposto | Verifica che `appcast.xml` su `main` contenga la nuova build e che la build installata sia una Release (in Debug Sparkle è disattivato) |
