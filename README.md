# PortableBackupKit

PortableBackupKit is a self-contained Windows toolkit for making automatic, incremental SFTP backups with `rclone`.
No installation is required; simply unzip the folder and run the setup wizard.

## Key scripts

- `setup.ps1` – interactive wizard that collects SFTP credentials and sets the backup schedule.
  It creates `rclone.conf` and a scheduled task.
- `backup.ps1` – job script run by Task Scheduler. Mirrors the remote into `current` and stores
  dated snapshots under `archive/`. It can optionally send a Brevo email report.
- `restore.ps1` – restore wizard that uploads a selected snapshot back to the SFTP server.
- `uninstall.ps1` – removes the scheduled task and can delete configuration files and local backups.
- `update.ps1` – pulls the latest version of the toolkit from this repository.
- `menu.bat` – interactive menu for setup, restore, uninstall or update

## Quick start

1. Extract the PortableBackupKit folder to any location, e.g. `C:\Tools\PortableBackupKit`.
2. Launch an **elevated** PowerShell window in that folder.
3. Run `menu.bat` and choose **Setup**
   (or run `Set-ExecutionPolicy -Scope Process Bypass -Force; .\setup.ps1`)
4. Answer the prompts. The first backup will run according to the schedule you choose.

See [docs/README.txt](docs/README.txt)
and [docs/INSTRUCTIONS.txt](docs/INSTRUCTIONS.txt) for full instructions and troubleshooting tips.

## Log messages

Rclone may retry a failed operation automatically. When that happens you might see a line like:

```text
ERROR : Attempt 2/3 succeeded
```

Even though rclone labels it as an error, this simply means the retry worked and the run continues normally.
