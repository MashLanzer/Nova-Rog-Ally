using System;
using System.Runtime.InteropServices;
using System.Collections.Generic;

namespace NovaAudio
{
    [ComImport, Guid("A95664D2-9614-4F35-A746-DE8DB63617E6"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    interface IMMDeviceEnumerator
    {
        int EnumAudioEndpoints(int dataFlow, int stateMask, out IMMDeviceCollection devices);
        int GetDefaultAudioEndpoint(int dataFlow, int role, out IMMDevice endpoint);
    }

    [ComImport, Guid("0BD7A1BE-7A1A-44DB-8397-CC5392387B5E"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    interface IMMDeviceCollection
    {
        int GetCount(out int count);
        int Item(int index, out IMMDevice device);
    }

    [ComImport, Guid("D666063F-1587-4E43-81F1-B948E807363F"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    interface IMMDevice
    {
        int Activate(ref Guid iid, int clsCtx, IntPtr activationParams, [MarshalAs(UnmanagedType.IUnknown)] out object iface);
        int OpenPropertyStore(int access, out IPropertyStore store);
        int GetId([MarshalAs(UnmanagedType.LPWStr)] out string id);
        int GetState(out int state);
    }

    [ComImport, Guid("886d8eeb-8cf2-4446-8d02-cdba1dbdcf99"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    interface IPropertyStore
    {
        int GetCount(out int count);
        int GetAt(int prop, out PROPERTYKEY key);
        int GetValue(ref PROPERTYKEY key, out PROPVARIANT value);
        int SetValue(ref PROPERTYKEY key, ref PROPVARIANT value);
        int Commit();
    }

    [StructLayout(LayoutKind.Sequential)]
    struct PROPERTYKEY { public Guid fmtid; public int pid; }

    [StructLayout(LayoutKind.Explicit)]
    struct PROPVARIANT
    {
        [FieldOffset(0)] public short vt;
        [FieldOffset(8)] public IntPtr puntero;
        [FieldOffset(16)] public IntPtr relleno;
    }

    // interfaz no documentada que usa el propio panel de sonido de Windows para
    // cambiar el dispositivo predeterminado; solo importa el orden de la vtable
    [ComImport, Guid("f8679f50-850a-41cf-9c72-430f290290c8"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    interface IPolicyConfig
    {
        int GetMixFormat();
        int GetDeviceFormat();
        int ResetDeviceFormat();
        int SetDeviceFormat();
        int GetProcessingPeriod();
        int SetProcessingPeriod();
        int GetShareMode();
        int SetShareMode();
        int GetPropertyValue();
        int SetPropertyValue();
        int SetDefaultEndpoint([MarshalAs(UnmanagedType.LPWStr)] string deviceId, int role);
        int SetEndpointVisibility();
    }

    [ComImport, Guid("870af99c-171d-4f9e-af0d-e63df40c2bc9")] class CPolicyConfigClient { }
    [ComImport, Guid("BCDE0395-E52F-467C-8E3D-C4579291692E")] class MMDeviceEnumeratorCom { }

    public static class Salida
    {
        // cada elemento: "id|nombre|1 si es la actual"
        public static string[] Lista()
        {
            var res = new List<string>();
            var en = (IMMDeviceEnumerator)new MMDeviceEnumeratorCom();
            string actual = "";
            IMMDevice def;
            if (en.GetDefaultAudioEndpoint(0, 0, out def) == 0 && def != null) { def.GetId(out actual); }
            IMMDeviceCollection col;
            if (en.EnumAudioEndpoints(0, 1, out col) != 0) { return res.ToArray(); }   // render, activos
            int n; col.GetCount(out n);
            var clave = new PROPERTYKEY { fmtid = new Guid("a45c254e-df1c-4efd-8020-67d146a850e0"), pid = 14 };
            for (int i = 0; i < n; i++)
            {
                IMMDevice d; if (col.Item(i, out d) != 0) { continue; }
                string id; d.GetId(out id);
                string nombre = id;
                IPropertyStore ps;
                if (d.OpenPropertyStore(0, out ps) == 0)
                {
                    PROPVARIANT v;
                    if (ps.GetValue(ref clave, out v) == 0 && v.vt == 31 && v.puntero != IntPtr.Zero) { nombre = Marshal.PtrToStringUni(v.puntero); }
                }
                res.Add(id + "|" + nombre + "|" + (id == actual ? "1" : "0"));
            }
            return res.ToArray();
        }

        public static void Poner(string id)
        {
            var pc = (IPolicyConfig)new CPolicyConfigClient();
            for (int rol = 0; rol < 3; rol++) { pc.SetDefaultEndpoint(id, rol); }
        }
    }
}
