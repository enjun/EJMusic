Add-Type @'
using System;
using System.Text;
using System.Collections.Generic;
using System.Runtime.InteropServices;
public class TopWin {
  public delegate bool EnumProc(IntPtr h, IntPtr l);
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc p, IntPtr l);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")] public static extern IntPtr GetWindow(IntPtr h, uint cmd);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetClassName(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  public struct RECT { public int Left, Top, Right, Bottom; }
  public static List<string> Find(HashSet<uint> pids) {
    SetProcessDPIAware();
    var res = new List<string>();
    EnumWindows((h, l) => {
      uint pid; GetWindowThreadProcessId(h, out pid);
      if (pids.Contains(pid)) {
        var sb = new StringBuilder(256); GetClassName(h, sb, 256);
        RECT r; GetWindowRect(h, out r);
        IntPtr owner = GetWindow(h, 4); // GW_OWNER
        res.Add(h.ToString() + "|class=" + sb.ToString() + "|vis=" + IsWindowVisible(h)
          + "|rect=" + r.Left + "," + r.Top + "," + r.Right + "," + r.Bottom
          + "|owner=" + owner.ToString());
      }
      return true;
    }, IntPtr.Zero);
    return res;
  }
}
'@
$names = @("msedgewebview2.exe", "ejmusic.exe")
$pidSet = New-Object 'System.Collections.Generic.HashSet[uint32]'
foreach ($n in $names) {
  Get-Process -Name ($n -replace '\.exe$','') -ErrorAction SilentlyContinue | ForEach-Object { [void]$pidSet.Add([uint32]$_.Id) }
}
Write-Output ("pids: " + ($pidSet -join ","))
[TopWin]::Find($pidSet) | ForEach-Object { Write-Output $_ }
