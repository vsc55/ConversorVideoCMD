Const ForReading = 1, ForWriting = 2
Dim i, fFrom, fTo, objKey

Set objFSO = CreateObject("Scripting.FileSystemObject")
Set objArgs = WScript.Arguments

if objArgs.Count = 2 then
	fFrom = objArgs(0)
	fTo = objArgs(1)
	if Len(Trim(fFrom)) = 0 then
		WScript.Quit 2
	elseif Len(Trim(fto)) = 0 then
		WScript.Quit 3
	end if
	If objFSO.FileExists(fFrom) = false Then WScript.Quit 4 	
else
	WScript.Quit 1
end if

Set objInputFile = objFSO.OpenTextFile(fFrom, ForReading)
Set objOutputFile = objFSO.OpenTextFile (fTo, ForWriting, True)
Set objDict = CreateObject("Scripting.Dictionary")

While Not objInputFile.AtEndOfStream 
	str1 = objInputFile.Readline
	If InStr(str1, "Parsed_cropdetect_") > 0 Then
		s=Split(str1," ")
		b=Split(s(UBound(s)),"=")
		if b(0) = "crop" then
			if objDict.Exists(b(1)) then
				objDict.item(b(1)) = objDict.item(b(1)) + 1
			Else 
				objDict.add b(1), 1
			End if
		end if
	End If
Wend

For Each objKey In objDict
	'wscript.Echo "key:" & CStr(objKey) & " - Val:" & CStr(objDict(objKey))
	objOutputFile.writeline CStr(objKey) & "-" & CStr(objDict(objKey))
Next

objInputFile.Close
objOutputFile.Close


'Fuente:
'https://gallery.technet.microsoft.com/scriptcenter/f536a3de-1c42-4838-9e35-4874a11e681f