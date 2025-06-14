PortableBackupKit
=================

What it is
----------
A self-contained Windows toolkit that makes automatic, incremental SFTP
backups with rclone.  No installation is required; everything runs from the
folder you unzip.

Main points
-----------
* Mirrors the remote server into current\
* Creates dated snapshots in archive\YYYY-MM-DD_HHMMSS\
* Keeps snapshots for 3 days by default (configurable up to 30)
* Runs on a schedule you choose (daily, every N hours, or weekly)
* Shows live progress in the console and in backup.log
* Optional Brevo e-mail when a run finishes, summarizing remote info, files transferred and data volume

* `update.ps1` pulls new versions using Git in PATH or `git.exe` in this folder
* `menu.bat` provides a simple menu for setup, restore, uninstall, update and manual backup


* Uses `--stats-log-level NOTICE` so totals appear in the log and e-mail
* Setup lets you set timeouts and retry counts to avoid stalled transfers


Folder layout
-------------
PortableBackupKit\
    rclone.exe
    setup.ps1          (wizard – run once)
    backup.ps1         (job script)
    update.ps1         (pulls latest toolkit files)
    menu.bat           (interactive menu)
    rclone.conf        (generated, encrypted settings)
    README.txt
    INSTRUCTIONS.txt
    <Destination root>\
        current\
        archive\YYYY-MM-DD_HHMMSS\

Requirements
------------
* Windows 10 or 11 with PowerShell 5.x
* Your SFTP host, port, username, password
* Disk space for the mirror plus snapshots
* (Optional) Brevo v3 API key and a verified sender address

* Git for Windows in PATH or a complete PortableGit distribution next to the scripts for update.ps1

Quick start
-----------
1. Extract this folder, for example to C:\Tools\PortableBackupKit
2. Open an *elevated* PowerShell window in that folder
3. Run `menu.bat` and choose **Setup**
   (or run `Set-ExecutionPolicy -Scope Process Bypass -Force; .\setup.ps1`)
   (the wizard re-prompts if the server, username or password are blank.
    Press **Enter** for the remote path to use `/`. A destination folder is required and re-prompts until valid.

WPX.NET: create an SFTP user
----------------------------
1. Log in at `my.wpx.net` and open **Manage Service** for your hosting plan.
2. Go to **SFTP/FTP Users** and choose **Add new user**.
3. Pick a username, password and set the root path to back up (e.g. `/public_html`).
4. Save the user. WPX listens on port `2222` for SFTP, so use that in setup.

Live log
--------
To watch a job in real time:
    powershell -ExecutionPolicy Bypass -File .\backup.ps1 Get-Content -Wait -Tail 10 "<dest path>\backup.log"

Uninstall
---------
Run `uninstall.ps1` to remove the Task-Scheduler job "Portable Rclone Incremental Backup".
The script can also delete `rclone.conf`, `last-run.txt`, `backup.log` and any local backup folders.
`backup.ps1` is now static and is always kept.
Each item is removed only when you respond **Y** to its prompt.
Deleting the entire PortableBackupKit folder is only needed after
running the script.
Deletion only happens when you reply `Y` to each prompt.

See INSTRUCTIONS.txt for step-by-step details and troubleshooting.

Notes
-----
* Quoted SFTP parameters so passwords with spaces or special characters work.
* `ERROR : Attempt 2/3 succeeded` in `backup.log` means the first try failed but
  a retry was successful.
* Run `Set-ExecutionPolicy` and `./setup.ps1` as two commands or join them with a semicolon.
* `setup.ps1` now checks if the remote entry exists in `rclone.conf` before updating.
  When missing, it runs `config create` instead of `config update`.
* Reliability options (timeouts and retries) are stored in `rclone.conf`; rerunning the wizard shows them as defaults.
* Saved SFTP host, port, username and paths are reused from rclone.conf; only the password must be entered again.


SFTP CREDENTIALS
----------
FTP Settings

The server, username and password are required; setup re-prompts until all three are provided.

SFTP Server : your_sftp_host or (your_sftp_ip)
Port : 2222

SFTP username : your_username
SFTP password : your_password

Brevo Key:
YOUR_BREVO_KEY

Sender Email:
your_sender_email@example.com
Sender Name:
Backup Bot

send to: <any email>

This toolkit is distributed under the MIT License. See the LICENSE file in the repository root for details.
