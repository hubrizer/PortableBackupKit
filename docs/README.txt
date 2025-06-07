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
* Keeps snapshots for 7 days by default (configurable up to 30)
* Runs on a schedule you choose (daily, every N hours, or weekly)
* Shows live progress in the console and in backup.log
* Optional Brevo e-mail when a run finishes, including remote type, host, port and user

Folder layout
-------------
PortableBackupKit\
    rclone.exe
    setup.ps1          (wizard – run once)
    backup.ps1         (job script)
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

Quick start
-----------
1. Extract this folder, for example to C:\Tools\PortableBackupKit
2. Open an *elevated* PowerShell window in that folder
3. Run:
       Set-ExecutionPolicy -Scope Process Bypass -Force .\setup.ps1
4. Answer the prompts
   (the wizard re-prompts if the server, username or password are blank.
    Credentials are tested before continuing. Press **Enter** for the remote
    path to use `/` and be sure the destination folder is a valid local path.)

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
The script can also delete `rclone.conf`, `backup.ps1`, `last-run.txt`,
`backup.log` and any local backup folders.
Deleting the entire PortableBackupKit folder is only needed after
running the script.

See INSTRUCTIONS.txt for step-by-step details and troubleshooting.



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
