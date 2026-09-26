Add-Type @'
using System;
using System.Text;
using System.Runtime.InteropServices;
public class ZProbe {
  public delegate bool EnumProc(IntPtr h, IntPtr l);
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc p, IntPtr l);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetClassName(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern IntPtr WindowFromPoint(P p);
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  public struct RECT { public int Left, Top, Right, Bottom; }
  public struct P { public int x, y; }
  static uint pid = 0;
  static int webRank = -1, mainRank = -1, r2 = 0;
  static IntPtr web = IntPtr.Zero;
  public static void Run() {
    SetProcessDPIAware();
    EnumWindows((h, l) => {
      uint p; GetWindowThreadProcessId(h, out p);
      var sb = new StringBuilder(256); GetClassName(h, sb, 256);
      if (IsWindowVisible(h) && sb.ToString() == "FLUTTER_RUNNER_WIN32_WINDOW") { pid = p; return false; }
      return true;
    }, IntPtr.Zero);
    Console.WriteLine("main pid=" + pid);
    EnumWindows((h, l) => {
      uint p; GetWindowThreadProcessId(h, out p);
      var sb = new StringBuilder(256); GetClassName(h, sb, 256);
      string cn = sb.ToString();
      if (!IsWindowVisible(h)) return true;
      if (cn == "Chrome_WidgetWin_1" && webRank < 0) { webRank = r2; web = h; }
      if (p == pid && cn == "FLUTTER_RUNNER_WIN32_WINDOW") mainRank = r2;
      r2++;
      return true;
    }, IntPtr.Zero);
    Console.WriteLine("zRank web=" + webRank + " main=" + mainRank + " (smaller=higher)");
    if (web != IntPtr.Zero) {
      RECT wr; GetWindowRect(web, out wr);
      var pt = new P { x = (wr.Left + wr.Right) / 2, y = (wr.Top + wr.Bottom) / 2 };
      IntPtr hit = WindowFromPoint(pt);
      var hsb = new StringBuilder(256); GetClassName(hit, hsb, 256);
      Console.WriteLine("point=(" + pt.x + "," + pt.y + ") hit=" + hsb.ToString());
    }
  }
}
'@
[ZProbe]::Run()
