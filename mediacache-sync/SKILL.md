---
name: mediacache-sync
description: Sync MediaCacheService repo from GitHub csp branch. Use when you need to pull latest changes from https://github.com/hututuxinyu/MediaCacheService.git csp branch or set up scheduled sync.
---

# MediaCacheService Sync

Syncs the `csp` branch from `https://github.com/hututuxinyu/MediaCacheService.git` to local `D:\Code\MediaCacheService`.

## Manual Sync

Run the sync script:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.config\opencode\skills\mediacache-sync\sync.ps1"
```

Or use opencode command:

```
/opencode command mediacache-sync
```

## Scheduled Sync (Windows Task Scheduler)

To set up automatic sync every hour:

```powershell
# Create scheduled task
$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$env:USERPROFILE\.config\opencode\skills\mediacache-sync\sync.ps1`""
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Hours 1)
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -DontStopOnIdleEnd
Register-ScheduledTask -TaskName "MediaCacheService-Sync" -Action $action -Trigger $trigger -Settings $settings -RunLevel Highest
```

To remove the scheduled task:

```powershell
Unregister-ScheduledTask -TaskName "MediaCacheService-Sync" -Confirm:$false
```

## Sync Script Location

- Script: `~/.config/opencode/skills/mediacache-sync/sync.ps1`
- Log: `~/.config/opencode/skills/mediacache-sync/sync.log`

## What the Script Does

1. Checks if `D:\Code\MediaCacheService` exists
2. Fetches from remote origin
3. Compares local `dev` branch with remote `csp` branch
4. If remote has new commits, merges them into local `dev`
5. Logs all actions with timestamps