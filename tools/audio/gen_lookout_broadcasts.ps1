# Original text, local development speech. No provider jobs or external recordings.
$lookoutRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$lookoutAudioDir = Join-Path $lookoutRoot 'tools/audio/generated/radio_bulletins'
$lookoutData = Get-Content -Raw -Encoding UTF8 (Join-Path $lookoutRoot 'brave-and-cold/data/lookout_broadcasts.json') | ConvertFrom-Json
New-Item -ItemType Directory -Force -Path $lookoutAudioDir | Out-Null
Add-Type -AssemblyName System.Speech
Add-Type -ReferencedAssemblies System.Speech -TypeDefinition @"
using System;
using System.Collections.Generic;
using System.Speech.Synthesis;
public class LookoutWordCue {
 public int Start; public int Count; public double Seconds;
}
public static class LookoutSpeechTiming {
 public static LookoutWordCue[] Render(SpeechSynthesizer voice, string text, string output) {
  var cues = new List<LookoutWordCue>();
  EventHandler<SpeakProgressEventArgs> handler = (sender, e) => {
   lock(cues) cues.Add(new LookoutWordCue { Start=e.CharacterPosition, Count=e.CharacterCount, Seconds=e.AudioPosition.TotalSeconds });
  };
  voice.SpeakProgress += handler;
  try { voice.SetOutputToWaveFile(output, new System.Speech.AudioFormat.SpeechAudioFormatInfo(16000, System.Speech.AudioFormat.AudioBitsPerSample.Sixteen, System.Speech.AudioFormat.AudioChannel.Mono)); voice.Speak(text); voice.SetOutputToNull(); }
  finally { voice.SpeakProgress -= handler; }
  lock(cues) return cues.ToArray();
 }
}
"@
$lookoutVoice = New-Object System.Speech.Synthesis.SpeechSynthesizer
$lookoutInstalled = @($lookoutVoice.GetInstalledVoices() | ForEach-Object { $_.VoiceInfo.Name })
$lookoutRecords = @{}
foreach ($broadcast in $lookoutData.broadcasts) {
 $lookoutName = if ($broadcast.device -eq 'dispatch' -and $lookoutInstalled -contains 'Microsoft Zira Desktop') { 'Microsoft Zira Desktop' } else { 'Microsoft David Desktop' }
 $lookoutVoice.SelectVoice($lookoutName)
 $lookoutVoice.Rate = if ($broadcast.device -eq 'dispatch') { 0 } else { -1 }
 $lookoutWords = [LookoutSpeechTiming]::Render($lookoutVoice, $broadcast.text, (Join-Path $lookoutAudioDir ($broadcast.id + '.wav')))
 $lookoutRecords[$broadcast.id] = @{ voice=$lookoutName; rate=$lookoutVoice.Rate; words=@($lookoutWords) }
}
$lookoutVoice.Dispose()
$lookoutRecords | ConvertTo-Json -Depth 6 | Set-Content -Encoding UTF8 (Join-Path $lookoutAudioDir 'speech_manifest.json')
Write-Output ('SPEECH_GENERATED ' + $lookoutData.broadcasts.Count)
# Run filter_lookout_broadcasts.py next. Only raw inputs are filtered; re-running is safe.
