Set objFS = CreateObject("Scripting.FileSystemObject")
Set objArgs = WScript.Arguments
str1 = objArgs(0)
s=Split(str1," ")
For i=LBound(s) To UBound(s)
	b=Split(s(i),":")
	if b(0) = "pts_time" then
		'WScript.Echo b(1) * 100
		WScript.Echo b(1)
	end if
	'WScript.Echo "DEBUG:" & s(i)
Next