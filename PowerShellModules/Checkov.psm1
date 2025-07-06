function Invoke-InstallCheckov
{
    [CmdletBinding()]
    param()

    $inv = $MyInvocation.MyCommand.Name
    $os = Assert-WhichOs -PassThru

    if ($os.toLower() -eq 'windows')
    {
        # on Windows, install via pip (or pip3/pipx if you prefer)
        _LogMessage -Level INFO -Message "Installing Checkov via pip on Windows…" -InvocationName $inv

        if (Get-Command pipx -ErrorAction SilentlyContinue)
        {
            pipx install checkov
        }
        elseif (Get-Command pip3 -ErrorAction SilentlyContinue)
        {
            pip3 install --upgrade checkov
        }
        elseif (Get-Command pip -ErrorAction SilentlyContinue)
        {
            pip install --upgrade checkov
        }
        else
        {
            _LogMessage -Level ERROR -Message "No pip/pip3/pipx found; cannot install Checkov." -InvocationName $inv
            throw "Cannot install Checkov: pip/pip3/pipx missing."
        }
    }
    elseif ($os.toLower() -eq 'linux' -or 'macos')
    {
        # on *nix, use Homebrew
        Assert-HomebrewPath
        _LogMessage -Level INFO -Message "Installing Checkov via Homebrew…" -InvocationName $inv
        brew install checkov
    }
    else
    {
        _LogMessage -Level ERROR -Message "Unsupported OS for Checkov install: $os" -InvocationName $inv
        throw "Unsupported OS: $os"
    }

    # verify
    Get-InstalledPrograms -Programs @('checkov')
}

function Invoke-Checkov
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $CodePath,
        [string]  $PlanJsonFile = 'tfplan.plan.json',

        [string]  $CheckovSkipChecks = '',
        [switch]  $SoftFail,

        [string[]]$ExtraArgs = @()
    )

    #── find the JSON plan ─────────────────────────────────────────────────
    $planPath = Join-Path $CodePath $PlanJsonFile
    if (-not (Test-Path $planPath))
    {
        _LogMessage -Level 'ERROR' -Message "JSON plan not found: $planPath" `
                    -InvocationName $MyInvocation.MyCommand.Name
        throw "JSON plan not found: $planPath"
    }

    #── build --skip-check … if supplied ──────────────────────────────────
    $skipArgument = @()
    if ($CheckovSkipChecks.Trim())
    {
        $list = ($CheckovSkipChecks -split ',') |
                ForEach-Object { $_.Trim() } | Where-Object { $_ }
        if ($list)
        {
            # Single DEBUG log with all checks as a formatted list
            $msg = "Checkov will skip:`n"
            foreach ($check in $list) {
                $msg += "- $check`n"
            }
            _LogMessage -Level 'DEBUG' -Message $msg.TrimEnd() `
                        -InvocationName $MyInvocation.MyCommand.Name
            $skipArgument = @('--skip-check', ($list -join ','))
        }
        else
        {
            _LogMessage -Level 'DEBUG' -Message "No tests are being skipped." `
                        -InvocationName $MyInvocation.MyCommand.Name
        }
    }
    else
    {
        _LogMessage -Level 'DEBUG' -Message "No tests are being skipped." `
                    -InvocationName $MyInvocation.MyCommand.Name
    }

    #── base Checkov arguments ─────────────────────────────────────────────
    $checkovArgs = @(
        '-f', $planPath
        '--repo-root-for-plan-enrichment', $CodePath
        '--download-external-modules', 'false'
    ) + $skipArgument + $ExtraArgs

    if ($SoftFail)
    {
        $checkovArgs += '--soft-fail'
    }

    _LogMessage -Level 'INFO' -Message "Executing Checkov: checkov $( $checkovArgs -join ' ' )" `
                -InvocationName $MyInvocation.MyCommand.Name

    & checkov @checkovArgs
    $code = $LASTEXITCODE

    if ($code -eq 0)
    {
        _LogMessage -Level 'INFO' -Message 'Checkov completed with no failed checks.' `
                    -InvocationName $MyInvocation.MyCommand.Name
    }
    elseif ($SoftFail)
    {
        _LogMessage -Level 'WARN' -Message "Checkov found issues (exit $code) – continuing because -SoftFail." `
                    -InvocationName $MyInvocation.MyCommand.Name
    }
    else
    {
        _LogMessage -Level 'ERROR' -Message "Checkov reported failures (exit $code)." `
                    -InvocationName $MyInvocation.MyCommand.Name
        throw "Checkov failed (exit $code)."
    }
}

function Invoke-CheckovSource {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $CodePath,

        [string] $ExternalChecksDir = 'checkov',

        [string] $CheckovSkipChecks = '',

        [switch] $SoftFail,

        [string[]] $ExtraArgs = @()
    )

    $inv = $MyInvocation.MyCommand.Name

    # ── validate paths ──────────────────────────────────────────────
    $resolvedCode = Resolve-Path -Path $CodePath -ErrorAction Stop
    if (-not (Test-Path $resolvedCode)) {
        _LogMessage -Level ERROR -Message "CodePath not found: $resolvedCode" -InvocationName $inv
        throw "CodePath not found: $resolvedCode"
    }

    $resolvedPolicies = Resolve-Path -Path $ExternalChecksDir -ErrorAction Stop
    if (-not (Test-Path $resolvedPolicies)) {
        _LogMessage -Level ERROR -Message "ExternalChecksDir not found: $resolvedPolicies" -InvocationName $inv
        throw "ExternalChecksDir not found: $resolvedPolicies"
    }

    # ── build --skip-check arg (if supplied) ───────────────────────
    $skipArg = @()
    if ($CheckovSkipChecks.Trim()) {
        $ids = ($CheckovSkipChecks -split ',') |
                ForEach-Object { $_.Trim() } | Where-Object { $_ }
        if ($ids) {
            _LogMessage -Level DEBUG -Message "Skipping checks: $($ids -join ', ')" -InvocationName $inv
            $skipArg = @('--skip-check', ($ids -join ','))
        }
    }

    # ── assemble Checkov arguments ─────────────────────────────────
    $checkovArgs = @(
        '-d', $resolvedCode
        '--external-checks-dir', $resolvedPolicies
    ) + $skipArg + $ExtraArgs

    if ($SoftFail) { $checkovArgs += '--soft-fail' }

    _LogMessage -Level INFO -Message "Executing Checkov: checkov $($checkovArgs -join ' ')" -InvocationName $inv

    & checkov @checkovArgs
    $exit = $LASTEXITCODE

    if ($exit -eq 0) {
        _LogMessage -Level INFO -Message 'Checkov source scan succeeded.' -InvocationName $inv
    } elseif ($SoftFail) {
        _LogMessage -Level WARN -Message "Checkov source scan reported failures (exit $exit) — continuing due to -SoftFail." -InvocationName $inv
    } else {
        _LogMessage -Level ERROR -Message "Checkov source scan failed (exit $exit)." -InvocationName $inv
        throw "Checkov source scan failed (exit $exit)."
    }
}

function Invoke-CheckovFlexible {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Path,                         # file (.json) or directory (.tf)

        [string] $ExternalChecksDir = 'checkov',

        [string] $CheckovSkipChecks = '',

        [switch] $SoftFail,

        [string[]] $ExtraArgs = @()
    )

    $inv = $MyInvocation.MyCommand.Name
    $resolvedPath = Resolve-Path -Path $Path -ErrorAction Stop

    if (-not (Test-Path $resolvedPath)) {
        _LogMessage -Level ERROR -Message "Path not found: $resolvedPath" -InvocationName $inv
        throw "Path not found: $resolvedPath"
    }

    # build --skip-check argument
    $skipArg = @()
    if ($CheckovSkipChecks.Trim()) {
        $ids = ($CheckovSkipChecks -split ',') | ForEach-Object { $_.Trim() } | Where-Object { $_ }
        if ($ids) { $skipArg = @('--skip-check', ($ids -join ',')) }
    }

    # detect plan vs source
    $isPlan = (Test-Path $resolvedPath -PathType Leaf) -and $resolvedPath.ToString().ToLower().EndsWith('.json')

    if ($isPlan) {
        # -------- plan scan --------
        $checkovArgs = @(
            '--framework', 'terraform_plan'
            '-f', $resolvedPath
            '--external-checks-dir', $ExternalChecksDir
            '--repo-root-for-plan-enrichment', (Split-Path $resolvedPath -Parent)  # enrich mod paths
            '--download-external-modules', 'false'
        )
    } else {
        # -------- source scan --------
        $checkovArgs = @(
            '-d', $resolvedPath
            '--external-checks-dir', $ExternalChecksDir
        )
    }

    $checkovArgs += $skipArg + $ExtraArgs
    if ($SoftFail) { $checkovArgs += '--soft-fail' }

    _LogMessage -Level INFO -Message "Executing Checkov: checkov $($checkovArgs -join ' ')" -InvocationName $inv

    & checkov @checkovArgs
    $exit = $LASTEXITCODE

    if ($exit -eq 0) {
        _LogMessage -Level INFO -Message 'Checkov completed with no failed checks.' -InvocationName $inv
    } elseif ($SoftFail) {
        _LogMessage -Level WARN -Message "Checkov reported failures (exit $exit) — continuing due to -SoftFail." -InvocationName $inv
    } else {
        _LogMessage -Level ERROR -Message "Checkov failed (exit $exit)." -InvocationName $inv
        throw "Checkov failed (exit $exit)."
    }
}



Export-ModuleMember -Function `
    Invoke-Checkov, `
    Invoke-InstallCheckov, `
    Invoke-CheckovFlexible, `
    Invoke-CheckovSource
