# Define domain name
$domainName = "minjtech.xyz"

# Specify domain credentials (avoid hardcoding password directly)
$domainUsername = "your_domain_admin_username"
$domainPassword = "your_secure_password" | ConvertTo-SecureString -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($domainUsername, $domainPassword)

# Join computer to the domain
Add-Computer -DomainName $domainName -Credential $credential -Restart -Force

# Confirm the domain join status
Write-Host "The server is being joined to the domain $domainName and will restart shortly."
