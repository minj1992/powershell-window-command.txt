#2019 winodw server
#https://chatgpt.com/share/66e44a42-b424-8009-92fe-c7ffd0295a3a
# Variables
$NewComputerName = "app010w001"
$LocalAdminPassword = "Login%123456"
$DomainName = "minjtech.xyz"
$NetbiosName = "MINJTECH"
$ForestMode = "WinThreshold"
$DomainMode = "WinThreshold"

# Log function
function Write-Log {
    param (
        [string]$message
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Output "$timestamp - $message" | Out-File -FilePath "C:\SetupLog.txt" -Append
}

# Function to handle reboot and resume script after reboot
function Test-PendingReboot {
    return (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending') -or
           (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired') -or
           (Test-Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\PendingFileRenameOperations') -or
           ((Get-WmiObject -Class Win32_ComputerSystem).RebootPending)
}

# Stage 1: Rename the computer and restart if needed
if (-not (Test-Path -Path "C:\SetupStage.txt")) {
    try {
        Write-Log "Changing computer name to $NewComputerName."
        Rename-Computer -NewName $NewComputerName -Force -Restart
        Write-Log "Computer renamed to $NewComputerName, restarting."
        
        # Set stage to track progress
        Set-Content -Path "C:\SetupStage.txt" -Value "Stage1"
        
        # Reboot after renaming
        Restart-Computer -Force
        exit
    } catch {
        Write-Log "Error renaming the computer: $_"
        exit 1
    }
}

# Stage 2: Set Administrator password
if ((Get-Content "C:\SetupStage.txt") -eq "Stage1" -and -not (Test-PendingReboot)) {
    try {
        Write-Log "Setting password for the Administrator user."
        $Password = ConvertTo-SecureString $LocalAdminPassword -AsPlainText -Force
        Set-LocalUser -Name "Administrator" -Password $Password
        Write-Log "Administrator password updated."

        # Move to next stage
        Set-Content -Path "C:\SetupStage.txt" -Value "Stage2"
    } catch {
        Write-Log "Error setting the Administrator password: $_"
        exit 1
    }
}

# Stage 3: Set the IPv4 DNS server to the private IP
if ((Get-Content "C:\SetupStage.txt") -eq "Stage2" -and -not (Test-PendingReboot)) {
    try {
        Write-Log "Getting private IP address."
        # Get the private IP address (exclude link-local addresses and loopback)
        $privateIP = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object {
            $_.IPAddress -notlike '169.254*' -and $_.InterfaceAlias -notlike "Loopback*"
        }).IPAddress
        
        Write-Log "Private IP found: $privateIP."
        
        # Get the adapter using the private IP
        $adapter = Get-NetIPAddress -AddressFamily IPv4 | Where-Object {
            $_.IPAddress -eq $privateIP
        } | Select-Object -ExpandProperty InterfaceAlias

        # Set DNS server to the private IP
        Write-Log "Setting DNS to $privateIP on adapter $adapter."
        Set-DnsClientServerAddress -InterfaceAlias $adapter -ServerAddresses $privateIP
        Write-Log "DNS updated to $privateIP on adapter $adapter."

        # Move to next stage
        Set-Content -Path "C:\SetupStage.txt" -Value "Stage3"
    } catch {
        Write-Log "Error configuring DNS: $_"
        exit 1
    }
}

# Stage 4: Install and configure AD DS
if ((Get-Content "C:\SetupStage.txt") -eq "Stage3" -and -not (Test-PendingReboot)) {
    try {
        Write-Log "Installing AD DS role."
        Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools
        Write-Log "AD DS role installed."

        # Promote to domain controller
        Write-Log "Promoting server as Domain Controller for domain $DomainName."
        Import-Module ADDSDeployment
        Install-ADDSForest `
        -CreateDnsDelegation:$false `
        -DatabasePath "C:\Windows\NTDS" `
        -DomainMode $DomainMode `
        -DomainName $DomainName `
        -DomainNetbiosName $NetbiosName `
        -ForestMode $ForestMode `
        -InstallDns:$true `
        -LogPath "C:\Windows\NTDS" `
        -NoRebootOnCompletion:$false `
        -SysvolPath "C:\Windows\SYSVOL" `
        -Force:$true
        Write-Log "Domain Controller promotion completed."

        # Clean up
        Remove-Item "C:\SetupStage.txt" -Force
        Write-Log "Setup complete. Cleaned up stage file."
    } catch {
        Write-Log "Error promoting server as Domain Controller: $_"
        exit 1
    }
}
