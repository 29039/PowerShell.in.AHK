#Requires AutoHotkey v2.0

; https://github.com/29039/PowerShell.in.AHK
; Version:  v0.01
; License: LGPL v2.1
; Description: Run Windows PowerShell 5.1 commands in-process of AutoHotKey V2 without launching powershell.exe
;
; Usage:
;   #Include Powershell-in-AHK.ahk
;   Result := RunPowerShell("Get-Date")
;
; Stream output configuration:
;   Bitmask: 1=Success 2=Error 4=Warning 8=Verbose 16=Debug 32=Information
;
; Credits:
;   CLR/.NET interop based on concepts and techniques from CLR.ahk by Lexikos:
;   Developed with AI assistance.

global PSStreams := 35 ;  Default is Information + Error + Success

RunPowerShell(Script) {
    global PSStreams
    static Host := 0
    if !Host {
        static Null := ComValue(13, 0), Empty := ComObjArray(0xC, 0)
        DllCall("ole32\IIDFromString", "wstr", "{CB2F6723-AB3A-11D2-9C40-00C04FA30A3E}", "ptr", CLSID := Buffer(16), "hresult")
        DllCall("ole32\IIDFromString", "wstr", "{CB2F6722-AB3A-11D2-9C40-00C04FA30A3E}", "ptr", IID := Buffer(16), "hresult")
        DllCall("mscoree\CorBindToRuntimeEx", "wstr", "v4.0.30319", "ptr", 0, "uint", 0, "ptr", CLSID, "ptr", IID, "ptr*", &Runtime := 0, "hresult")
        ComCall(10, Runtime)
        ComCall(13, Runtime, "ptr*", &DomainPointer := 0)
        Domain := ComObjFromPtr(DomainPointer)
        AssemblyArguments := ComObjArray(0xC, 1), AssemblyArguments[0] := "System"
        System := Domain.GetType().Assembly.GetType().InvokeMember_3("LoadWithPartialName", 0x158, Null, Null, AssemblyArguments)
        SMA := "C:\Windows\Microsoft.Net\assembly\GAC_MSIL\System.Management.Automation\v4.0_3.0.0.0__31bf3856ad364e35\System.Management.Automation.dll"
        References := ComObjArray(8, 2), References[0] := "System.Core.dll", References[1] := SMA
        CompilerArguments := ComObjArray(0xC, 1), CompilerArguments[0] := References
        Parameters := System.CreateInstance_3("System.CodeDom.Compiler.CompilerParameters", true, 0, Null, CompilerArguments, Null, Empty)
        Parameters.GenerateInMemory := true
        Host := System.CreateInstance("Microsoft.CSharp.CSharpCodeProvider").CreateCompiler().CompileAssemblyFromSource(Parameters, "
        (
        using System;
        using System.Text;
        using System.Collections;
        using System.Management.Automation;
        using System.Management.Automation.Runspaces;
        public class PSHost {
            readonly Runspace runspace;
            readonly PowerShell powershell;
            readonly IEnumerable[] streams;
            public int StreamMask { get; set; }
            public PSHost() {
                runspace = RunspaceFactory.CreateRunspace();
                runspace.Open();
                powershell = PowerShell.Create();
                powershell.Runspace = runspace;
                streams = new IEnumerable[] {
                    powershell.Streams.Error,
                    powershell.Streams.Warning,
                    powershell.Streams.Verbose,
                    powershell.Streams.Debug,
                    powershell.Streams.Information
                };
            }
            public string Run(string script) {
                powershell.Commands.Clear();
                foreach (var stream in streams) ((IList)stream).Clear();
                powershell.AddScript(script);
                var results = powershell.Invoke();
                var output = new StringBuilder();
                if ((StreamMask & 1) != 0)
                    foreach (var x in results) output.AppendLine(x.ToString());
                for (int i = 0; i < streams.Length; i++)
                    if ((StreamMask & (2 << i)) != 0)
                        foreach (var x in streams[i]) output.AppendLine(x.ToString());
                return output.ToString().TrimEnd();
            }
        }
        )").CompiledAssembly.CreateInstance_2("PSHost", true)
        Host.StreamMask := PSStreams
    }
    return Host.Run(Script)
}

; Examples:
; MsgBox RunPowerShell("Get-Date")
; MsgBox RunPowerShell("'Hello from PowerShell'")
; MsgBox RunPowerShell("Get-Process | Select-Object -First 5")
; MsgBox RunPowerShell("Write-Output 'Success'; Write-Error 'Error'; Write-Host 'Information'")
