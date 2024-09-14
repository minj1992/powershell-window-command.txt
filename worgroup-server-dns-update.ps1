# Define your custom DNS server IP
$dnsServerIP = "172.31.1.203"  # Replace with your DNS server IP

# Get the network adapter (you can modify the InterfaceAlias if needed)
$adapter = Get-NetAdapter | Select-Object -ExpandProperty Name

# Check if the adapter is found
if ($adapter) {
    Write-Host "Setting DNS server to $dnsServerIP for adapter $adapter..."
    
    # Set the DNS server to your custom DNS IP for this adapter
    Set-DnsClientServerAddress -InterfaceAlias $adapter -ServerAddresses $dnsServerIP
    
    # Verify and display the updated DNS settings
    $dnsSettings = Get-DnsClientServerAddress -InterfaceAlias $adapter
    Write-Host "DNS settings updated successfully for adapter $adapter"
    $dnsSettings | Format-Table -AutoSize
} else {
    Write-Error "No network adapter found."
}

