param(
  [Parameter(Mandatory = $true)]
  [string]$SignalBase,
  [Parameter(Mandatory = $true)]
  [ValidateRange(0, 100)]
  [int]$Volume
)

$ErrorActionPreference = 'Stop'

$readyPath = "$SignalBase.ready"
$donePath = "$SignalBase.done"
$restoredPath = "$SignalBase.restored"
$errorPath = "$SignalBase.error"
$endpoint = $null
$originalVolume = 0.0
$originalMute = $false
$mustRestore = $false
$parentProcessId = 0

try {
  $helperProcess = Get-WmiObject Win32_Process -Filter "ProcessId=$PID"
  if (-not $helperProcess) {
    throw 'No se pudo identificar el proceso de Mini Voice.'
  }
  $parentProcessId = [int]$helperProcess.ParentProcessId

  Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

[ComImport]
[Guid("BCDE0395-E52F-467C-8E3D-C4579291692E")]
internal class MiniVoiceDeviceEnumerator { }

[ComImport]
[Guid("A95664D2-9614-4F35-A746-DE8DB63617E6")]
[InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
public interface IMiniVoiceDeviceEnumerator {
  [PreserveSig]
  int EnumAudioEndpoints(int dataFlow, int stateMask, out IntPtr devices);
  [PreserveSig]
  int GetDefaultAudioEndpoint(int dataFlow, int role, out IMiniVoiceDevice device);
}

[ComImport]
[Guid("D666063F-1587-4E43-81F1-B948E807363F")]
[InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
public interface IMiniVoiceDevice {
  [PreserveSig]
  int Activate(ref Guid interfaceId, int classContext, IntPtr activationParameters, [MarshalAs(UnmanagedType.IUnknown)] out object instance);
}

[ComImport]
[Guid("5CDF2C82-841E-4546-9722-0CF74078229A")]
[InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
public interface IMiniVoiceEndpointVolume {
  [PreserveSig]
  int RegisterControlChangeNotify(IntPtr notify);
  [PreserveSig]
  int UnregisterControlChangeNotify(IntPtr notify);
  [PreserveSig]
  int GetChannelCount(out uint channelCount);
  [PreserveSig]
  int SetMasterVolumeLevel(float levelDb, ref Guid eventContext);
  [PreserveSig]
  int GetMasterVolumeLevel(out float levelDb);
  [PreserveSig]
  int SetMasterVolumeLevelScalar(float level, ref Guid eventContext);
  [PreserveSig]
  int GetMasterVolumeLevelScalar(out float level);
  [PreserveSig]
  int SetChannelVolumeLevel(uint channel, float levelDb, ref Guid eventContext);
  [PreserveSig]
  int GetChannelVolumeLevel(uint channel, out float levelDb);
  [PreserveSig]
  int SetChannelVolumeLevelScalar(uint channel, float level, ref Guid eventContext);
  [PreserveSig]
  int GetChannelVolumeLevelScalar(uint channel, out float level);
  [PreserveSig]
  int SetMute([MarshalAs(UnmanagedType.Bool)] bool muted, ref Guid eventContext);
  [PreserveSig]
  int GetMute([MarshalAs(UnmanagedType.Bool)] out bool muted);
  [PreserveSig]
  int GetVolumeStepInfo(out uint step, out uint stepCount);
  [PreserveSig]
  int VolumeStepUp(ref Guid eventContext);
  [PreserveSig]
  int VolumeStepDown(ref Guid eventContext);
  [PreserveSig]
  int QueryHardwareSupport(out uint hardwareSupportMask);
  [PreserveSig]
  int GetVolumeRange(out float minimumDb, out float maximumDb, out float incrementDb);
}

public static class MiniVoiceEndpointAudio {
  public static IMiniVoiceEndpointVolume GetDefaultEndpoint() {
    IMiniVoiceDeviceEnumerator enumerator = (IMiniVoiceDeviceEnumerator)new MiniVoiceDeviceEnumerator();
    IMiniVoiceDevice device;
    Marshal.ThrowExceptionForHR(enumerator.GetDefaultAudioEndpoint(0, 1, out device));
    Guid interfaceId = typeof(IMiniVoiceEndpointVolume).GUID;
    object instance;
    Marshal.ThrowExceptionForHR(device.Activate(ref interfaceId, 23, IntPtr.Zero, out instance));
    return (IMiniVoiceEndpointVolume)instance;
  }

  public static float GetVolume(IMiniVoiceEndpointVolume endpoint) {
    float volume;
    Marshal.ThrowExceptionForHR(endpoint.GetMasterVolumeLevelScalar(out volume));
    return volume;
  }

  public static bool GetMute(IMiniVoiceEndpointVolume endpoint) {
    bool muted;
    Marshal.ThrowExceptionForHR(endpoint.GetMute(out muted));
    return muted;
  }

  public static void SetVolume(IMiniVoiceEndpointVolume endpoint, float volume) {
    Guid eventContext = Guid.Empty;
    Marshal.ThrowExceptionForHR(endpoint.SetMasterVolumeLevelScalar(volume, ref eventContext));
  }

  public static void SetMute(IMiniVoiceEndpointVolume endpoint, bool muted) {
    Guid eventContext = Guid.Empty;
    Marshal.ThrowExceptionForHR(endpoint.SetMute(muted, ref eventContext));
  }
}
'@

  $endpoint = [MiniVoiceEndpointAudio]::GetDefaultEndpoint()
  $originalVolume = [MiniVoiceEndpointAudio]::GetVolume($endpoint)
  $originalMute = [MiniVoiceEndpointAudio]::GetMute($endpoint)
  $mustRestore = $true

  [MiniVoiceEndpointAudio]::SetMute($endpoint, $false)
  [MiniVoiceEndpointAudio]::SetVolume($endpoint, $Volume / 100.0)
  [System.IO.File]::WriteAllText($readyPath, 'ready')

  $deadline = [DateTime]::UtcNow.AddMinutes(30)
  while ([DateTime]::UtcNow -lt $deadline) {
    if ([System.IO.File]::Exists($donePath)) {
      break
    }

    if (-not (Get-Process -Id $parentProcessId -ErrorAction SilentlyContinue)) {
      break
    }

    Start-Sleep -Milliseconds 50
  }
}
catch {
  [System.IO.File]::WriteAllText($errorPath, $_.Exception.Message)
}
finally {
  if ($mustRestore) {
    try {
      [MiniVoiceEndpointAudio]::SetVolume($endpoint, $originalVolume)
      [MiniVoiceEndpointAudio]::SetMute($endpoint, $originalMute)
      [System.IO.File]::WriteAllText($restoredPath, 'restored')
    }
    catch {
      [System.IO.File]::WriteAllText($errorPath, "No se pudo restaurar el volumen: $($_.Exception.Message)")
    }
  }
  else {
    [System.IO.File]::WriteAllText($restoredPath, 'unchanged')
  }
}
