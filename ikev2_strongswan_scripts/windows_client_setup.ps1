$Name = "Yura VPN"
$Server = "vpn.yuramishin.ru"

Remove-VpnConnection -Name $Name -Force -ErrorAction SilentlyContinue
Remove-VpnConnection -Name $Name -AllUserConnection -Force -ErrorAction SilentlyContinue

Add-VpnConnection `
  -Name $Name `
  -ServerAddress $Server `
  -TunnelType IKEv2 `
  -AuthenticationMethod EAP `
  -EncryptionLevel Maximum `
  -RememberCredential `
  -Force

Set-VpnConnectionIPsecConfiguration `
  -ConnectionName $Name `
  -AuthenticationTransformConstants SHA256128 `
  -CipherTransformConstants AES256 `
  -EncryptionMethod AES256 `
  -IntegrityCheckMethod SHA256 `
  -PfsGroup PFS2048 `
  -DHGroup Group14 `
  -Force `
  -PassThru

Write-Host "Created VPN profile: $Name"
Write-Host "Connect with: rasphone -d `"$Name`""
