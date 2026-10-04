# Local Windows development speech. Original script; replace with directed performances later.
$lookoutRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$lookoutAudioDir = Join-Path $lookoutRoot 'brave-and-cold/assets/audio/radio_opening'
$lookoutData = Get-Content -Raw -Encoding UTF8 (Join-Path $lookoutRoot 'brave-and-cold/data/lookout_broadcasts.json') | ConvertFrom-Json
New-Item -ItemType Directory -Force -Path $lookoutAudioDir | Out-Null
Add-Type -AssemblyName System.Speech
$lookoutVoice = New-Object System.Speech.Synthesis.SpeechSynthesizer
$lookoutVoice.SelectVoice('Microsoft David Desktop')
$lookoutVoice.Rate = -1
foreach ($broadcast in $lookoutData.broadcasts) {
 $lookoutVoice.SetOutputToWaveFile((Join-Path $lookoutAudioDir ($broadcast.id + '.wav')))
 $lookoutVoice.Speak($broadcast.text)
 $lookoutVoice.SetOutputToNull()
}
$lookoutVoice.Dispose()
# Run filter_lookout_broadcasts.py with the project's Python environment after synthesis.
