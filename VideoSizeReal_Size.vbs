Set objFS = CreateObject("Scripting.FileSystemObject")
Set objArgs = WScript.Arguments
str1 = objArgs(0)
s=Split(str1,":")
WScript.Echo s(0) & "x" & s(1)