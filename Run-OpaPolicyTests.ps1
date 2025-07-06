param (
    [string]$RunTerraformInit = "true",
    [string]$RunTerraformValidate = "true",
    [string]$RunTerraformPlan = "true",
    [string]$RunTerraformPlanDestroy = "false",
    [string]$RunTerraformApply = "false",
    [string]$RunTerraformDestroy = "false",
    [string]$TerraformInitExtraArgsJson = '["-upgrade"]',
    [string]$TerraformPlanExtraArgsJson = '[]',
    [string]$TerraformPlanDestroyExtraArgsJson = '[]',
    [string]$TerraformApplyExtraArgsJson = '[]',
    [string]$TerraformDestroyExtraArgsJson = '[]',
    [string]$DebugMode = "false",
    [string]$DeletePlanFiles = "false",
    [string]$TerraformPlanFileName = "tfplan.plan",
    [string]$TerraformDestroyPlanFileName = "tfplan-destroy.plan",
    [string]$TerraformCodeLocation = "tests/builds/opa/resource-naming"
)

$ErrorActionPreference = 'Stop'
$currentWorkingDirectory = (Get-Location).path
$fullTerraformCodePath = Join-Path -Path $currentWorkingDirectory -ChildPath $TerraformCodeLocation

# Get script directory
$scriptDir = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent

# Import all required modules
$modules = @("Logger", "Utils", "Terraform", "Tenv", "Opa")
$modulesFolder = "PowerShellModules"
foreach ($module in $modules)
{
    $modulePath = Join-Path -Path $scriptDir -ChildPath "$modulesFolder/$module.psm1"
    if (Test-Path $modulePath)
    {
        Import-Module $modulePath -Force -ErrorAction Stop
    }
    else
    {
        Write-Host "ERROR:  [$( $MyInvocation.MyCommand.Name )] Module not found: $modulePath" -ForegroundColor Red
        exit 1
    }
}


# Log that modules were loaded
_LogMessage -Level "INFO" -Message "[$( $MyInvocation.MyCommand.Name )] Modules loaded successfully" -InvocationName "$( $MyInvocation.MyCommand.Name )"

$convertedDebugMode = ConvertTo-Boolean $DebugMode
_LogMessage -Level 'DEBUG' -Message "DebugMode: `"$DebugMode`" → $convertedDebugMode" -InvocationName "$( $MyInvocation.MyCommand.Name )"

# Enable debug mode if DebugMode is set to $true
if ($true -eq $convertedDebugMode)
{
    $Global:DebugPreference = 'Continue'     # module functions see this
    $Env:TF_LOG = 'DEBUG'         # Terraform debug
}
else
{
    $Global:DebugPreference = 'SilentlyContinue'
}

try
{
    $TerraformInitExtraArgs = $TerraformInitExtraArgsJson | ConvertFrom-Json
    $TerraformPlanExtraArgs = $TerraformPlanExtraArgsJson | ConvertFrom-Json
    $TerraformPlanDestroyExtraArgs = $TerraformPlanDestroyExtraArgsJson | ConvertFrom-Json
    $TerraformApplyExtraArgs = $TerraformApplyExtraArgsJson | ConvertFrom-Json
    $TerraformDestroyExtraArgs = $TerraformDestroyExtraArgsJson | ConvertFrom-Json

    Get-InstalledPrograms -Programs @("terraform")

    $convertedRunTerraformInit = ConvertTo-Boolean $RunTerraformInit
    $convertedRunTerraformValidate = ConvertTo-Boolean $RunTerraformValiate
    $convertedRunTerraformPlan = ConvertTo-Boolean $RunTerraformPlan
    $convertedRunTerraformPlanDestroy = ConvertTo-Boolean $RunTerraformPlanDestroy
    $convertedRunTerraformApply = ConvertTo-Boolean $RunTerraformApply
    $convertedRunTerraformDestroy = ConvertTo-Boolean $RunTerraformDestroy
    $convertedDeletePlanFiles = ConvertTo-Boolean $DeletePlanFiles

    # ── Chicken-and-egg / mutual exclusivity checks ───────────────────────────────
    if (-not $convertedRunTerraformInit -and (
    $convertedRunTerraformPlan -or
            $convertedRunTerraformPlanDestroy -or
            $convertedRunTerraformApply -or
            $convertedRunTerraformDestroy))
    {
        $msg = 'Terraform init must be run before plan / apply / destroy operations.'
        _LogMessage -Level 'ERROR' -Message $msg -InvocationName $MyInvocation.MyCommand.Name
        throw $msg
    }

    if ($convertedRunTerraformPlan -and $convertedRunTerraformPlanDestroy)
    {
        $msg = 'Both Terraform Plan and Terraform Plan-Destroy cannot be true at the same time.'
        _LogMessage -Level 'ERROR' -Message $msg -InvocationName $MyInvocation.MyCommand.Name
        throw $msg
    }

    if ($convertedRunTerraformApply -and $convertedRunTerraformDestroy)
    {
        $msg = 'Both Terraform Apply and Terraform Destroy cannot be true at the same time.'
        _LogMessage -Level 'ERROR' -Message $msg -InvocationName $MyInvocation.MyCommand.Name
        throw $msg
    }

    if (-not $convertedRunTerraformPlan -and $convertedRunTerraformApply)
    {
        $msg = 'You must run terraform **plan** together with **apply** when using this script.'
        _LogMessage -Level 'ERROR' -Message $msg -InvocationName $MyInvocation.MyCommand.Name
        throw $msg
    }

    if (-not $convertedRunTerraformPlanDestroy -and $convertedRunTerraformDestroy)
    {
        $msg = 'You must run terraform **plan destroy** together with **destroy** when using this script.'
        _LogMessage -Level 'ERROR' -Message $msg -InvocationName $MyInvocation.MyCommand.Name
        throw $msg
    }

    # terraform fmt – always safe
    Invoke-TerraformFmtCheck  -CodePath $fullTerraformCodePath

    # ── INIT ──────────────────────────────────────────────────────────────
    if ($convertedRunTerraformInit)
    {
        Invoke-TerraformInit `
                -CodePath $fullTerraformCodePath `
                -InitArgs $TerraformInitExtraArgs
    }

    # ── VALIDATE ──────────────────────────────────────────────────────────
    if ($convertedRunTerraformInit -and $convertedRunTerraformValidate)
    {
        Invoke-TerraformValidate -CodePath $fullTerraformCodePath
    }

    # ── PLAN / PLAN-DESTROY ───────────────────────────────────────────────
    if ($convertedRunTerraformPlan)
    {
        Invoke-TerraformPlan -CodePath $fullTerraformCodePath -PlanArgs $TerraformPlanExtraArgs -PlanFile $TerraformPlanFileName
    }
    elseif ($convertedRunTerraformPlanDestroy)
    {
        Invoke-TerraformPlanDestroy -CodePath $fullTerraformCodePath -PlanArgs $TerraformPlanDestroyExtraArgs -PlanFile $TerraformDestroyPlanFileName
    }

    # JSON + Checkov need a plan file
    if ($convertedRunTerraformPlan -or $convertedRunTerraformPlanDestroy)
    {

        if ($convertedRunTerraformPlan)
        {
            $TfPlanFileName = $TerraformPlanFileName
            Convert-TerraformPlanToJson -CodePath $fullTerraformCodePath -PlanFile $TfPlanFileName
        }

        if ($convertedRunTerraformPlanDestroy)
        {
            $TfPlanFileName = $TerraformDestroyPlanFileName
        }
    }

    # ── APPLY / DESTROY ───────────────────────────────────────────────────
    if ($convertedRunTerraformApply)
    {
        Invoke-TerraformApply -CodePath $fullTerraformCodePath -SkipApprove -ApplyArgs $TerraformApplyExtraArgs
    }
    elseif ($convertedRunTerraformDestroy)
    {
        Invoke-TerraformDestroy -CodePath $fullTerraformCodePath -SkipApprove -DestroyArgs $TerraformDestroyExtraArgs
    }
}

catch
{
    _LogMessage -Level "ERROR" -Message "Error: $( $_.Exception.Message )" -InvocationName "$( $MyInvocation.MyCommand.Name )"
    exit 1
}
finally
{
    if ($convertedDeletePlanFiles)
    {

        $patterns = @(
            $TfPlanFileName,
            "${TfPlanFileName}.json",
            "${TfPlanFileName}-destroy.tfplan",
            "${TfPlanFileName}-destroy.tfplan.json"
        )

        foreach ($pat in $patterns)
        {

            $file = Join-Path $fullTerraformCodePath $pat
            if (Test-Path $file)
            {
                try
                {
                    Remove-Item $file -Force -ErrorAction Stop
                    _LogMessage -Level DEBUG -Message "Deleted $file" `
                                    -InvocationName $MyInvocation.MyCommand.Name
                }
                catch
                {
                    _LogMessage -Level WARN -Message "Failed to delete $file – $( $_.Exception.Message )" `
                                    -InvocationName $MyInvocation.MyCommand.Name
                }
            }
            else
            {
                _LogMessage -Level DEBUG -Message "No file to delete: $file" `
                                -InvocationName $MyInvocation.MyCommand.Name
            }
        }
    }
    else
    {
        _LogMessage -Level DEBUG -Message 'DeletePlanFiles is false – leaving plan files in place.' `
                    -InvocationName $MyInvocation.MyCommand.Name
    }

    $Env:TF_LOG = $null
    Set-Location $currentWorkingDirectory
}
