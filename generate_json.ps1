<#
.SYNOPSIS
    Updates the images array in molecules.json based on files in the assets folder.
#>

# --- Configuration ---
$ScriptRoot = $PSScriptRoot
$AssetsBaseDir = Join-Path $ScriptRoot "assets"
$JsonFilePath = Join-Path $ScriptRoot "molecules.json"

# --- Main Script ---
Write-Host "Starting Image Path Update..." -ForegroundColor Cyan

# 1. Check if JSON file exists
if (-not (Test-Path $JsonFilePath)) {
    Write-Error "Could not find molecules.json at: $JsonFilePath"
    exit 1
}

# 2. Check if assets directory exists
if (-not (Test-Path $AssetsBaseDir)) {
    Write-Error "Assets directory not found at: $AssetsBaseDir"
    exit 1
}

# 3. Load and Parse JSON
Write-Host "Reading JSON file..." -ForegroundColor Yellow
try {
    $rawJson = Get-Content -Path $JsonFilePath -Raw -ErrorAction Stop
    $jsonContent = $rawJson | ConvertFrom-Json
    Write-Host "JSON parsed successfully!" -ForegroundColor Green
}
catch {
    Write-Error "Failed to parse JSON: $_"
    exit 1
}

# 4. Determine JSON Structure (Array vs Object with 'value')
if ($jsonContent -is [Array]) {
    $molecules = $jsonContent
}
elseif ($jsonContent.PSObject.Properties.Match('value').Count) {
    $molecules = $jsonContent.value
}
else {
    Write-Error "JSON structure invalid. Must be an array or object with 'value' property."
    exit 1
}

Write-Host "Total molecules to process: $($molecules.Count)" -ForegroundColor Cyan

# 5. Process molecules
$updatedCount = 0
$missingCount = 0
$unchangedCount = 0

foreach ($molecule in $molecules) {
    $moleculeName = $molecule.name
    $packName = $molecule.pack
    
    $moleculePath = Join-Path $AssetsBaseDir $packName
    $moleculePath = Join-Path $moleculePath $moleculeName
    
    if (-not (Test-Path $moleculePath)) {
        Write-Host "  [WARNING] Folder not found: $packName/$moleculeName" -ForegroundColor Yellow
        $missingCount++
        continue
    }
    
    # Find images
    $imageFiles = Get-ChildItem -Path $moleculePath -File | 
                  Where-Object { $_.Extension -match '^\.(jpg|jpeg)$' } |
                  Sort-Object Name
    
    # Build new paths
    $newImagePaths = @()
    foreach ($img in $imageFiles) {
        $newImagePaths += "assets/$packName/$moleculeName/$($img.Name)"
    }
    
    # Compare
    $oldImagesStr = ($molecule.images | Sort-Object) -join "|"
    $newImagesStr = ($newImagePaths | Sort-Object) -join "|"
    
    if ($oldImagesStr -ne $newImagesStr) {
        $molecule.images = $newImagePaths
        $updatedCount++
    }
    else {
        $unchangedCount++
    }
}

# 6. Save and Exit
Write-Host "`nSummary:" -ForegroundColor Cyan
Write-Host "  Updated:   $updatedCount" -ForegroundColor Green
Write-Host "  Unchanged: $unchangedCount" -ForegroundColor Gray
Write-Host "  Missing:   $missingCount" -ForegroundColor Yellow

if ($updatedCount -gt 0) {
    Write-Host "Saving changes to molecules.json..." -ForegroundColor Yellow
    try {
        $jsonString = $jsonContent | ConvertTo-Json -Depth 10
        $jsonString | Out-File -FilePath $JsonFilePath -Encoding UTF8 -Force
        Write-Host "[SUCCESS] File saved." -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to save file: $_"
        exit 1
    }
} else {
    Write-Host "[INFO] No changes needed." -ForegroundColor Cyan
}

Write-Host "[DONE]" -ForegroundColor Green
# Explicitly exit with success code to satisfy GitHub Actions
exit 0