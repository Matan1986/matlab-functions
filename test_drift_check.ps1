param(
    [string]$RunDir = "C:\Dev\matlab-functions\results\switching\runs\run_2026_03_28_131759_minimal_canonical"
)

# Test the exact drift check logic from run_matlab_safe.bat
$repoRoot = "C:\Dev\matlab-functions"

function NormalizePathToken([string]$p, [string]$root) { 
    if ([string]::IsNullOrWhiteSpace($p)) { return $null }
    $raw = $p.Trim()
    $n = $raw.Replace('\','/')
    if ($n.StartsWith('./')) { $n = $n.Substring(2) }
    try { 
        if ([System.IO.Path]::IsPathRooted($raw)) { 
            $full = [System.IO.Path]::GetFullPath($raw) 
        } else { 
            $full = [System.IO.Path]::GetFullPath((Join-Path $root $raw)) 
        }
        $rootFull = [System.IO.Path]::GetFullPath($root)
        if ($full.StartsWith($rootFull, [System.StringComparison]::OrdinalIgnoreCase)) { 
            return [System.IO.Path]::GetRelativePath($rootFull, $full).Replace('\','/').ToLowerInvariant() 
        } 
    } catch {}
    return $n.ToLowerInvariant() 
}

Write-Host "Testing drift check on: $RunDir"

if ($RunDir -eq 'NA') { 
    Write-Host "RESULT: __DRIFT_UNKNOWN__|RUN_DIR_NOT_FOUND__"
    exit 1 
}

Push-Location -LiteralPath $RunDir
try { 
    if (-not (Test-Path 'run_manifest.json')) { 
        Write-Host "RESULT: __DRIFT_UNKNOWN__|MANIFEST_NOT_FOUND__"
        exit 1 
    }
    
    try { 
        $m = Get-Content -LiteralPath 'run_manifest.json' -Raw | ConvertFrom-Json 
    } catch { 
        Write-Host "RESULT: __DRIFT_UNKNOWN__|MANIFEST_PARSE_ERROR__"
        exit 1 
    }
    
    $expected = $m.outputs
    if ($null -eq $expected) { 
        Write-Host "RESULT: __DRIFT_UNKNOWN__|NO_OUTPUTS_DECLARED__"
        exit 1 
    }
    
    $expectedRaw = @()
    if ($expected -is [System.Array]) { 
        $expectedRaw = $expected 
    } else { 
        $expectedRaw = @($expected) 
    }
    
    $expectedNorm = @($expectedRaw | ForEach-Object { 
        if ($_ -is [string]) { 
            NormalizePathToken $_ $repoRoot 
        } elseif ($_ -and $_.path) { 
            NormalizePathToken $_.path $repoRoot 
        } 
    } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object -Unique)
    
    Write-Host "Expected (normalized): $($expectedNorm.Count) files"
    $expectedNorm | ForEach-Object { Write-Host "  - $_" }
    
    $actualExist = @($expectedNorm | Where-Object { 
        try { 
            (Test-Path -LiteralPath $_) 
        } catch { 
            $false 
        } 
    })
    
    Write-Host "Actual existing: $($actualExist.Count) files"
    $actualExist | ForEach-Object { Write-Host "  - $_" }
    
    $missing = @($expectedNorm | Where-Object { $_ -notin $actualExist })
    
    if ($missing.Count -gt 0) { 
        $reason = "missing_count_$($missing.Count)"
        Write-Host "Missing files: $($missing.Count)"
        $missing | ForEach-Object { Write-Host "  - $_" }
        Write-Host "RESULT: __DRIFT_YES__|$reason"
        exit 0 
    } else { 
        Write-Host "RESULT: __DRIFT_NO__|NONE"
        exit 0 
    } 
} finally { 
    Pop-Location 
}
