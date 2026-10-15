# Creates and links two demo GPOs. Safe to re-run.
# Run on DC01:  .\02-gpo.ps1
#   1. "WS - Logon banner"          -> OU Company\Computers      (computer policy: message before logon)
#   2. "Users - No Control Panel"   -> OU Company\Users\Accounting (user policy: Control Panel blocked)
Import-Module GroupPolicy, ActiveDirectory

$Domain = (Get-ADDomain).DistinguishedName
$Gpos = @(
    @{ Name   = "WS - Logon banner"
       Target = "OU=Computers,OU=Company,$Domain"
       Values = @(
           @{ Key = "HKLM\Software\Microsoft\Windows\CurrentVersion\Policies\System"; Name = "legalnoticecaption"; Type = "String"; Value = "CORP.LAB" },
           @{ Key = "HKLM\Software\Microsoft\Windows\CurrentVersion\Policies\System"; Name = "legalnoticetext";    Type = "String"; Value = "Доступ только для сотрудников. Действия в системе журналируются." }
       ) },
    @{ Name   = "Users - No Control Panel"
       Target = "OU=Accounting,OU=Users,OU=Company,$Domain"
       Values = @(
           @{ Key = "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer"; Name = "NoControlPanel"; Type = "DWord"; Value = 1 }
       ) }
)

foreach ($g in $Gpos) {
    if (-not (Get-GPO -Name $g.Name -ErrorAction SilentlyContinue)) {
        New-GPO -Name $g.Name | Out-Null
        Write-Host "GPO created: $($g.Name)"
    }
    foreach ($v in $g.Values) {
        Set-GPRegistryValue -Name $g.Name -Key $v.Key -ValueName $v.Name -Type $v.Type -Value $v.Value | Out-Null
    }
    $linked = (Get-GPInheritance -Target $g.Target).GpoLinks | Where-Object DisplayName -eq $g.Name
    if (-not $linked) {
        New-GPLink -Name $g.Name -Target $g.Target | Out-Null
        Write-Host "GPO linked: $($g.Name) -> $($g.Target)"
    }
}

Get-GPO -All | Format-Table DisplayName, GpoStatus, ModificationTime -AutoSize
