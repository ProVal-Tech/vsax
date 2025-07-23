<#
Required variable inputs:
None

Required variable outputs:
Name: 'OutputRDPEnableStatus'
Default Value: 'Not Checked'
Associated Custom Field: 'Audit: System: cPVAL RDP Enable Status'

Note: This script is designed for auditing purposes within an RMM environment.
#>

# Initialize the output variable
$OutputRDPEnableStatus = 'Disabled' # Default to disabled unless found enabled

Write-Output 'Checking Remote Desktop Protocol (RDP) status...'

# 1. Check RDP Registry Setting
# The fDenyTSConnections registry value determines if RDP is enabled (0) or disabled (1).
# Path: HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server
$rdpRegPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server'
$fDenyTSConnections = $null

try {
    $regValue = Get-ItemProperty -Path $rdpRegPath -Name 'fDenyTSConnections' -ErrorAction Stop
    $fDenyTSConnections = $regValue.fDenyTSConnections
    Write-Output "Registry value 'fDenyTSConnections' found: $fDenyTSConnections"
}
catch {
    Write-Warning "Could not read RDP registry setting ($rdpRegPath\fDenyTSConnections). Error: $($_.Exception.Message)"
    # If the key isn't found, it might default to disabled or an unknown state.
    # We'll treat this as 'Disabled' or 'Unknown' for safety.
}

# 2. Check 'Remote Desktop Services' Service Status
$serviceName = 'TermService' # This is the service name for 'Remote Desktop Services'
$serviceStatus = $null

try {
    $service = Get-Service -Name $serviceName -ErrorAction Stop
    $serviceStatus = $service.Status
    Write-Output "Remote Desktop Services (TermService) status: $serviceStatus"
}
catch {
    Write-Warning "Could not retrieve status for service '$serviceName'. Error: $($_.Exception.Message)"
    # If the service isn't found, RDP cannot be functional.
    $serviceStatus = 'Not Found'
}

# 3. Determine Final RDP Status
if ($fDenyTSConnections -eq 0) {
    # RDP is enabled via registry
    if ($serviceStatus -eq 'Running') {
        $OutputRDPEnableStatus = 'Enabled'
    } elseif ($serviceStatus -eq 'Stopped') {
        $OutputRDPEnableStatus = 'Enabled'
    } else { # e.g., 'Not Found', 'Paused', etc.
        $OutputRDPEnableStatus = "Enabled $serviceStatus" # 'RDP Enabled | Service Not Found' or 'RDP Enabled | Service Paused'
    }
} elseif ($fDenyTSConnections -eq 1) {
    # RDP is disabled via registry
    $OutputRDPEnableStatus = 'Disabled'
} else {
    # Registry value not 0 or 1, or not found.
    # In practice, 'fDenyTSConnections' usually is 0 or 1.
    # If not found or another value, it's safer to consider it disabled or unknown.
    $OutputRDPEnableStatus = "Unknown: $($fDenyTSConnections -join ',')"
}

# Log the result for RMM
Write-Output "Extended Audit: System: cPVAL RDP Enable Status: $OutputRDPEnableStatus"

# As noted before, for VSAx, the Write-Output line is generally sufficient.
Start-Process -FilePath "$env:VSX_HOME\CLI.exe" -ArgumentList ("setVariable OutputRDPEnableStatus `"$OutputRDPEnableStatus`"") -Wait