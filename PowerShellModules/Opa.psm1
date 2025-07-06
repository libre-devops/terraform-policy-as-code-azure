function Invoke-InstallConftest {
    [CmdletBinding()]
    param()

    $inv = $MyInvocation.MyCommand.Name
    $os  = Assert-WhichOs -PassThru

    if ($os.ToLower() -eq 'windows') {
        _LogMessage -Level INFO -Message "Installing Conftest via Scoop on Windows…" -InvocationName $inv

        if (Get-Command scoop -ErrorAction SilentlyContinue) {
            scoop install conftest
        }
        elseif (Get-Command choco -ErrorAction SilentlyContinue) {
            choco install -y conftest
        }
        elseif (Get-Command winget -ErrorAction SilentlyContinue) {
            winget install --id Instrumenta.Conftest -e
        }
        else {
            _LogMessage -Level ERROR -Message "No Scoop/Chocolatey/Winget found; cannot install Conftest." -InvocationName $inv
            throw "Cannot install Conftest: package manager missing."
        }
    }
    elseif ($os.ToLower() -in @('linux','macos')) {
        Assert-HomebrewPath
        _LogMessage -Level INFO -Message "Installing Conftest via Homebrew…" -InvocationName $inv
        brew install conftest     # formula exists in Homebrew core :contentReference[oaicite:0]{index=0}
    }
    else {
        _LogMessage -Level ERROR -Message "Unsupported OS for Conftest install: $os" -InvocationName $inv
        throw "Unsupported OS: $os"
    }

    # verify
    Get-InstalledPrograms -Programs @('conftest')
}

function Invoke-Conftest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $CodePath,              # repo / module root
        [string]  $PlanJsonFile = 'tfplan.plan.json',          # same default as your Checkov helper
        [string]  $PolicyDir    = 'policy',                    # relative to $CodePath
        [switch]  $SoftFail,                                   # continue on violations
        [string[]]$ExtraArgs    = @()                          # pass-through for anything exotic
    )

    #── locate plan ─────────────────────────────────────────────────────────
    $planPath = Join-Path $CodePath $PlanJsonFile
    if (-not (Test-Path $planPath)) {
        _LogMessage -Level ERROR -Message "JSON plan not found: $planPath" -InvocationName $MyInvocation.MyCommand.Name
        throw "JSON plan not found: $planPath"
    }

    #── locate policy dir ───────────────────────────────────────────────────
    $policyPath = Join-Path $CodePath $PolicyDir
    if (-not (Test-Path $policyPath)) {
        _LogMessage -Level WARN -Message "Policy directory not found ($policyPath) – falling back to built-in policies (if any)." -InvocationName $MyInvocation.MyCommand.Name
    }

    #── build CLI args ──────────────────────────────────────────────────────
    $conftestArgs = @(
        'test', $planPath
        '--policy', $policyPath
    ) + $ExtraArgs

    _LogMessage -Level INFO -Message "Executing Conftest: conftest $(($conftestArgs -join ' '))" -InvocationName $MyInvocation.MyCommand.Name

    & conftest @conftestArgs
    $code = $LASTEXITCODE

    if ($code -eq 0) {
        _LogMessage -Level INFO -Message 'Conftest completed with no failed tests.' -InvocationName $MyInvocation.MyCommand.Name
    }
    elseif ($SoftFail) {
        _LogMessage -Level WARN -Message "Conftest found issues (exit $code) – continuing because -SoftFail." -InvocationName $MyInvocation.MyCommand.Name
    }
    else {
        _LogMessage -Level ERROR -Message "Conftest reported failures (exit $code)." -InvocationName $MyInvocation.MyCommand.Name
        throw "Conftest failed (exit $code)."
    }
}

Export-ModuleMember -Function `
    Invoke-Conftest, `
    Invoke-InstallConftest
