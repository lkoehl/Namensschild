#!/bin/bash
# Packt die App in ein einzelnes .dmg zum Weitergeben.
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$PWD"
BUILD="$ROOT/build"
VERSION="1.0"
DMG="$BUILD/Namensschild-$VERSION.dmg"
STAGE="$BUILD/dmg"

./Tools/make-app.sh

echo "› Inhalt vorbereiten"
rm -rf "$STAGE" "$DMG"
mkdir -p "$STAGE"
cp -R "$BUILD/Namensschild.app" "$STAGE/"
ln -s /Applications "$STAGE/Applications"

cat > "$STAGE/Bitte zuerst lesen.txt" <<'TXT'
Namensschild — für das ALLNET LED-Namensschild (Art. 167016–167024)

INSTALLIEREN
1. Namensschild.app nach links auf "Applications" ziehen.
2. Im Programme-Ordner doppelklicken.

BEIM ERSTEN START
macOS meldet: "Namensschild kann nicht geöffnet werden, da Apple es nicht
auf Schadsoftware überprüfen konnte." Das liegt daran, dass das Programm
nicht bei Apple registriert ist (das kostet 99 Euro im Jahr) — nicht daran,
dass etwas damit nicht stimmt.

So geht es trotzdem:
  › Systemeinstellungen öffnen
  › Datenschutz & Sicherheit
  › ganz nach unten scrollen
  › bei "Namensschild wurde blockiert" auf "Trotzdem öffnen" klicken
  › die Meldung noch einmal mit "Trotzdem öffnen" bestätigen

Das ist nur beim allerersten Start nötig.

BENUTZEN
1. Schild per USB anstecken und einschalten (Ein-/Aus-Taste lange drücken).
   Der Punkt links unten in der App wird grün.
2. Text in eine der acht Zeilen tippen und links das Häkchen setzen.
3. Effekt, Tempo, Blinken und Rahmen wählen.
4. Auf "Senden" klicken.

Am Schild schaltet die Nachrichtentaste zwischen den acht Nachrichten um.

WIE VIELE ZEILEN HAT MEIN SCHILD?
Es gibt die Baureihe mit 11 und die mit 12 LED-Zeilen; am USB-Anschluss
lässt sich das nicht erkennen. Steht der Text verschoben oder verzerrt da:
auf "Testmuster" klicken, die leuchtenden Reihen abzählen und rechts unter
"Modell" einstellen.

WENN DAS SCHILD NICHT ERKANNT WIRD
Meistens liegt es am Kabel: viele Billigkabel führen nur Strom und keine
Daten. Ein anderes Kabel probieren.

Voraussetzung: macOS 14 oder neuer, Apple Silicon oder Intel.
TXT

echo "› Abbild schreiben"
hdiutil create -volname "Namensschild" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
rm -rf "$STAGE"

echo
echo "Fertig: $DMG  ($(du -h "$DMG" | cut -f1))"
