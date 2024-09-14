# Variables
$domainName = "minjtech.xyz"          # Replace with your domain name
$ouPath = "OU=Servers,DC=minjtech,DC=xyz"  # Replace with your specific OU path
$domainUser = "DomainAdminUser"       # Replace with domain admin username
$password = ConvertTo-SecureString "YourPassword" -AsPlainText -Force  # Replace with domain admin password

# Create credential object
$credential = New-Object System.Management.Automation.PSCredential($domainUser, $password)

# Join the computer to the domain and specify the OU path
Add-Computer -DomainName $domainName -Credential $credential -OUPath $ouPath -Restart -Force
