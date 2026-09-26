Add-Type @'
using System;
using System.Text;
using System.Runtime.InteropServices;
public class W8 {
  public delegate bool EnumProc(IntPtr h, IntPtr l);
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc p, IntPtr l);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetClassName(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  public struct RECT { public int Left, Top, Right, Bottom; }
  public static void Run() {
    SetProcessDPIAware();
    EnumWindows((h, l) => {
      var sb = new StringBuilder(256); GetClassName(h, sb, 256);
      if (!IsWindowVisible(h) || sb.ToString() != "Chrome_WidgetWin_1") return true;
      RECT r; GetWindowRect(h, out r);
      Console.WriteLine("WEB " + h + " " + r.Left + "," + r.Top + "," + r.Right + "," + r.Bottom);
      return true;
    }, IntPtr.Zero);
  }
}
'@
[W8]::Run()
