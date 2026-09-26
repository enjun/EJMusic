param([int]$X, [int]$Y)
Add-Type @'
using System;
using System.Text;
using System.Runtime.InteropServices;
public class H9 {
  [DllImport("user32.dll")] public static extern IntPtr WindowFromPoint(P p);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetClassName(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern IntPtr GetAncestor(IntPtr h, uint f);
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  public struct RECT { public int Left, Top, Right, Bottom; }
  public struct P { public int x, y; }
  public static void Run(int x, int y) {
    SetProcessDPIAware();
    var pt = new P { x = x, y = y };
    IntPtr h = WindowFromPoint(pt);
    var sb = new StringBuilder(256); GetClassName(h, sb, 256);
    RECT r; GetWindowRect(h, out r);
    Console.WriteLine("hit " + sb + " rect=" + r.Left + "," + r.Top + "," + r.Right + "," + r.Bottom);
    IntPtr top = GetAncestor(h, 2); // GA_ROOT
    var sb2 = new StringBuilder(256); GetClassName(top, sb2, 256);
    RECT r2; GetWindowRect(top, out r2);
    Console.WriteLine("root " + sb2 + " rect=" + r2.Left + "," + r2.Top + "," + r2.Right + "," + r2.Bottom);
  }
}
'@
[H9]::Run($X, $Y)
