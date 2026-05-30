# Text it

**App Store Links:**
- 🔒 [Datenschutzerklärung / Privacy Policy](PRIVACY.md)
- 🛠 [Support & Fehler melden](https://github.com/g0403345-oss/text-it/issues)

---

# Text it — Notion-Klon für Mac & iPad

Eine vollständige, native Notion-ähnliche Notiz-App mit:

- **Multiplattform**: macOS, iPadOS, iOS, visionOS (ein Code, ein Target).
- **Verschachtelte Seiten & Ordner** (rekursive Hierarchie).
- **Favoriten & Papierkorb**.
- **Block-Editor** mit allen klassischen Notion-Blöcken:
  - Text, Überschrift (H1/H2/H3), To-do, Aufzählung, nummerierte Liste,
    Umschalter (Toggle), Zitat, Callout (Hinweis), Code-Block mit Sprachwahl,
    Trennlinie, Bild, Lesezeichen, Tabelle.
- **Slash-Menü** (`/`) zum Einfügen + Markdown-Shortcuts (`# `, `- `, `[] `, ``` ``` ```, …).
- **Handschrift mit Apple Pencil** (PencilKit-Canvas) auf iPad – synchronisiert via iCloud zum Mac.
- **Synchronisierung über CloudKit** (automatisch via SwiftData).
- **Globale Schnellsuche** (⇧⌘F).
- **Einstellungen** für Erscheinungsbild & Editorbreite.

## Projektstruktur

```
Text it/
  App/AppState.swift            # globaler UI-Zustand
  Models/Models.swift           # SwiftData: Workspace, Page, Block, BlockType
  Persistence/
    DataController.swift        # ModelContainer + CloudKit + Seed
    PageActions.swift           # CRUD-Mutationen
  Views/
    RootView.swift              # NavigationSplitView
    SidebarView.swift           # Seitenbaum, Favoriten, Papierkorb
    PageEditorView.swift        # Editor + Toolbar + Breadcrumb + Header
    SlashMenuView.swift         # „/“-Menü
    SearchView.swift            # globale Suche
    Settings/SettingsView.swift # Mac-Settings-Szene
    Blocks/
      BlockRowView.swift        # alle Blocktypen
      EditableTextField.swift   # plattformübergreifendes Input-Feld
      ImageBlockView.swift      # Bilder (PhotosPicker / NSOpenPanel)
      HandwritingBlockView.swift# PencilKit (iPad) / Vorschau (Mac)
      TableBlockView.swift      # einfache Tabellen
  Text_it.entitlements          # iCloud + CloudKit + Sandbox
  Text_itApp.swift              # @main, Scenes, Befehle (⌘N, ⇧⌘F)
  ContentView.swift             # Legacy-Wrapper
```

## Einmalige Xcode-Einrichtung (für iCloud-Sync)

1. Projekt in Xcode öffnen → Target **„Text it“** → Reiter **Signing & Capabilities**.
2. **+ Capability** → **iCloud** hinzufügen.
   - Aktivieren: **CloudKit**.
   - Container: `iCloud.de.justinguel.Text-it` (anklicken bzw. neu erstellen).
3. **+ Capability** → **Background Modes** → Häkchen bei **Remote notifications** (für Push-Sync).
4. Stelle sicher, dass das Build-Setting **Code Signing Entitlements** auf
   `Text it/Text_it.entitlements` zeigt (Xcode trägt das beim Hinzufügen der
   Capability automatisch ein).
5. Auf Mac **und** iPad mit derselben Apple-ID anmelden und **iCloud Drive**
   aktivieren.

Ohne iCloud läuft die App weiterhin lokal (Fallback ist im `DataController`
eingebaut).

## Bedienung

- **⌘ N** – neue Seite.
- **⇧ ⌘ F** – globale Suche.
- In einem leeren Textblock `# `, `## `, `### `, `- `, `[] `, `> `, ` ``` `,
  `--- ` tippen → Block wird umgewandelt.
- `/` in einem Block öffnet das Slash-Menü.
- Rechtsklick auf eine Seite (oder „•••“-Menü) für Umbenennen, Unterseite,
  Favorit, Duplizieren, Papierkorb.
- Auf dem iPad einen **Handschrift-Block** einfügen und mit Apple Pencil
  schreiben – die Zeichnung erscheint Sekunden später auf dem Mac.

## Architektur-Hinweise

- **SwiftData + CloudKit**: alle Modelle haben Default-Werte und optionale
  Relationships (CloudKit-Anforderung).
- `Block` ist absichtlich generisch (eine Tabelle für alle Block-Arten),
  Typ-spezifische Felder (`checked`, `level`, `language`, `drawingData`, …)
  sind direkt am Modell – einfach zu syncen, einfach zu erweitern.
- PencilKit-Daten werden als `Data` (PKDrawing) gespeichert → CloudKit-fähig.
- Plattform-Spezifika via `#if os(iOS)` / `#if os(macOS)`.
