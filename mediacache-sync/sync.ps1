$ErrorActionPreference = "Continue"
$RepoPath = "D:\Code\MediaCacheService"
$RemoteUrl = "https://github.com/hututuxinyu/MediaCacheService.git"
$RemoteBranch = "csp"
$LocalBranch = "dev"
$LogPath = "$PSScriptRoot\sync.log"

function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] $Message"
    Write-Host $logEntry
    Add-Content -Path $LogPath -Value $logEntry -ErrorAction SilentlyContinue
}

Write-Log "=== MediaCacheService Sync Started ==="

if (-not (Test-Path -LiteralPath $RepoPath)) {
    Write-Log "ERROR: Repository not found at $RepoPath"
    Write-Log "Clone the repo first: git clone $RemoteUrl $RepoPath"
    exit 1
}

Push-Location -LiteralPath $RepoPath

try {
    $currentBranch = git rev-parse --abbrev-ref HEAD
    Write-Log "Current branch: $currentBranch"
    
    Write-Log "Fetching from origin..."
    git fetch origin 2>&1 | ForEach-Object { Write-Log "  $_" }
    
    $localCommit = git rev-parse $LocalBranch 2>$null
    $remoteCommit = git rev-parse "origin/$RemoteBranch" 2>$null
    
    if (-not $localCommit -or -not $remoteCommit) {
        Write-Log "ERROR: Could not get commit hashes"
        exit 1
    }
    
    Write-Log "Local $LocalBranch`: $localCommit"
    Write-Log "Remote origin/$RemoteBranch`: $remoteCommit"
    
    if ($localCommit -eq $remoteCommit) {
        Write-Log "No new commits. Already up to date."
    } else {
        $aheadCount = git rev-list --count "origin/$RemoteBranch..$LocalBranch" 2>$null
        $behindCount = git rev-list --count "$LocalBranch..origin/$RemoteBranch" 2>$null
        
        Write-Log "Local is $aheadCount commits ahead, $behindCount commits behind remote"
        
        if ($behindCount -gt 0) {
            Write-Log "New commits found on origin/$RemoteBranch. Syncing..."
            
            git checkout $LocalBranch 2>&1 | ForEach-Object { Write-Log "  $_" }
            
            $mergeResult = git merge "origin/$RemoteBranch" --no-edit 2>&1
            $mergeResult | ForEach-Object { Write-Log "  $_" }
            
            if ($LASTEXITCODE -eq 0) {
                Write-Log "SUCCESS: Merged origin/$RemoteBranch into $LocalBranch"
            } else {
                Write-Log "ERROR: Merge failed. Check for conflicts."
                git merge --abort 2>$null
            }
        }
    }
    
    if ($currentBranch -ne $LocalBranch) {
        git checkout $currentBranch 2>&1 | ForEach-Object { Write-Log "  $_" }
    }
} catch {
    Write-Log "ERROR: $($_.Exception.Message)"
} finally {
    Pop-Location
}

Write-Log "=== MediaCacheService Sync Completed ==="