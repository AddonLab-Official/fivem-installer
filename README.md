# AddonLab – FiveM Auto Installer

> Set up a FiveM server on Debian or Ubuntu in minutes – database, web panel and all dependencies included.

`~/gaming/services$` **AddonLab** – Gaming Service

---

## Features

- **Bilingual** – choose English or German at startup
- **Automatic FiveM install** – downloads the latest artifacts (with the option to pick your own build)
- **MariaDB included** – installs and configures the database automatically
- **phpMyAdmin included** – web-based database management out of the box
- **User & database setup** – creates a dedicated FiveM database user; generate a secure password or set your own
- **Custom folder name** – install to `/home/<name>` of your choice (default: `fivem`)
- **Safe to re-run** – detects existing installations and asks before overwriting
- **screen included** – run your server in the background, even after you disconnect
- **Clean design** – clear step-by-step interface with error logging

---

## Requirements

- A fresh **Debian** or **Ubuntu** server
- **root** access (or `sudo`)
- An internet connection

---

## Installation

The recommended way is to download the script first, then run it. This keeps it fully interactive and lets you review the file before running.

```bash
curl -fsSL https://YOUR-URL/addonlab-fivem-installer.sh -o addonlab.sh
sudo bash addonlab.sh
```

> Replace `https://YOUR-URL/...` with the real link to your script.

### Prefer to review it first?

Security-conscious? Download it, read it, then run it:

```bash
curl -fsSL https://YOUR-URL/addonlab-fivem-installer.sh -o addonlab.sh
less addonlab.sh        # review the contents
sudo bash addonlab.sh   # run when you are happy
```

---

## What the script does

1. Asks for your language (English / German)
2. Confirms before starting
3. Updates the system and installs dependencies
4. Installs MariaDB (skipped if already present)
5. Installs the webserver, PHP and phpMyAdmin (skipped if already present)
6. Creates the database and users (generated or custom password)
7. Downloads and extracts FiveM into a folder you choose
8. Saves all credentials to a protected file (`/root/addonlab-credentials.txt`, readable by root only)
9. Shows a summary with next steps

---

## After installation

Start your server inside a `screen` session so it keeps running after you log out:

```bash
screen -S fivem                 # start a new session
cd /home/fivem && ./run.sh      # start the server
# Press Ctrl+A, then D to detach (the server keeps running)

screen -r fivem                 # re-attach later
screen -ls                      # list your sessions
```

Then open txAdmin in your browser to finish the setup:

```
http://<YOUR-SERVER-IP>:40120
```

Enter the database credentials from `/root/addonlab-credentials.txt` when txAdmin asks for them.

---

## Security notes

- **Credentials file** is readable by root only (`chmod 600`). Keep it safe.
- **phpMyAdmin** is a common attack target. Do **not** leave it openly exposed to the internet – restrict access by IP or place it behind a reverse proxy before going public.
- If anything fails, details are written to `/root/addonlab-error.log`.

---

## Troubleshooting

- **"Another install process is running"** – a background system update is holding the package manager. The script waits and continues automatically.
- **FiveM version not detected** – if automatic detection fails, the script lets you paste a build URL manually. Find builds at the official FiveM artifacts page.
- **Need help?** Open an issue or join our community.

---


