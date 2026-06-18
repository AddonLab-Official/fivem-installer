#!/usr/bin/env bash
#
# ============================================================
#  AddonLab - FiveM Auto Installer
#  Für Debian & Ubuntu
#  Version: 1.2
# ============================================================

set -euo pipefail

# ------------------------------------------------------------
# Globale Variablen
# ------------------------------------------------------------
LANG_CHOICE=""
DISTRO_ID=""
DISTRO_CODENAME=""
FIVEM_DIR="/home/fivem"
CREDENTIALS_FILE="/root/addonlab-credentials.txt"
ERROR_LOG="/root/addonlab-error.log"
DB_ROOT_PASS=""
DB_FIVEM_USER="fivem"
DB_FIVEM_PASS=""
DB_FIVEM_NAME="fivem"
DB_SETUP_DONE="no"
MARIADB_PREEXISTING="no"
ARTIFACT_LIST_URL="https://runtime.fivem.net/artifacts/fivem/build_proot_linux/master/"
TOTAL_STEPS=7
CURRENT_STEP=0

# ------------------------------------------------------------
# Farbpalette (AddonLab-Design)
# ------------------------------------------------------------
C_RESET="\033[0m"
C_BOLD="\033[1m"
C_DIM="\033[2m"
C_BRAND="\033[1;36m"     # Cyan
C_LOGO="\033[38;5;48m"   # Türkis/Spring-Green
C_ACCENT="\033[1;35m"    # Magenta
C_OK="\033[1;32m"        # Grün
C_WARN="\033[1;33m"      # Gelb
C_ERR="\033[1;31m"       # Rot
C_INFO="\033[1;34m"      # Blau
C_GREY="\033[0;90m"      # Grau

BOX_W=60

# ------------------------------------------------------------
# Sprach-Helfer:  t "deutsch" "english"
# ------------------------------------------------------------
t() {
    if [ "$LANG_CHOICE" = "de" ]; then echo -e "$1"; else echo -e "$2"; fi
}

# ------------------------------------------------------------
# Design-Bausteine
# ------------------------------------------------------------
hr() {
    printf "${C_BRAND}"
    printf '═%.0s' $(seq 1 "$BOX_W")
    printf "${C_RESET}\n"
}

box_line_center() {
    local text="$1"
    local plain
    plain=$(echo -e "$text" | sed 's/\x1b\[[0-9;]*m//g')
    local len=${#plain}
    local pad=$(( (BOX_W - len) / 2 ))
    [ "$pad" -lt 0 ] && pad=0
    local rpad=$(( BOX_W - len - pad ))
    [ "$rpad" -lt 0 ] && rpad=0
    printf "${C_BRAND}║${C_RESET}%*s%b%*s${C_BRAND}║${C_RESET}\n" "$pad" "" "$text" "$rpad" ""
}

banner() {
    echo ""
    printf "${C_BRAND}╔"; printf '═%.0s' $(seq 1 "$BOX_W"); printf "╗${C_RESET}\n"
    box_line_center "${C_BOLD}${C_LOGO}A D D O N L A B${C_RESET}"
    box_line_center "${C_DIM}FiveM Auto Installer${C_RESET}"
    printf "${C_BRAND}╚"; printf '═%.0s' $(seq 1 "$BOX_W"); printf "╝${C_RESET}\n"
    echo ""
}

screen() {
    clear
    banner
    if [ -n "${1:-}" ]; then
        printf "${C_ACCENT}${C_BOLD}»${C_RESET} ${C_BOLD}%b${C_RESET}" "$1"
        if [ "$CURRENT_STEP" -gt 0 ]; then
            printf "  ${C_GREY}[%d/%d]${C_RESET}" "$CURRENT_STEP" "$TOTAL_STEPS"
        fi
        echo ""
        hr
        echo ""
    fi
}

step() {
    CURRENT_STEP=$((CURRENT_STEP + 1))
    screen "$1"
}

msg()  { echo -e "${C_INFO}[*]${C_RESET} $1"; }
ok()   { echo -e "${C_OK}[OK]${C_RESET} $1"; }
warn() { echo -e "${C_WARN}[!]${C_RESET} $1"; }
err()  { echo -e "${C_ERR}[X]${C_RESET} $1"; }

# ------------------------------------------------------------
# Fehler-Behandlung: bei jedem Abbruch automatisch loggen
# ------------------------------------------------------------
on_error() {
    local exit_code=$?
    local line_no=$1
    {
        echo "============================================================"
        echo " AddonLab Fehler / Error  -  $(date)"
        echo "============================================================"
        echo " Exit-Code:  $exit_code"
        echo " Zeile/Line: $line_no"
        echo " Schritt/Step: ${CURRENT_STEP}/${TOTAL_STEPS}"
        echo " Distro: ${DISTRO_ID} ${DISTRO_CODENAME}"
        echo "------------------------------------------------------------"
    } >> "$ERROR_LOG" 2>/dev/null || true

    echo ""
    err "$(t 'Es ist ein Fehler aufgetreten.' 'An error occurred.')"
    t "  Details wurden gespeichert in: $ERROR_LOG" \
      "  Details have been saved to: $ERROR_LOG"
    t "  (Zeile $line_no, Exit-Code $exit_code)" \
      "  (line $line_no, exit code $exit_code)"
    exit "$exit_code"
}
trap 'on_error $LINENO' ERR

# ------------------------------------------------------------
# Abbruch durch Strg+C (SIGINT) sauber abfangen
# ------------------------------------------------------------
on_interrupt() {
    trap - ERR
    echo ""
    echo ""
    warn "$(t 'Installation abgebrochen (Strg+C).' 'Installation cancelled (Ctrl+C).')"
    t "  Es wurden ggf. nicht alle Schritte abgeschlossen." \
      "  Some steps may not have completed."
    echo ""
    exit 130
}
trap 'on_interrupt' INT

# ------------------------------------------------------------
# Auf freie dpkg/apt-Sperre warten (häufig auf frischen Servern)
# ------------------------------------------------------------
wait_for_apt() {
    local lock="/var/lib/dpkg/lock-frontend"
    # Wenn die Sperrdatei nicht existiert, gibt es nichts zu warten.
    [ -e "$lock" ] || return 0
    # flock vorhanden? Wenn nicht, lieber nicht warten als endlos hängen.
    command -v flock >/dev/null 2>&1 || return 0

    local waited=0
    local timeout=120   # max. 2 Minuten warten, dann trotzdem weiter

    while ! flock -n "$lock" true 2>/dev/null; do
        if [ "$waited" -ge "$timeout" ]; then
            warn "$(t 'Zeitüberschreitung - fahre trotzdem fort.' 'Timed out - continuing anyway.')"
            break
        fi
        warn "$(t 'Ein anderer Installationsprozess läuft - warte...' 'Another install process is running - waiting...')"
        sleep 5
        waited=$((waited + 5))
    done
}

# ------------------------------------------------------------
# 1. Root-Check
# ------------------------------------------------------------
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        err "Bitte als root ausführen (sudo). / Please run as root (sudo)."
        exit 1
    fi
}

# ------------------------------------------------------------
# 2. Sprachauswahl + Startbestätigung
# ------------------------------------------------------------
choose_language() {
    clear
    banner
    echo -e "  ${C_BOLD}Sprache wählen / Choose language${C_RESET}"
    echo ""
    echo -e "   ${C_ACCENT}1)${C_RESET} Deutsch"
    echo -e "   ${C_ACCENT}2)${C_RESET} English"
    echo ""
    read -rp "  > " lang_input
    case "$lang_input" in
        1) LANG_CHOICE="de" ;;
        2) LANG_CHOICE="en" ;;
        *) LANG_CHOICE="en" ;;
    esac
}

confirm_start() {
    screen "$(t 'Installation starten' 'Start installation')"
    t "  Es werden FiveM, MariaDB, Webserver und phpMyAdmin installiert." \
      "  This will install FiveM, MariaDB, webserver and phpMyAdmin."
    echo ""
    echo -e "   ${C_OK}1)${C_RESET} $(t 'FiveM-Installation beginnen' 'Begin FiveM installation')"
    echo -e "   ${C_ERR}2)${C_RESET} $(t 'Abbrechen' 'Cancel')"
    echo ""
    read -rp "  > " start_choice
    if [ "$start_choice" != "1" ]; then
        echo ""
        warn "$(t 'Abgebrochen.' 'Cancelled.')"
        exit 0
    fi
}

# ------------------------------------------------------------
# 3. Distribution erkennen
# ------------------------------------------------------------
detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO_ID="$ID"
        DISTRO_CODENAME="${VERSION_CODENAME:-}"
    else
        err "$(t 'Distribution nicht erkennbar.' 'Cannot detect distribution.')"
        exit 1
    fi
    if [ "$DISTRO_ID" != "debian" ] && [ "$DISTRO_ID" != "ubuntu" ]; then
        err "$(t "Nicht unterstützt: $DISTRO_ID" "Unsupported: $DISTRO_ID")"
        exit 1
    fi
}

# ------------------------------------------------------------
# Passwort sicher erfragen (manuell: 2x, min 8 Zeichen)
# ------------------------------------------------------------
RESULT_PASS=""
get_password() {
    local label="$1"
    echo ""
    echo -e "  ${C_BOLD}$(t "Passwort für" "Password for") ${C_ACCENT}${label}${C_RESET}"
    echo -e "   ${C_ACCENT}1)${C_RESET} $(t 'Automatisch generieren (empfohlen)' 'Generate automatically (recommended)')"
    echo -e "   ${C_ACCENT}2)${C_RESET} $(t 'Selbst eingeben' 'Enter manually')"
    read -rp "  > " pw_choice

    if [ "$pw_choice" = "2" ]; then
        while true; do
            read -rsp "$(t '  Passwort (min. 8 Zeichen): ' '  Password (min. 8 chars): ')" p1; echo ""
            if [ "${#p1}" -lt 8 ]; then
                warn "$(t 'Zu kurz - mindestens 8 Zeichen.' 'Too short - at least 8 characters.')"
                continue
            fi
            read -rsp "$(t '  Passwort bestätigen: ' '  Confirm password: ')" p2; echo ""
            if [ "$p1" != "$p2" ]; then
                warn "$(t 'Passwörter stimmen nicht überein.' 'Passwords do not match.')"
                continue
            fi
            RESULT_PASS="$p1"
            break
        done
    else
        RESULT_PASS="$(set +o pipefail; tr -dc 'A-Za-z0-9' < /dev/urandom 2>/dev/null | head -c 20 || true)"
        ok "$(t 'Passwort generiert.' 'Password generated.')"
    fi
}

# ------------------------------------------------------------
# 4. System aktualisieren
# ------------------------------------------------------------
update_system() {
    step "$(t 'System aktualisieren' 'Update system')"
    export DEBIAN_FRONTEND=noninteractive
    msg "$(t 'Paketquellen werden aktualisiert...' 'Updating package sources...')"
    wait_for_apt
    apt-get update -y
    apt-get upgrade -y
    apt-get install -y curl wget xz-utils ca-certificates gnupg lsb-release sudo screen psmisc
    ok "$(t 'System bereit.' 'System ready.')"
}

# ------------------------------------------------------------
# 5. MariaDB
# ------------------------------------------------------------
install_mariadb() {
    step "$(t 'MariaDB installieren' 'Install MariaDB')"
    if command -v mariadb >/dev/null 2>&1 || command -v mysql >/dev/null 2>&1; then
        MARIADB_PREEXISTING="yes"
        warn "$(t 'MariaDB/MySQL bereits installiert.' 'MariaDB/MySQL already installed.')"
        warn "$(t 'Datenbank-Einrichtung wird übersprungen - bitte DB und User selbst anlegen.' 'Database setup will be skipped - please create DB and user yourself.')"
    else
        msg "$(t 'MariaDB wird installiert...' 'Installing MariaDB...')"
        wait_for_apt
        apt-get install -y mariadb-server mariadb-client
        systemctl enable --now mariadb
        ok "$(t 'MariaDB installiert.' 'MariaDB installed.')"
    fi
}

# ------------------------------------------------------------
# 6. Webserver + PHP + phpMyAdmin
# ------------------------------------------------------------
install_phpmyadmin() {
    step "$(t 'Webserver & phpMyAdmin' 'Webserver & phpMyAdmin')"
    if [ -d /usr/share/phpmyadmin ] || dpkg -l 2>/dev/null | grep -q phpmyadmin; then
        warn "$(t 'phpMyAdmin bereits vorhanden - übersprungen.' 'phpMyAdmin already present - skipped.')"
        return
    fi
    msg "$(t 'Apache, PHP und phpMyAdmin werden installiert...' 'Installing Apache, PHP and phpMyAdmin...')"
    wait_for_apt
    apt-get install -y apache2 php php-mysqli php-mbstring php-zip php-gd php-json php-curl libapache2-mod-php
    echo "phpmyadmin phpmyadmin/dbconfig-install boolean false" | debconf-set-selections
    echo "phpmyadmin phpmyadmin/reconfigure-webserver multiselect apache2" | debconf-set-selections
    wait_for_apt
    apt-get install -y phpmyadmin || warn "$(t 'phpMyAdmin meldete Warnungen.' 'phpMyAdmin reported warnings.')"
    systemctl enable --now apache2
    ok "$(t 'Webserver + phpMyAdmin installiert.' 'Webserver + phpMyAdmin installed.')"
    warn "$(t 'SICHERHEIT: phpMyAdmin absichern (IP-Filter/Reverse-Proxy)!' 'SECURITY: secure phpMyAdmin (IP filter / reverse proxy)!')"
}

# ------------------------------------------------------------
# 7. Datenbank einrichten (nur wenn MariaDB frisch installiert)
# ------------------------------------------------------------
setup_database() {
    step "$(t 'Datenbank einrichten' 'Set up database')"
    if [ "$MARIADB_PREEXISTING" = "yes" ]; then
        warn "$(t 'Bestehende MariaDB erkannt - DB-Einrichtung übersprungen.' 'Existing MariaDB detected - DB setup skipped.')"
        t "  Lege Datenbank und Benutzer bitte manuell an." \
          "  Please create the database and user manually."
        return
    fi

    get_password "MariaDB root";              DB_ROOT_PASS="$RESULT_PASS"
    get_password "FiveM DB ($DB_FIVEM_USER)"; DB_FIVEM_PASS="$RESULT_PASS"

    msg "$(t 'Erstelle Datenbank und Benutzer...' 'Creating database and users...')"
    mariadb <<SQL
ALTER USER 'root'@'localhost' IDENTIFIED BY '${DB_ROOT_PASS}';
CREATE DATABASE IF NOT EXISTS \`${DB_FIVEM_NAME}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
CREATE USER IF NOT EXISTS '${DB_FIVEM_USER}'@'localhost' IDENTIFIED BY '${DB_FIVEM_PASS}';
GRANT ALL PRIVILEGES ON \`${DB_FIVEM_NAME}\`.* TO '${DB_FIVEM_USER}'@'localhost';
FLUSH PRIVILEGES;
SQL
    DB_SETUP_DONE="yes"
    ok "$(t 'Datenbank und Benutzer erstellt.' 'Database and users created.')"
}

# ------------------------------------------------------------
# 8. FiveM-Artifacts  (Auto-Erkennung + Custom-Fallback)
# ------------------------------------------------------------
detect_latest_artifact() {
    # Versucht, die neueste Build-URL von der CFX-Seite zu lesen.
    # Gibt bei Erfolg die volle .tar.xz-URL aus, sonst nichts (Rückgabe != 0).
    local html latest
    html="$(curl -fsSL "$ARTIFACT_LIST_URL" 2>/dev/null || true)"
    [ -z "$html" ] && return 1
    latest="$(echo "$html" \
        | grep -oE '[0-9]+-[a-f0-9]+/fx\.tar\.xz' \
        | sort -t'-' -k1 -n \
        | tail -n1 || true)"
    [ -z "$latest" ] && return 1
    echo "${ARTIFACT_LIST_URL}${latest}"
}

install_fivem() {
    step "$(t 'FiveM-Server installieren' 'Install FiveM server')"

    # --- Ordnername abfragen (Standard: fivem) + Existenz-Prüfung ---
    while true; do
        echo -e "  ${C_BOLD}$(t 'Name des FiveM-Ordners' 'Name of the FiveM folder')${C_RESET}"
        echo -e "  ${C_GREY}$(t 'Wird angelegt unter /home/<name>. Enter = Standard "fivem".' 'Created at /home/<name>. Enter = default "fivem".')${C_RESET}"
        read -rp "  > " folder_name
        # Leere Eingabe -> Standard
        folder_name="${folder_name:-fivem}"
        # Nur erlaubte Zeichen (Buchstaben, Zahlen, - und _)
        if ! echo "$folder_name" | grep -qE '^[A-Za-z0-9_-]+$'; then
            warn "$(t 'Nur Buchstaben, Zahlen, - und _ erlaubt.' 'Only letters, numbers, - and _ allowed.')"
            echo ""
            continue
        fi
        FIVEM_DIR="/home/${folder_name}"

        # Existiert der Ordner schon und ist nicht leer?
        if [ -d "$FIVEM_DIR" ] && [ -n "$(ls -A "$FIVEM_DIR" 2>/dev/null)" ]; then
            echo ""
            warn "$(t "Der Ordner $FIVEM_DIR existiert bereits und ist nicht leer." "The folder $FIVEM_DIR already exists and is not empty.")"
            echo -e "   ${C_ACCENT}1)${C_RESET} $(t 'Anderen Namen wählen' 'Choose another name')"
            echo -e "   ${C_ACCENT}2)${C_RESET} $(t 'Trotzdem hineininstallieren (Dateien können überschrieben werden)' 'Install anyway (files may be overwritten)')"
            echo -e "   ${C_ERR}3)${C_RESET} $(t 'Abbrechen' 'Cancel')"
            read -rp "  > " exist_choice
            case "$exist_choice" in
                1) echo ""; continue ;;
                2) ok "$(t 'Verwende vorhandenen Ordner.' 'Using existing folder.')"; break ;;
                *) warn "$(t 'Abgebrochen.' 'Cancelled.')"; exit 0 ;;
            esac
        else
            break
        fi
    done
    echo ""

    local artifact_url=""
    msg "$(t 'Suche neueste Version...' 'Looking for latest version...')"
    local detected
    detected="$(detect_latest_artifact || true)"

    echo ""
    if [ -n "$detected" ]; then
        echo -e "  ${C_OK}$(t 'Neueste erkannte Version:' 'Latest detected version:')${C_RESET}"
        echo -e "    ${C_GREY}${detected}${C_RESET}"
        echo ""
        echo -e "   ${C_ACCENT}1)${C_RESET} $(t 'Neueste Version verwenden (empfohlen)' 'Use latest version (recommended)')"
        echo -e "   ${C_ACCENT}2)${C_RESET} $(t 'Eigene Version eintragen' 'Enter custom version')"
        read -rp "  > " ver_choice
        if [ "$ver_choice" = "2" ]; then
            read -rp "$(t '  Build-URL (.tar.xz): ' '  Build URL (.tar.xz): ')" artifact_url
        else
            artifact_url="$detected"
        fi
    else
        warn "$(t 'Automatische Erkennung fehlgeschlagen.' 'Automatic detection failed.')"
        t "  Builds findest du hier:" "  Find builds here:"
        echo -e "    ${C_GREY}${ARTIFACT_LIST_URL}${C_RESET}"
        read -rp "$(t '  Build-URL (.tar.xz) eintragen: ' '  Enter build URL (.tar.xz): ')" artifact_url
    fi

    mkdir -p "$FIVEM_DIR"
    cd "$FIVEM_DIR"

    if [ -n "$artifact_url" ]; then
        msg "$(t 'Lade Artifacts herunter...' 'Downloading artifacts...')"
        wget -O fx.tar.xz "$artifact_url"
        tar xf fx.tar.xz
        rm -f fx.tar.xz
        ok "$(t 'FiveM installiert nach' 'FiveM installed to') $FIVEM_DIR"
    else
        warn "$(t 'Keine URL - bitte Artifacts manuell installieren.' 'No URL - please install artifacts manually.')"
    fi
}

# ------------------------------------------------------------
# 9. Zugangsdaten speichern (nur wenn DB-Setup lief)
# ------------------------------------------------------------
save_credentials() {
    [ "$DB_SETUP_DONE" != "yes" ] && return
    cat > "$CREDENTIALS_FILE" <<EOF
============================================================
 AddonLab - FiveM Installer - Zugangsdaten / Credentials
 $(date)
============================================================

MariaDB root:
  User:     root
  Passwort: ${DB_ROOT_PASS}

FiveM Datenbank / Database:
  DB-Name:  ${DB_FIVEM_NAME}
  User:     ${DB_FIVEM_USER}
  Passwort: ${DB_FIVEM_PASS}
  Host:     localhost

Connection-String (server.cfg / txAdmin):
  mysql://${DB_FIVEM_USER}:${DB_FIVEM_PASS}@localhost/${DB_FIVEM_NAME}?charset=utf8mb4

FiveM-Verzeichnis: ${FIVEM_DIR}
============================================================
EOF
    chmod 600 "$CREDENTIALS_FILE"
}

# ------------------------------------------------------------
# 10. Abschluss
# ------------------------------------------------------------
summary() {
    screen "$(t 'Fertig' 'Done')"
    ok "$(t 'Installation abgeschlossen!' 'Installation complete!')"
    echo ""
    if [ "$DB_SETUP_DONE" = "yes" ]; then
        t "  Zugangsdaten: $CREDENTIALS_FILE" "  Credentials: $CREDENTIALS_FILE"
    else
        warn "$(t 'DB-Setup übersprungen - keine Zugangsdaten-Datei erstellt.' 'DB setup skipped - no credentials file created.')"
    fi
    echo ""
    echo -e "  ${C_BOLD}$(t 'Nächste Schritte:' 'Next steps:')${C_RESET}"
    echo -e "   ${C_ACCENT}1)${C_RESET} cd $FIVEM_DIR"
    echo -e "   ${C_ACCENT}2)${C_RESET} ./run.sh"
    echo -e "   ${C_ACCENT}3)${C_RESET} $(t 'txAdmin öffnen:' 'Open txAdmin:') http://<IP>:40120"
    echo -e "   ${C_ACCENT}4)${C_RESET} $(t 'DB-Daten in txAdmin eintragen.' 'Enter DB credentials in txAdmin.')"
    echo ""
    echo -e "  ${C_BOLD}$(t 'Server dauerhaft laufen lassen (screen):' 'Keep the server running (screen):')${C_RESET}"
    echo -e "   ${C_GREY}$(t 'Neue Session starten:' 'Start a new session:')${C_RESET} screen -S fivem"
    echo -e "   ${C_GREY}$(t 'Darin den Server starten:' 'Start the server inside:')${C_RESET} cd $FIVEM_DIR && ./run.sh"
    echo -e "   ${C_GREY}$(t 'Session verlassen (Server läuft weiter):' 'Detach (server keeps running):')${C_RESET} Strg+A, dann D"
    echo -e "   ${C_GREY}$(t 'Zurück zur Session:' 'Re-attach:')${C_RESET} screen -r fivem"
    echo -e "   ${C_GREY}$(t 'Sessions anzeigen:' 'List sessions:')${C_RESET} screen -ls"
    echo ""
    hr
    echo -e "  ${C_BRAND}AddonLab${C_RESET} ${C_DIM}- $(t 'Discord: https://discord.com/invite/RJC6zSmru3' 'Discord: https://discord.com/invite/RJC6zSmru3')${C_RESET}"
    echo ""
}

# ------------------------------------------------------------
# Hauptablauf
# ------------------------------------------------------------
main() {
    check_root
    choose_language
    confirm_start
    detect_distro
    update_system
    install_mariadb
    install_phpmyadmin
    setup_database
    install_fivem
    save_credentials
    summary
}

main "$@"
