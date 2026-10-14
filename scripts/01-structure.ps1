# Creates OU structure, groups and users in corp.lab.
# Safe to re-run: existing objects are skipped.
# Run on DC01 as CORP\Administrator:  .\01-structure.ps1
Import-Module ActiveDirectory

$Domain  = (Get-ADDomain).DistinguishedName      # DC=corp,DC=lab
$Root    = "OU=Company,$Domain"
$UsersOU = "OU=Users,$Root"
$Depts   = @("IT", "Accounting")

function New-OUIfMissing($Name, $Path) {
    $dn = "OU=$Name,$Path"
    if (-not (Get-ADOrganizationalUnit -Filter "DistinguishedName -eq '$dn'")) {
        New-ADOrganizationalUnit -Name $Name -Path $Path
        Write-Host "OU created: $dn"
    }
}

# 1. OU tree: Company\{Users\{IT,Accounting}, Computers, Groups}
New-OUIfMissing "Company" $Domain
foreach ($ou in "Users", "Computers", "Groups") { New-OUIfMissing $ou $Root }
foreach ($d in $Depts) { New-OUIfMissing $d $UsersOU }

# 2. One global group per department
foreach ($d in $Depts) {
    $g = "GG_$d"
    if (-not (Get-ADGroup -Filter "Name -eq '$g'")) {
        New-ADGroup -Name $g -GroupScope Global -GroupCategory Security -Path "OU=Groups,$Root"
        Write-Host "Group created: $g"
    }
}

# 3. Users from CSV, initial password must be changed at first logon
$Password = Read-Host "Initial password for new users" -AsSecureString
Import-Csv "$PSScriptRoot\users.csv" | ForEach-Object {
    if (Get-ADUser -Filter "SamAccountName -eq '$($_.Sam)'") { return }
    try {
        New-ADUser -SamAccountName $_.Sam `
            -UserPrincipalName "$($_.Sam)@corp.lab" `
            -Name "$($_.GivenName) $($_.Surname)" `
            -GivenName $_.GivenName -Surname $_.Surname `
            -Department $_.Department `
            -Path "OU=$($_.Department),$UsersOU" `
            -AccountPassword $Password -ChangePasswordAtLogon $true -Enabled $true `
            -ErrorAction Stop
        Add-ADGroupMember -Identity "GG_$($_.Department)" -Members $_.Sam -ErrorAction Stop
        Write-Host "User created: $($_.Sam) -> GG_$($_.Department)"
    } catch {
        Write-Warning "FAILED $($_.Exception.Message)"
        $script:Failed = $true
    }
}

# 4. New computers joining the domain land in Company\Computers instead of the default container
redircmp "OU=Computers,$Root" | Out-Null

# 5. Lockout policy: 5 wrong passwords -> locked for 15 minutes (default is never)
Set-ADDefaultDomainPasswordPolicy -Identity (Get-ADDomain).DNSRoot `
    -LockoutThreshold 5 -LockoutDuration 00:15:00 -LockoutObservationWindow 00:15:00

if ($script:Failed) { Write-Warning "Finished with errors, see above."; exit 1 }
Write-Host "`nDone."
