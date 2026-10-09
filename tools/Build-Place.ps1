# ============================================================================
#  Build-Place.ps1
#
#  Genera "HowToVape.rbxlx": un place listo para abrir en Roblox Studio con
#  TODOS los scripts de src/ ya colocados en su servicio correspondiente, mas
#  una baseplate para no caerse del mapa. No necesita Rojo ni Rokit.
#
#  Uso, desde la raiz del proyecto:
#      powershell -ExecutionPolicy Bypass -File tools\Build-Place.ps1
#
#  El recorrido se hace leyendo default.project.json, respetando el $className
#  que declare cada nodo. Esto importa: "StarterPlayerScripts" NO es una carpeta
#  normal, es una clase propia, y los LocalScripts metidos en un Folder con ese
#  nombre no se ejecutarian.
#
#  OJO: esto es una FOTO. Si editas src/ despues, vuelve a ejecutarlo (o usa
#  "rojo serve", que es el flujo recomendado y mantiene el place vivo).
# ============================================================================

[CmdletBinding()]
param(
    [string]$Output = "HowToVape.rbxlx"
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$root = Split-Path -Parent $scriptDir
$outPath = Join-Path $root $Output

$project = Get-Content -Raw -LiteralPath (Join-Path $root "default.project.json") | ConvertFrom-Json
$tree = $project.tree

# --- Documento XML ----------------------------------------------------------
$doc = New-Object System.Xml.XmlDocument
$decl = $doc.CreateXmlDeclaration("1.0", "utf-8", $null)
$doc.AppendChild($decl) | Out-Null

$rootEl = $doc.CreateElement("roblox")
$rootEl.SetAttribute("xmlns:xmime", "http://www.w3.org/2005/05/xmlmime")
$rootEl.SetAttribute("xmlns:xsi", "http://www.w3.org/2001/XMLSchema-instance")
# OJO: hay que crear el atributo con prefijo + namespace explicitos. Un
# SetAttribute("xsi:...", valor) cae en la sobrecarga (localName, namespaceURI)
# de .NET y pierde el prefijo "xsi:".
$schemaAttr = $doc.CreateAttribute("xsi", "noNamespaceSchemaLocation", "http://www.w3.org/2001/XMLSchema-instance")
$schemaAttr.Value = "http://www.roblox.com/roblox.xsd"
$rootEl.Attributes.Append($schemaAttr) | Out-Null
$rootEl.SetAttribute("version", "4")
$doc.AppendChild($rootEl) | Out-Null

foreach ($ext in @("null", "nil")) {
    $e = $doc.CreateElement("External")
    $e.AppendChild($doc.CreateTextNode($ext)) | Out-Null
    $rootEl.AppendChild($e) | Out-Null
}

$script:ref = 0
$script:scriptCount = 0
$script:log = New-Object System.Collections.ArrayList

# --- Helpers XML ------------------------------------------------------------
function New-ItemEl([string]$class) {
    $el = $doc.CreateElement("Item")
    $el.SetAttribute("class", $class)
    $el.SetAttribute("referent", "RBX$($script:ref)")
    $script:ref++
    return $el
}

function Get-Props($item) {
    $p = $item.SelectSingleNode("Properties")
    if (-not $p) {
        $p = $doc.CreateElement("Properties")
        $item.InsertBefore($p, $item.FirstChild) | Out-Null
    }
    return $p
}

function Set-Str($item, [string]$name, [string]$value) {
    $e = $doc.CreateElement("string"); $e.SetAttribute("name", $name)
    $e.AppendChild($doc.CreateTextNode($value)) | Out-Null
    (Get-Props $item).AppendChild($e) | Out-Null
}
function Set-Bool($item, [string]$name, [bool]$value) {
    $e = $doc.CreateElement("bool"); $e.SetAttribute("name", $name)
    $e.AppendChild($doc.CreateTextNode($(if ($value) { "true" } else { "false" }))) | Out-Null
    (Get-Props $item).AppendChild($e) | Out-Null
}
function Set-Source($item, [string]$source) {
    $e = $doc.CreateElement("ProtectedString"); $e.SetAttribute("name", "Source")
    $e.AppendChild($doc.CreateTextNode($source)) | Out-Null
    (Get-Props $item).AppendChild($e) | Out-Null
}
function Set-Vec3($item, [string]$name, $x, $y, $z) {
    $e = $doc.CreateElement("Vector3"); $e.SetAttribute("name", $name)
    foreach ($kv in @(@("X", $x), @("Y", $y), @("Z", $z))) {
        $c = $doc.CreateElement($kv[0])
        $c.AppendChild($doc.CreateTextNode([string]$kv[1])) | Out-Null
        $e.AppendChild($c) | Out-Null
    }
    (Get-Props $item).AppendChild($e) | Out-Null
}
function Set-CFrame($item, [string]$name, $x, $y, $z) {
    $e = $doc.CreateElement("CoordinateFrame"); $e.SetAttribute("name", $name)
    foreach ($kv in @(@("X", $x), @("Y", $y), @("Z", $z))) {
        $c = $doc.CreateElement($kv[0])
        $c.AppendChild($doc.CreateTextNode([string]$kv[1])) | Out-Null
        $e.AppendChild($c) | Out-Null
    }
    foreach ($kv in @(@("R00", 1), @("R01", 0), @("R02", 0), @("R10", 0), @("R11", 1),
                      @("R12", 0), @("R20", 0), @("R21", 0), @("R22", 1))) {
        $c = $doc.CreateElement($kv[0])
        $c.AppendChild($doc.CreateTextNode([string]$kv[1])) | Out-Null
        $e.AppendChild($c) | Out-Null
    }
    (Get-Props $item).AppendChild($e) | Out-Null
}

# --- Helpers de arbol -------------------------------------------------------
function Find-ClassChild($parent, [string]$class) {
    foreach ($child in $parent.SelectNodes("Item")) {
        if ($child.GetAttribute("class") -eq $class) { return $child }
    }
    return $null
}

function Get-Service([string]$class) {
    $existing = Find-ClassChild $rootEl $class
    if ($existing) { return $existing }
    $el = New-ItemEl $class
    Set-Str $el "Name" $class
    $rootEl.AppendChild($el) | Out-Null
    return $el
}

function Get-ScriptClass([string]$fileName) {
    if ($fileName -match "\.server\.(luau|lua)$") { return @{ Class = "Script";      Name = $fileName -replace "\.server\.(luau|lua)$", "" } }
    if ($fileName -match "\.client\.(luau|lua)$") { return @{ Class = "LocalScript"; Name = $fileName -replace "\.client\.(luau|lua)$", "" } }
    return @{ Class = "ModuleScript"; Name = $fileName -replace "\.(luau|lua)$", "" }
}

function Add-ScriptsFrom([string]$dir, $parent, [string]$indent) {
    foreach ($sub in (Get-ChildItem -LiteralPath $dir -Directory | Sort-Object Name)) {
        $folder = New-ItemEl "Folder"
        Set-Str $folder "Name" $sub.Name
        $parent.AppendChild($folder) | Out-Null
        [void]$script:log.Add("$indent  [Folder] $($sub.Name)")
        Add-ScriptsFrom $sub.FullName $folder "$indent  "
    }
    foreach ($file in (Get-ChildItem -LiteralPath $dir -File | Sort-Object Name)) {
        if ($file.Extension -notin @(".luau", ".lua")) { continue }
        $info = Get-ScriptClass $file.Name
        # UTF-8 explicito: sin esto, los acentos de los comentarios se rompen.
        $src = [System.IO.File]::ReadAllText($file.FullName, [System.Text.Encoding]::UTF8)
        $el = New-ItemEl $info.Class
        Set-Str $el "Name" $info.Name
        Set-Source $el $src
        $parent.AppendChild($el) | Out-Null
        $script:scriptCount++
        [void]$script:log.Add("$indent  [$($info.Class)] $($info.Name)")
    }
}

# Recorre un nodo del proyecto Rojo respetando su $className.
function Add-Node($elem, $node, [string]$name, [string]$indent) {
    $class = $node.'$className'
    if (-not $class) { $class = "Folder" }   # nodo sin clase explicita = carpeta
    $el = New-ItemEl $class
    Set-Str $el "Name" $name
    $elem.AppendChild($el) | Out-Null
    [void]$script:log.Add("$indent[$class] $name")

    if ($node.'$path') {
        $dir = Join-Path $root $node.'$path'
        if (Test-Path -LiteralPath $dir) {
            Add-ScriptsFrom $dir $el "$indent  "
        } else {
            Write-Warning "No existe la carpeta del proyecto: $dir"
        }
    }

    foreach ($child in $node.PSObject.Properties) {
        if ($child.Name.StartsWith('$')) { continue }
        Add-Node $el $child.Value $child.Name "$indent  "
    }
}

# --- Construir el contenido -------------------------------------------------
foreach ($child in $tree.PSObject.Properties) {
    if ($child.Name.StartsWith('$')) { continue }
    Add-Node $rootEl $child.Value $child.Name ""
}

# Baseplate, por si el jugador se sale de la plaza.
$workspace = Get-Service "Workspace"
$plate = New-ItemEl "Part"
Set-Str $plate "Name" "Baseplate"
Set-Bool $plate "Anchored" $true
Set-Bool $plate "Locked" $true
Set-Vec3 $plate "size" 512 20 512
Set-CFrame $plate "CFrame" 0 -10.5 0
$workspace.AppendChild($plate) | Out-Null

# --- Escribir ---------------------------------------------------------------
$settings = New-Object System.Xml.XmlWriterSettings
$settings.Encoding = New-Object System.Text.UTF8Encoding($false)
$settings.Indent = $true
$settings.IndentChars = "`t"
$writer = [System.Xml.XmlWriter]::Create($outPath, $settings)
$doc.Save($writer)
$writer.Close()

Write-Host ""
Write-Host "=== Contenido del place ==="
foreach ($line in $script:log) { Write-Host "  $line" }
Write-Host ""
Write-Host "Place generado: $outPath"
Write-Host "  $($script:scriptCount) scripts insertados"
Write-Host ""
Write-Host "Siguiente paso: abre ese .rbxlx en Roblox Studio y pulsa Play."
