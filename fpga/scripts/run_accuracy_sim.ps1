param(
    [string]$Tag = "iter0_baseline",
    [string]$VivadoBin = "D:\Xilinx\Vivado\2024.2\bin",
    [string]$DataDir = "D:/IC_Workspace/mnist/fpga/data",
    [int]$NImages = 30,
    [string]$LabelFile = ""
)

$ErrorActionPreference = "Stop"
$Root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$OutDir = Join-Path $Root "fpga\build\$Tag\sim"
if (Test-Path -LiteralPath $OutDir) {
    $resolved = (Resolve-Path -LiteralPath $OutDir).Path
    $buildRoot = (Resolve-Path (Join-Path $Root "fpga\build")).Path
    if (-not $resolved.StartsWith($buildRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to remove outside fpga/build: $resolved"
    }
    Remove-Item -LiteralPath $resolved -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

$SrcDir = Join-Path $Root "fpga\src"
$SimTopSrc = Join-Path $Root "fpga\sim\tb_mnist_top_acc.sv"
$SimTop = Join-Path $OutDir "tb_mnist_top_acc_cfg.sv"
$DataDirForSv = $DataDir.Replace("\", "/")
$tbText = Get-Content -LiteralPath $SimTopSrc -Raw
$tbText = $tbText -replace 'parameter N_IMAGES = \d+;', "parameter N_IMAGES = $NImages;"
$tbText = $tbText -replace 'data_dir = "D:/IC_Workspace/mnist/fpga/data";', "data_dir = `"$DataDirForSv`";"
Set-Content -LiteralPath $SimTop -Value $tbText -Encoding ASCII
$sources = @(
    "weight_rom.sv",
    "line_buffer.sv",
    "conv1_layer_v5.sv",
    "conv2_layer_v5.sv",
    "fc1_layer.sv",
    "fc2_layer.sv",
    "backend_v5.sv",
    "top_mnist.sv"
) | ForEach-Object { Join-Path $SrcDir $_ }

Push-Location $OutDir
try {
    & (Join-Path $VivadoBin "xvlog.bat") -sv @sources $SimTop 2>&1 | Tee-Object -FilePath "cmd_xvlog.out"
    if ($LASTEXITCODE -ne 0) { throw "xvlog failed with exit code $LASTEXITCODE" }

    & (Join-Path $VivadoBin "xelab.bat") tb_mnist_top_acc -debug typical -s $Tag 2>&1 | Tee-Object -FilePath "cmd_xelab.out"
    if ($LASTEXITCODE -ne 0) { throw "xelab failed with exit code $LASTEXITCODE" }

    & (Join-Path $VivadoBin "xsim.bat") $Tag -runall 2>&1 | Tee-Object -FilePath "accuracy.log"
    if ($LASTEXITCODE -ne 0) { throw "xsim failed with exit code $LASTEXITCODE" }
}
finally {
    Pop-Location
}
