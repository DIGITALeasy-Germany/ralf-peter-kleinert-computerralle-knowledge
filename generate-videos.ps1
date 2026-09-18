param(
    [Parameter(Mandatory = $true)]
    [string]$PythonPath,

    [Parameter(Mandatory = $true)]
    [string]$YtDlpPath
)

$ErrorActionPreference = 'Stop'
$env:PYTHONPATH = $YtDlpPath

$videoUrl = 'https://www.youtube.com/@ComputerRalle/videos'
$shortsUrl = 'https://www.youtube.com/@ComputerRalle/shorts'
$channelUrl = 'https://www.youtube.com/@ComputerRalle'
$channelId = 'UCH2BXSlcm69j6BhoKplYkaQ'
$personId = 'https://knowledge.ralf-peter-kleinert.de/#ralf-peter-kleinert'

function Get-FlatPlaylist([string]$Url) {
    $raw = & $PythonPath -m yt_dlp --flat-playlist --dump-single-json --no-warnings $Url
    if ($LASTEXITCODE -ne 0) { throw "Kanalliste konnte nicht gelesen werden: $Url" }
    return ($raw | ConvertFrom-Json)
}

function Convert-ToIsoDuration([double]$Seconds) {
    $total = [int][Math]::Round($Seconds)
    $hours = [Math]::Floor($total / 3600)
    $minutes = [Math]::Floor(($total % 3600) / 60)
    $secondsPart = $total % 60
    $value = 'PT'
    if ($hours -gt 0) { $value += "${hours}H" }
    if ($minutes -gt 0) { $value += "${minutes}M" }
    if (($secondsPart -gt 0) -or ($value -eq 'PT')) { $value += "${secondsPart}S" }
    return $value
}

$videosFlat = Get-FlatPlaylist $videoUrl
$shortsFlat = Get-FlatPlaylist $shortsUrl
$shortIds = @{}
foreach ($entry in $shortsFlat.entries) { $shortIds[$entry.id] = $true }

$rawItems = & $PythonPath -m yt_dlp --skip-download --dump-json --ignore-errors --no-warnings $videoUrl $shortsUrl
if ($LASTEXITCODE -ne 0) { throw 'Ein oder mehrere YouTube-Metadaten konnten nicht gelesen werden.' }

$byId = [ordered]@{}
foreach ($line in $rawItems) {
    if ([string]::IsNullOrWhiteSpace($line)) { continue }
    $source = $line | ConvertFrom-Json
    if ([string]::IsNullOrWhiteSpace($source.id)) { continue }

    $video = [ordered]@{
        '@type' = 'VideoObject'
        '@id' = "https://knowledge.ralf-peter-kleinert.de/videos/$($source.id)"
        'identifier' = $source.id
        'name' = $source.title
        'url' = "https://www.youtube.com/watch?v=$($source.id)"
        'embedUrl' = "https://www.youtube.com/embed/$($source.id)"
        'thumbnailUrl' = @("https://i.ytimg.com/vi/$($source.id)/hqdefault.jpg")
        'creator' = [ordered]@{
            '@type' = 'Person'
            '@id' = $personId
            'name' = 'Ralf-Peter Kleinert'
            'alternateName' = 'ComputerRalle'
        }
        'publisher' = [ordered]@{
            '@type' = 'Organization'
            'name' = 'YouTube'
            'url' = 'https://www.youtube.com/'
        }
        'inLanguage' = 'de'
        'isFamilyFriendly' = $true
    }

    if (-not [string]::IsNullOrWhiteSpace($source.description)) {
        $video['description'] = $source.description.Trim()
    } elseif ($shortIds.ContainsKey($source.id)) {
        $video['description'] = "YouTube-Short von Ralf-Peter Kleinert / ComputerRalle: $($source.title)"
    } else {
        $video['description'] = "YouTube-Video von Ralf-Peter Kleinert / ComputerRalle: $($source.title)"
    }
    if (-not [string]::IsNullOrWhiteSpace($source.upload_date) -and $source.upload_date.Length -eq 8) {
        $video['uploadDate'] = "$( $source.upload_date.Substring(0,4) )-$( $source.upload_date.Substring(4,2) )-$( $source.upload_date.Substring(6,2) )"
    }
    if ($null -ne $source.duration) {
        $video['duration'] = Convert-ToIsoDuration ([double]$source.duration)
    }
    if ($null -ne $source.tags -and @($source.tags).Count -gt 0) {
        $video['keywords'] = @($source.tags)
    }
    $genres = @()
    if ($null -ne $source.categories -and @($source.categories).Count -gt 0) {
        $genres += @($source.categories)
    }
    if ($shortIds.ContainsKey($source.id)) {
        $genres += 'Short-form video'
    }
    if ($genres.Count -gt 0) {
        $video['genre'] = @($genres | Select-Object -Unique)
    }

    $stats = @()
    if ($null -ne $source.view_count) {
        $stats += [ordered]@{
            '@type' = 'InteractionCounter'
            'interactionType' = [ordered]@{ '@type' = 'WatchAction' }
            'userInteractionCount' = [long]$source.view_count
        }
    }
    if ($null -ne $source.like_count) {
        $stats += [ordered]@{
            '@type' = 'InteractionCounter'
            'interactionType' = [ordered]@{ '@type' = 'LikeAction' }
            'userInteractionCount' = [long]$source.like_count
        }
    }
    if ($null -ne $source.comment_count) {
        $stats += [ordered]@{
            '@type' = 'InteractionCounter'
            'interactionType' = [ordered]@{ '@type' = 'CommentAction' }
            'userInteractionCount' = [long]$source.comment_count
        }
    }
    if ($stats.Count -gt 0) { $video['interactionStatistic'] = $stats }

    $byId[$source.id] = $video
}

$orderedIds = @($videosFlat.entries | ForEach-Object id) + @($shortsFlat.entries | ForEach-Object id)
$listItems = @()
$position = 1
foreach ($id in $orderedIds) {
    if (-not $byId.Contains($id)) { continue }
    $listItems += [ordered]@{
        '@type' = 'ListItem'
        'position' = $position
        'item' = $byId[$id]
    }
    $position++
}

$document = [ordered]@{
    '@context' = 'https://schema.org'
    '@id' = 'https://knowledge.ralf-peter-kleinert.de/videos.json'
    '@type' = @('ItemList', 'CreativeWork')
    'name' = 'Videos von Ralf-Peter Kleinert / ComputerRalle'
    'description' = ('Maschinenlesbares Verzeichnis der ' + [char]0x00F6 + 'ffentlichen Videos und Shorts des offiziellen YouTube-Kanals ComputerRalle.')
    'url' = 'https://knowledge.ralf-peter-kleinert.de/videos.md'
    'mainEntity' = [ordered]@{
        '@type' = 'ProfilePage'
        '@id' = $channelUrl
        'name' = 'ComputerRalle (Ralf-Peter Kleinert) - YouTube-Kanal'
        'url' = $channelUrl
        'identifier' = $channelId
        'mainEntity' = [ordered]@{
            '@type' = 'Person'
            '@id' = $personId
            'name' = 'Ralf-Peter Kleinert'
            'alternateName' = 'ComputerRalle'
        }
    }
    'dateModified' = (Get-Date).ToString('yyyy-MM-dd')
    'numberOfItems' = $listItems.Count
    'itemListOrder' = 'https://schema.org/ItemListOrderDescending'
    'itemListElement' = $listItems
}

$target = Join-Path $PSScriptRoot 'videos.json'
$json = $document | ConvertTo-Json -Depth 20
[System.IO.File]::WriteAllText($target, $json, [System.Text.UTF8Encoding]::new($false))

$markdown = [System.Text.StringBuilder]::new()
[void]$markdown.AppendLine('# Videos von Ralf-Peter Kleinert / ComputerRalle')
[void]$markdown.AppendLine()
[void]$markdown.AppendLine("Dieses Verzeichnis enth$([char]0x00E4)lt die $([char]0x00F6)ffentlichen Videos und Shorts des offiziellen YouTube-Kanals ComputerRalle. Die maschinenlesbaren Daten stehen in [`videos.json`](https://knowledge.ralf-peter-kleinert.de/videos.json).")
[void]$markdown.AppendLine()
[void]$markdown.AppendLine('- YouTube-Kanal: https://www.youtube.com/@ComputerRalle')
[void]$markdown.AppendLine("- Ver$([char]0x00F6)ffentlichungen: $($listItems.Count)")
[void]$markdown.AppendLine()
[void]$markdown.AppendLine('<!-- /////////////////////////////////////////////////////// -->')
[void]$markdown.AppendLine('<!-- Videos -->')
[void]$markdown.AppendLine('<!-- /////////////////////////////////////////////////////// -->')

foreach ($listItem in $listItems) {
    $video = $listItem.item
    $typeLabel = if (@($video.genre) -contains 'Short-form video') { 'YouTube Short' } else { 'YouTube Video' }
    [void]$markdown.AppendLine()
    [void]$markdown.AppendLine("## $($video.name)")
    [void]$markdown.AppendLine()
    [void]$markdown.AppendLine("- Typ: $typeLabel")
    [void]$markdown.AppendLine("- Upload-Datum: $($video.uploadDate)")
    [void]$markdown.AppendLine("- Dauer: $($video.duration)")
    [void]$markdown.AppendLine("- YouTube: $($video.url)")
    [void]$markdown.AppendLine()
    [void]$markdown.AppendLine('### Beschreibung')
    [void]$markdown.AppendLine()
    foreach ($descriptionLine in ($video.description -split "`r?`n")) {
        [void]$markdown.AppendLine("> $descriptionLine")
    }
}

[void]$markdown.AppendLine()
[void]$markdown.AppendLine('<!--')
[void]$markdown.AppendLine("VORLAGE F$([char]0x00DC)R EIN WEITERES VIDEO - diesen Block kopieren, au$([char]0x00DF)erhalb des")
[void]$markdown.AppendLine("Kommentars einf$([char]0x00FC)gen und alle Platzhalter durch echte Angaben ersetzen.")
[void]$markdown.AppendLine()
[void]$markdown.AppendLine('## [Videotitel]')
[void]$markdown.AppendLine()
[void]$markdown.AppendLine('- Typ: [YouTube Video oder YouTube Short]')
[void]$markdown.AppendLine('- Upload-Datum: [JJJJ-MM-TT]')
[void]$markdown.AppendLine('- Dauer: [ISO-8601, zum Beispiel PT12M30S]')
[void]$markdown.AppendLine('- YouTube: [URL]')
[void]$markdown.AppendLine()
[void]$markdown.AppendLine('### Beschreibung')
[void]$markdown.AppendLine()
[void]$markdown.AppendLine('[Beschreibung]')
[void]$markdown.AppendLine('-->')
[void]$markdown.AppendLine()
[void]$markdown.AppendLine("<!-- Neue Videos oberhalb dieser Zeile einf$([char]0x00FC)gen. -->")

$markdownTarget = Join-Path $PSScriptRoot 'videos.md'
[System.IO.File]::WriteAllText($markdownTarget, $markdown.ToString(), [System.Text.UTF8Encoding]::new($false))

Write-Output "WRITTEN=$target"
Write-Output "WRITTEN=$markdownTarget"
Write-Output "TOTAL=$($listItems.Count)"
Write-Output "VIDEOS=$(@($videosFlat.entries).Count)"
Write-Output "SHORTS=$(@($shortsFlat.entries).Count)"
