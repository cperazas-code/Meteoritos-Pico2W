param(
    [string]$ArmBin = (Join-Path $PSScriptRoot '..\bin'),
    [string]$PicotoolDir = (Join-Path $PSScriptRoot '..\picotool')
)
$ErrorActionPreference = 'Stop'
$assembler = Join-Path $ArmBin 'arm-none-eabi-as.exe'
$linker = Join-Path $ArmBin 'arm-none-eabi-ld.exe'
$picotool = Get-ChildItem -LiteralPath $PicotoolDir -Filter picotool.exe -File -Recurse | Select-Object -First 1
if (-not $picotool) { throw 'No se encontró picotool.exe.' }
Push-Location $PSScriptRoot
try {
    New-Item -Path build -ItemType Directory -Force | Out-Null
    & $assembler -mcpu=cortex-m33 -mthumb -I src -o build/meteoritos.o src/main.s
    if ($LASTEXITCODE -ne 0) { throw 'Falló el ensamblado.' }
    & $linker -N -Ttext=0x10000000 -e reset -o build/meteoritos.elf build/meteoritos.o
    if ($LASTEXITCODE -ne 0) { throw 'Falló el enlazado.' }
    & $picotool.FullName uf2 convert build/meteoritos.elf build/meteoritos.uf2 --family rp2350-arm-s
    if ($LASTEXITCODE -ne 0) { throw 'Falló la conversión a UF2.' }
    Get-Item build/meteoritos.uf2
}
finally {
    Pop-Location
}
