# Namensschild

Native macOS-App für das **ALLNET LED-Namensschild** (Art. 167017 / 167016 / 167018 / 167020 / 167024,
SKU `ALL_NTAG_*v2`) — und für alle baugleichen Schilder der Lesun-Familie
(S1144, B1144, GD1144, LG1144, S1155, S1248, B1248, GD1248).

Die mitgelieferte Software von ALLNET gibt es nur für Windows. Diese App ersetzt sie.

## Es wird kein Treiber gebraucht

Trotz „Seriell" im Produktnamen ist das Schild **kein** serielles Gerät, sondern ein
USB-HID-Gerät (`VID 0x0416`, `PID 0x5020`). macOS spricht USB-HID von Haus aus über
IOKit — ohne Kernel-Erweiterung, ohne Systemerweiterung, ohne Sonderrechte.
Was gefehlt hat, war nicht ein Treiber, sondern das Programm, das die richtigen Bytes schickt.

## Bauen und installieren

```bash
./Tools/make-app.sh
cp -R build/Namensschild.app /Applications/
```

Gebraucht wird nur Xcode (oder die Command Line Tools). Keine externen Bibliotheken,
kein Homebrew, kein Python. Die App wird als Universal-Binary gebaut und läuft auf
Apple Silicon wie auf Intel, ab macOS 14.

## Weitergeben

```bash
./Tools/make-dmg.sh
```

Ergebnis: `build/Namensschild-1.0.dmg` — eine einzelne Datei (rund 1,3 MB) mit der App,
einer Verknüpfung zum Programme-Ordner und einer Kurzanleitung.

Beim ersten Start auf einem fremden Mac meldet macOS, es könne die App nicht auf
Schadsoftware prüfen. Grund ist die fehlende Notarisierung durch Apple, die ein
Entwicklerkonto für 99 Euro im Jahr voraussetzt — nicht ein Problem mit der App.
Der Weg drumherum steht in der Kurzanleitung im Abbild: *Systemeinstellungen →
Datenschutz & Sicherheit → ganz nach unten → „Trotzdem öffnen"*. Nur einmal nötig.

Mit einem Entwicklerkonto entfiele das:

```bash
codesign --force --deep --options runtime --sign "Developer ID Application: …" build/Namensschild.app
xcrun notarytool submit build/Namensschild-1.0.dmg --apple-id … --team-id … --wait
xcrun stapler staple build/Namensschild-1.0.dmg
```

## Bedienung

1. Schild per USB anstecken. Der Punkt links unten wird grün.
2. Nachricht in eine der acht Zeilen tippen und das Häkchen links setzen.
3. Effekt, Tempo, Blinken und Rahmen je Nachricht wählen.
4. **Senden** (⌘↩).

Am Schild schaltet die Nachrichtentaste zwischen M1 … M8 um.

Jede Zeile zeigt eine Mini-Vorschau ihres Inhalts. Nachrichten lassen sich an der
Nummer auf einen anderen Platz ziehen, ⌘Z widerruft. Der Schriftwähler listet alle
installierten Schriften und zeigt jede auf dem echten Punktraster — bei elf Zeilen
sagt der Name einer Schrift nichts darüber, ob sie taugt.

### Wie viele Zeilen hat mein Schild?

Die 1144er-Baureihe hat 11 LED-Zeilen, die 1248er hat 12. Der USB-Deskriptor verrät das
nicht. Bei falscher Einstellung erscheint der Text verschoben oder verzerrt.

Im Zweifel: **Testmuster** senden — das schaltet alle LEDs ein, dann die leuchtenden
Reihen abzählen und unter *Modell* einstellen.

### Effekte

| Effekt | Beschreibung |
|---|---|
| Nach links / rechts / oben / unten | Lauftext in die jeweilige Richtung |
| Stehend | Text steht fest |
| Animation, Herabfallen, Vorhang, Laser | Einblend-Effekte der Firmware |

Die Vorschau animiert die vier Laufrichtungen und den stehenden Text originalgetreu.
Die vier Firmware-Effekte erzeugt das Schild selbst — die Vorschau zeigt dort nur den Inhalt.

### Symbole im Text

Zwölf Pixelsymbole lassen sich mitten in den Text setzen — als Kürzel geschrieben,
auf dem Schild als Grafik:

```
Lukas :herz: Kaffee
:achtung: Raum 12 gesperrt
```

`:herz:` · `:stern:` · `:haken:` · `:kreuz:` · `:rechts:` · `:links:` · `:wlan:` ·
`:kaffee:` · `:achtung:` · `:smiley:` · `:note:` · `:blitz:`

Der Knopf **Symbol** zeigt sie alle mit Vorschau. Für einen echten Doppelpunkt
`::` schreiben (`12::30` wird zu `12:30`). Ein unbekanntes Kürzel bleibt sichtbar
stehen — so sieht man den Tippfehler auf dem Schild, statt dass Text verschwindet.

Die Symbole sind Punkt für Punkt von Hand gezeichnet. Auf neun Zeilen entscheidet
jedes einzelne Pixel über die Erkennbarkeit; eine skalierte Vektorgrafik oder ein
Emoji aus einer Systemschrift wird dort unweigerlich zu Matsch.

### Schriftgröße und Umlaute

Text wird über CoreText gerastert, Antialiasing aus. Die Grundlinie ergibt sich aus den
tatsächlich leuchtenden Pixeln von `ÄÖÜQÅgjpqy` — den Zeichen, die am weitesten nach oben
und unten reichen. Dadurch sitzt jede Nachricht gleich hoch, und die Punkte auf großen
Umlauten fallen nicht weg.

Passt die gewählte Größe nicht vollständig auf die Matrix, warnt die App und bietet die
größte passende Größe an. Wird trotzdem zu groß gewählt, verliert das Schild die
Unterlängen von g/j/p/q — die Umlautpunkte bleiben.

### Speicherbedarf

Alle acht Nachrichten zusammen passen in 8 KB. Der Balken unten links zeigt den
Füllstand in Byte-Spalten (eine Byte-Spalte = 8 Pixel breit); bei Überlauf wird
**Senden** gesperrt.

## Kommandozeile

Das gleiche Innenleben gibt es als CLI unter `.build/release/badgectl`:

```bash
badgectl devices                                  # angeschlossene Schilder auflisten
badgectl send "Lukas Köhl" --effect left --speed 4
badgectl preview "Lukas Köhl" --font Menlo-Bold   # ASCII-Vorschau, ohne Gerät
badgectl fonts                                    # Schriften im Vergleich
badgectl hexdump "Test"                           # den Bytestrom ansehen
badgectl test                                     # Testmuster
```

## Wenn das Schild nicht erkannt wird

```bash
system_profiler SPUSBDataType | grep -B 2 -A 8 "0x5020"
```

* **Nichts zu sehen:** anderes Kabel probieren — viele Billigkabel führen nur Strom,
  keine Daten. Das Schild muss außerdem eingeschaltet sein (Ein-/Aus-Taste lange drücken).
* **Ein `/dev/cu.usbserial-*` oder `/dev/cu.wchusbserial-*` taucht auf:** dann ist es
  doch eine Seriell-Variante mit CH340/CH9102-Chip. Diese App spricht sie nicht an.
* **„Gerät ist belegt":** ein anderes Programm hält das Schild offen — z. B. eine noch
  laufende zweite Instanz oder eine Windows-VM mit USB-Durchreichung.

Beim ersten Start meldet Gatekeeper eventuell, dass die App aus einer nicht
verifizierten Quelle stammt (sie ist nur ad-hoc signiert). Rechtsklick → *Öffnen*.

## Aufbau des Projekts

```
Sources/BadgeKit/          Die Bibliothek — ohne AppKit, voll testbar
  BadgeMessage.swift       Datenmodell: Nachrichten, Effekte, Helligkeit, Zeilenzahl
  ColumnBitmap.swift       Monochrome Bitmap in Geräteanordnung
  TextRasterizer.swift     Text → Bitmap über CoreText, ohne Antialiasing
  BadgeProtocol.swift      Header und Nutzdaten
  BadgeDevice.swift        IOKit-HID: Suchen, Senden, An-/Abstecken melden
  BadgeJob.swift           Dokument → fertiger Puffer
Sources/NamensschildApp/   Die SwiftUI-Oberfläche
Sources/badgectl/          Kommandozeilenwerkzeug
Tests/BadgeKitTests/       30 Tests, laufen ohne Gerät
Tools/make-app.sh          Baut Namensschild.app
Tools/make-icon.swift      Erzeugt das App-Symbol
```

```bash
swift test    # alles ohne angeschlossenes Schild prüfbar
```

## Das Protokoll

Gesendet werden 64-Byte-HID-Output-Reports mit Report-ID 0, insgesamt höchstens 8192 Bytes.

**Header (64 Bytes):**

| Offset | Inhalt |
|---|---|
| 0–4 | `77 61 6E 67 00` — „wang\0" |
| 5 | Helligkeit: `00` = 100 %, `10` = 75 %, `20` = 50 %, `40` = 25 % |
| 6 | Blinken, ein Bit je Nachricht |
| 7 | Rahmen, ein Bit je Nachricht |
| 8–15 | je Nachricht: `(Tempo − 1) << 4 \| Effekt` |
| 16–31 | acht Längen als `uint16` big-endian, in Byte-Spalten |
| 38–43 | Zeitstempel `JJ MM TT hh mm ss` |

Danach folgen die Bitmaps in Slot-Reihenfolge: je Byte-Spalte 11 Bytes (bzw. 12),
ein Byte pro LED-Zeile, MSB links. Zum Schluss auf ein Vielfaches von 64 auffüllen.

Das Protokoll wurde gegen [fossasia/led-name-badge-ls32](https://github.com/fossasia/led-name-badge-ls32)
verifiziert. Dieses Projekt enthält keinen Code daraus.
