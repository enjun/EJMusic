param([int]$TargetPid)
Add-Type @'
using System;
using System.Text;
using System.Collections.Generic;
using System.Runtime.InteropServices;
public class WinEnum {
  public delegate bool EnumProc(IntPtr h, IntPtr l);
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc p, IntPtr l);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")] public static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
  public static List<string> Find(uint target) {
    var res = new List<string>();
    EnumWindows((h, l) => {
      uint pid; GetWindowThreadProcessId(h, out pid);
      if (pid == target) {
        var sb = new StringBuilder(256); GetWindowText(h, sb, 256);
        res.Add(h.ToString() + " visible=" + IsWindowVisible(h) + " [" + sb.ToString() + "]");
      }
      return true;
    }, IntPtr.Zero);
    return res;
  }
}
'@
[WinEnum]::Find($TargetPid) | ForEach-Object { Write-Output $_ }
