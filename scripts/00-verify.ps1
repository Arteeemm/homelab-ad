# Collects the state of the lab domain into a text report.
# Run on DC01:  .\00-verify.ps1   ->  ..\docs\verify-dc.txt
Import-Module ActiveDirectory

$Out = Join-Path $PSScriptRoot "..\docs\verify-dc.txt"
New-Item -ItemType Directory -Force -Path (Split-Path $Out) | Out-Null
$Base = "OU=Company," + (Get-ADDomain).DistinguishedName

function Section($Title, [scriptblock]$Body) {
    "`n===== $Title =====" | Out-File $Out -Append -Encoding utf8
    & $Body | Out-String -Width 200 | Out-File $Out -Append -Encoding utf8
}

"homelab-ad verification, $(Get-Date -Format 'yyyy-MM-dd HH:mm')" | Out-File $Out -Encoding utf8

Section "Domain" { Get-ADDomain | Select-Object DNSRoot, NetBIOSName, PDCEmulator }
Section "DC services" { Get-Service NTDS, DNS, KDC, Netlogon | Format-Table Name, Status -AutoSize }
Section "SYSVOL / NETLOGON shares" { Get-SmbShare | Where-Object Name -in "SYSVOL","NETLOGON" | Format-Table Name, Path -AutoSize }
Section "DNS: SRV record for domain controllers" { Resolve-DnsName -Type SRV "_ldap._tcp.dc._msdcs.$((Get-ADDomain).DNSRoot)" | Where-Object Type -eq SRV | Format-Table Name, NameTarget, Port -AutoSize }
Section "OU tree" { Get-ADOrganizationalUnit -Filter * | Sort-Object DistinguishedName | Select-Object -ExpandProperty DistinguishedName }
Section "Users" { Get-ADUser -Filter * -SearchBase $Base -Properties Department | Format-Table SamAccountName, Department, Enabled -AutoSize }
Section "Groups and members" {
    Get-ADGroup -Filter "Name -like 'GG_*'" | ForEach-Object {
        "$($_.Name): " + ((Get-ADGroupMember $_ | Select-Object -ExpandProperty SamAccountName) -join ", ")
    }
}
Section "Computers" { Get-ADComputer -Filter * | Format-Table Name, DistinguishedName -AutoSize }
Section "Lockout policy" { Get-ADDefaultDomainPasswordPolicy | Format-List LockoutThreshold, LockoutDuration, MinPasswordLength, ComplexityEnabled }

Write-Host "Report saved: $Out"
