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
* Keeps only the last 30 days of snapshots (changeable)
* Runs on a schedule you choose (daily, every N hours, or weekly)
* Shows live progress in the console and in backup.log
* Optional Brevo e-mail when a run finishes

Folder layout
-------------
PortableBackupKit\
    rclone.exe
    setup.ps1          (wizard – run once)
    backup.ps1         (generated job)
    rclone.conf        (generated, encrypted)
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

Live log
--------
To watch a job in real time:
    powershell -ExecutionPolicy Bypass -File .\backup.ps1 Get-Content -Wait -Tail 10 "<dest path>\backup.log"

Uninstall
---------
Delete the Task-Scheduler job "Portable Rclone Incremental Backup",
then delete the PortableBackupKit folder.

See INSTRUCTIONS.txt for step-by-step details and troubleshooting.



SFTP CREDENTIALS
----------
FTP Settings

SFTP Server : s20.wpxhosting.com or (67.202.92.20)
Port : 2222

SFTP username : jshirley.ftp@dianedrain.com
SFTP password : @20ILoveDianeDrainsWebsite25!

Brevo Key:
dd
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

gds
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

Sender Email:
no-reply@dianedrain.com

send to: <any email>
