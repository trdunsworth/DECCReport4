param(
  [string]$Workspace = "c:\Users\tony.dunsworth\projects\DECCReport4"
)

$ErrorActionPreference = 'Stop'

$qmdPath = Join-Path $Workspace "test_file.qmd"
$ipynbPath = Join-Path $Workspace "test_jupyter.ipynb"
$marimoPath = Join-Path $Workspace "test_marimo.py"

if (-not (Test-Path $qmdPath)) {
  throw "Source file not found: $qmdPath"
}

$lines = Get-Content -Path $qmdPath

# Skip YAML frontmatter when present.
$start = 0
if ($lines.Count -gt 1 -and $lines[0].Trim() -eq '---') {
  for ($i = 1; $i -lt $lines.Count; $i++) {
    if ($lines[$i].Trim() -eq '---') {
      $start = $i + 1
      break
    }
  }
}

$cells = New-Object System.Collections.Generic.List[object]
$md = New-Object System.Collections.Generic.List[string]
$code = New-Object System.Collections.Generic.List[string]
$inCode = $false

function Trim-BlankEdges {
  param([string[]]$arr)
  $list = New-Object System.Collections.Generic.List[string]
  foreach ($x in $arr) { $list.Add($x) }

  while ($list.Count -gt 0 -and [string]::IsNullOrWhiteSpace($list[0])) {
    $list.RemoveAt(0)
  }
  while ($list.Count -gt 0 -and [string]::IsNullOrWhiteSpace($list[$list.Count - 1])) {
    $list.RemoveAt($list.Count - 1)
  }
  return ,$list.ToArray()
}

function To-SourceLines {
  param([string[]]$arr)
  $out = New-Object System.Collections.Generic.List[string]
  for ($j = 0; $j -lt $arr.Count; $j++) {
    if ($j -lt $arr.Count - 1) { $out.Add($arr[$j] + "`n") }
    else { $out.Add($arr[$j]) }
  }
  return ,$out.ToArray()
}

function Add-MarkdownCell {
  param([string[]]$content)
  $trimmed = Trim-BlankEdges $content
  if ($trimmed.Count -eq 0) { return }

  $cell = [ordered]@{
    cell_type = "markdown"
    metadata = [ordered]@{ language = "markdown" }
    source = (To-SourceLines $trimmed)
  }
  $script:cells.Add($cell)
}

function Add-CodeCell {
  param([string[]]$content)
  $trimmed = Trim-BlankEdges $content
  if ($trimmed.Count -eq 0) { return }

  $cell = [ordered]@{
    cell_type = "code"
    execution_count = $null
    metadata = [ordered]@{ language = "r" }
    outputs = @()
    source = (To-SourceLines $trimmed)
  }
  $script:cells.Add($cell)
}

for ($i = $start; $i -lt $lines.Count; $i++) {
  $line = $lines[$i]

  if (-not $inCode) {
    if ($line -match '^```\{r.*\}\s*$') {
      Add-MarkdownCell $md.ToArray()
      $md.Clear()
      $inCode = $true
      continue
    }
    $md.Add($line)
  } else {
    if ($line.Trim() -eq '```') {
      Add-CodeCell $code.ToArray()
      $code.Clear()
      $inCode = $false
      continue
    }
    $code.Add($line)
  }
}

if ($md.Count -gt 0) { Add-MarkdownCell $md.ToArray() }
if ($code.Count -gt 0) { Add-CodeCell $code.ToArray() }

$nb = [ordered]@{
  cells = $cells
  metadata = [ordered]@{
    kernelspec = [ordered]@{
      display_name = "R"
      language = "R"
      name = "ir"
    }
    language_info = [ordered]@{
      name = "R"
      codemirror_mode = "r"
      file_extension = ".r"
      mimetype = "text/r"
    }
  }
  nbformat = 4
  nbformat_minor = 5
}

$nbJson = $nb | ConvertTo-Json -Depth 100
Set-Content -Path $ipynbPath -Value $nbJson -Encoding UTF8

$py = New-Object System.Text.StringBuilder
[void]$py.AppendLine('import marimo')
[void]$py.AppendLine('')
[void]$py.AppendLine('__generated_with = "0.11.20"')
[void]$py.AppendLine('app = marimo.App()')
[void]$py.AppendLine('')
[void]$py.AppendLine('@app.cell')
[void]$py.AppendLine('def __(mo):')
[void]$py.AppendLine('    mo.md("""# DECC Weekly Report')
[void]$py.AppendLine('')
[void]$py.AppendLine('Converted from test_file.qmd for presentation.  ')
[void]$py.AppendLine('R chunks are preserved as rendered code blocks.""")')
[void]$py.AppendLine('    return')
[void]$py.AppendLine('')

foreach ($c in $cells) {
  if ($c.cell_type -eq 'markdown') {
    $text = ($c.source -join '') -replace '"""', '\"\"\"'
    [void]$py.AppendLine('@app.cell')
    [void]$py.AppendLine('def __(mo):')
    [void]$py.AppendLine('    mo.md("""' + $text + '""")')
    [void]$py.AppendLine('    return')
    [void]$py.AppendLine('')
  } else {
    $text = ($c.source -join '') -replace '"""', '\"\"\"'
    [void]$py.AppendLine('@app.cell')
    [void]$py.AppendLine('def __(mo):')
    [void]$py.AppendLine('    mo.md("""```r')
    [void]$py.AppendLine($text)
    [void]$py.AppendLine('```""")')
    [void]$py.AppendLine('    return')
    [void]$py.AppendLine('')
  }
}

[void]$py.AppendLine('if __name__ == "__main__":')
[void]$py.AppendLine('    app.run()')

Set-Content -Path $marimoPath -Value $py.ToString() -Encoding UTF8

Write-Output ("Converted: " + $cells.Count + " cells")
