# crearet the pt uing forward look up zone both a recored righ lick and update after running the script will reoslve the issue 
# Define the domain name
$DomainName = "minjtech.xyz"

# Function to get the private IP address (excludes loopback and APIPA)
function Get-PrivateIPAddress {
    $privateIP = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object {
        $_.IPAddress -notlike '169.254*' -and $_.InterfaceAlias -notlike "Loopback*"
    }).IPAddress
    return $privateIP
}

# Function to extract the first three octets of the IP address for reverse lookup zone creation
function Get-ReverseZoneName {
    param([string]$ipAddress)

    # Split the IP into octets and get the first three
    $octets = $ipAddress -split '\.'
    $reverseZone = "$($octets[2]).$($octets[1]).$($octets[0]).in-addr.arpa"
    
    return $reverseZone
}

# Function to create a reverse lookup zone
function Create-ReverseLookupZone {
    param ([string]$ReverseZone, [string]$NetworkId)

    try {
        Write-Host "Checking if the reverse lookup zone for $ReverseZone exists..."
        # Check if the reverse zone already exists
        $existingZone = Get-DnsServerZone -ZoneName $ReverseZone -ErrorAction SilentlyContinue
        if ($existingZone) {
            Write-Host "Reverse lookup zone $ReverseZone already exists." -ForegroundColor Yellow
            return
        }

        Write-Host "Creating reverse lookup zone for $ReverseZone..."
        # Create the reverse lookup zone
        Add-DnsServerPrimaryZone -NetworkId $NetworkId -ReplicationScope Domain
        Write-Host "Reverse lookup zone $ReverseZone created successfully!" -ForegroundColor Green
    } catch {
        Write-Host "Error creating reverse lookup zone: $_" -ForegroundColor Red
        exit 1
    }
}

# Function to create or update A record in forward lookup zone and handle PTR record
function Manage-DnsRecords {
    param ([string]$PrivateIP, [string]$ReverseZone)

    try {
        # Get the hostname (current machine's name)
        $hostname = hostname
        
        Write-Host "Creating A record for $hostname ($PrivateIP) and updating PTR record..."

        # Check if the A record already exists
        $existingARecord = Get-DnsServerResourceRecord -Name $hostname -ZoneName $DomainName -ErrorAction SilentlyContinue
        if ($existingARecord) {
            Write-Host "A record for $hostname already exists. Removing the existing record..." -ForegroundColor Yellow
            # Remove the existing A record
            Remove-DnsServerResourceRecord -Name $hostname -ZoneName $DomainName -Confirm:$false
        }

        # Create A record and ensure PTR record is automatically updated
        $aRecord = Add-DnsServerResourceRecordA -Name $hostname -ZoneName $DomainName -IPv4Address $PrivateIP -CreatePtr

        if ($aRecord) {
            Write-Host "A record created successfully for $hostname." -ForegroundColor Green
        } else {
            Write-Host "A record creation failed for $hostname." -ForegroundColor Red
            exit 1
        }
        
        # Verify PTR record creation
        $ptrRecord = Get-DnsServerResourceRecord -Name $hostname -ZoneName $ReverseZone -ErrorAction SilentlyContinue | Where-Object {$_.RecordType -eq 'PTR'}
        if ($ptrRecord) {
            Write-Host "PTR record successfully created: $($ptrRecord.HostName)" -ForegroundColor Green
        } else {
            Write-Host "PTR record creation failed. A record created but PTR record is missing." -ForegroundColor Red
        }
    } catch {
        Write-Host "Error creating A record or updating PTR: $_" -ForegroundColor Red
        exit 1
    }
}

# Main script execution
# Get the private IP address
$PrivateIP = Get-PrivateIPAddress

if (-not $PrivateIP) {
    Write-Host "Error: Unable to retrieve private IP address." -ForegroundColor Red
    exit 1
}

Write-Host "Private IP address detected: $PrivateIP" -ForegroundColor Cyan

# Get the reverse zone name (e.g., 1.31.172.in-addr.arpa)
$ReverseZone = Get-ReverseZoneName -ipAddress $PrivateIP

# Calculate the NetworkId (e.g., 172.31.1.0/24)
$octets = $PrivateIP -split '\.'
$NetworkId = "$($octets[0]).$($octets[1]).$($octets[2]).0/24"

# Create reverse lookup zone if not exists
Create-ReverseLookupZone -ReverseZone $ReverseZone -NetworkId $NetworkId

# Wait briefly to ensure DNS server update
Start-Sleep -Seconds 20

# Manage A and PTR records
Manage-DnsRecords -PrivateIP $PrivateIP -ReverseZone $ReverseZone
