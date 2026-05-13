param(
    [string]$Tag = "module_tests",
    [string]$VivadoBin = "D:\Xilinx\Vivado\2024.2\bin"
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
$SimDir = Join-Path $Root "fpga\sim"
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

$tests = @(
    "tb_weight_rom",
    "tb_line_buffer",
    "tb_fc1_layer",
    "tb_fc2_layer",
    "tb_conv1_layer_v5",
    "tb_conv2_layer_v5",
    "tb_backend_v5"
)
$testFiles = $tests | ForEach-Object { Join-Path $SimDir "$_.sv" }

Push-Location $OutDir
try {
    & (Join-Path $VivadoBin "xvlog.bat") -sv @sources @testFiles 2>&1 | Tee-Object -FilePath "cmd_xvlog.out"
    if ($LASTEXITCODE -ne 0) { throw "xvlog failed with exit code $LASTEXITCODE" }

    foreach ($test in $tests) {
        & (Join-Path $VivadoBin "xelab.bat") $test -debug typical -s $test 2>&1 | Tee-Object -FilePath "cmd_xelab_$test.out"
        if ($LASTEXITCODE -ne 0) { throw "xelab failed for $test with exit code $LASTEXITCODE" }

        & (Join-Path $VivadoBin "xsim.bat") $test -runall 2>&1 | Tee-Object -FilePath "xsim_$test.log"
        if ($LASTEXITCODE -ne 0) { throw "xsim failed for $test with exit code $LASTEXITCODE" }

        $logText = Get-Content -LiteralPath "xsim_$test.log" -Raw
        if ($logText -notmatch "TEST_PASS $test") {
            throw "Missing TEST_PASS marker for $test"
        }
    }

    "MODULE_TESTS_PASS tests=$($tests.Count)" | Tee-Object -FilePath "module_tests_summary.log"
}
finally {
    Pop-Location
}
