Set objFS = CreateObject("Scripting.FileSystemObject")
Set objArgs = WScript.Arguments
if objArgs.Count < 1 then WScript.Quit 1
str1 = objArgs(0)
s=Split(str1," ")
For i=LBound(s) To UBound(s)
	b=Split(s(i),":")
	'UBound(b) >= 1 EVITA "Subscript out of range" CON TOKENS VACIOS (DOBLES ESPACIOS) O SIN ":"
	if UBound(b) >= 1 then
		if b(0) = "pts_time" then
			'WScript.Echo b(1) * 100
			WScript.Echo b(1)
			'EL DESFASE INICIAL ES EL PRIMER pts_time
			Exit For
		end if
	end if
	'WScript.Echo "DEBUG:" & s(i)
Next
