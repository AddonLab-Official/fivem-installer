# AddonLab – FiveM Auto Installer

> Richte in wenigen Minuten einen FiveM-Server unter Debian oder Ubuntu ein – Datenbank, Web-Oberfläche und alle Abhängigkeiten inklusive.

🇩🇪 Deutsch | 🇬🇧 [English](README.md)

---

## Funktionen

- **Zweisprachig** – beim Start zwischen Deutsch und Englisch wählen
- **Automatische FiveM-Installation** – lädt die neueste Version (oder eine selbst gewählte Build-Version)
- **MariaDB inklusive** – installiert und konfiguriert die Datenbank automatisch
- **phpMyAdmin inklusive** – webbasierte Datenbankverwaltung von Anfang an
- **Benutzer & Datenbank** – legt einen eigenen FiveM-Datenbankbenutzer an; Passwort generieren lassen oder selbst festlegen
- **Eigener Ordnername** – Installation nach `/home/<name>` deiner Wahl (Standard: `fivem`)
- **Mehrfach ausführbar** – erkennt bestehende Installationen und fragt vor dem Überschreiben nach
- **screen inklusive** – lass deinen Server im Hintergrund laufen, auch nach dem Trennen der Verbindung
- **Sauberes Design** – übersichtliche Schritt-für-Schritt-Oberfläche mit Fehler-Protokoll

---

## Voraussetzungen

- Ein frischer **Debian**- oder **Ubuntu**-Server
- **root**-Zugriff (oder `sudo`)
- Eine Internetverbindung

---

## Installation

Empfohlen wird, das Skript zuerst herunterzuladen und dann auszuführen. So bleibt es voll interaktiv und du kannst die Datei vorher ansehen.

```bash
curl -fsSL https://raw.githubusercontent.com/AddonLab-Official/fivem-installer/main/addonlab-fivem-installer.sh -o addonlab-fivem-installer.sh
sudo bash addonlab-fivem-installer.sh
```

### Lieber erst anschauen?

Sicherheitsbewusst? Herunterladen, durchlesen, dann ausführen:

```bash
curl -fsSL https://raw.githubusercontent.com/AddonLab-Official/fivem-installer/main/addonlab-fivem-installer.sh -o addonlab-fivem-installer.sh
less addonlab-fivem-installer.sh        # Inhalt ansehen
sudo bash addonlab-fivem-installer.sh   # ausführen, wenn alles passt
```

---

## Was das Skript macht

1. Fragt nach der Sprache (Deutsch / Englisch)
2. Bestätigung vor dem Start
3. Aktualisiert das System und installiert Abhängigkeiten
4. Installiert MariaDB (übersprungen, falls vorhanden)
5. Installiert Webserver, PHP und phpMyAdmin (übersprungen, falls vorhanden)
6. Erstellt Datenbank und Benutzer (Passwort generiert oder selbst gewählt)
7. Lädt FiveM herunter und entpackt es in einen Ordner deiner Wahl
8. Speichert alle Zugangsdaten in einer geschützten Datei (`/root/addonlab-credentials.txt`, nur für root lesbar)
9. Zeigt eine Zusammenfassung mit den nächsten Schritten

---

## Nach der Installation

Starte deinen Server in einer `screen`-Sitzung, damit er auch nach dem Abmelden weiterläuft:

```bash
screen -S fivem                 # neue Sitzung starten
cd /home/fivem && ./run.sh      # Server starten
# Strg+A, dann D drücken, um die Sitzung zu verlassen (Server läuft weiter)

screen -r fivem                 # später wieder verbinden
screen -ls                      # Sitzungen anzeigen
```

Öffne dann txAdmin im Browser, um die Einrichtung abzuschließen:

```
http://<DEINE-SERVER-IP>:40120
```

Trage die Datenbank-Zugangsdaten aus `/root/addonlab-credentials.txt` ein, wenn txAdmin danach fragt.

---

## Sicherheitshinweise

- Die **Zugangsdaten-Datei** ist nur für root lesbar (`chmod 600`). Bewahre sie sicher auf.
- **phpMyAdmin** ist ein beliebtes Angriffsziel. Lass es **nicht** ungeschützt offen im Internet – beschränke den Zugriff per IP oder sichere es über einen Reverse-Proxy ab, bevor du den Server öffentlich machst.
- Falls etwas fehlschlägt, werden Details in `/root/addonlab-error.log` gespeichert.

---

## Fehlerbehebung

- **„Ein anderer Installationsprozess läuft"** – ein Hintergrund-Update belegt gerade die Paketverwaltung. Das Skript wartet und macht automatisch weiter.
- **FiveM-Version nicht erkannt** – schlägt die automatische Erkennung fehl, kannst du eine Build-URL manuell eintragen. Die Builds findest du auf der offiziellen FiveM-Artifacts-Seite.
- **Hilfe nötig?** Erstelle ein Issue oder tritt unserer Community bei.

---

## Lizenz

Veröffentlicht unter der MIT-Lizenz. Details findest du in der Datei [LICENSE](LICENSE).

---

Discord: https://discord.com/invite/RJC6zSmru3
