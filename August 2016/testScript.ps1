param(
    [string] $reboot
)

if ($reboot -eq "test") {
    Write-Output "1"
} else {
    Write-Output "0"
}