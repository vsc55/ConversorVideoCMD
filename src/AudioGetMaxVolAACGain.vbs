'debugmode = 0 	Debug OFF
'debugmode = 1 	Debug ON

Const ForReading = 1, ForWriting = 2, debugmode = 0
Dim sPathFileInfo, sPathFileInfoR, iReturn

Set objFSO = CreateObject("Scripting.FileSystemObject")
Set objArgs = WScript.Arguments

if objArgs.Count = 2 then
	sPathFileInfo = objArgs(0)
	sPathFileInfoR = objArgs(1)
	if Len(Trim(sPathFileInfo)) = 0 then
		WScript.Quit 2
	elseif Len(Trim(sPathFileInfoR)) = 0 then
		WScript.Quit 3
	end if
	If objFSO.FileExists(sPathFileInfo) = false Then WScript.Quit 4
else
	WScript.Quit 1
end if

Set objInfoFile = objFSO.OpenTextFile(sPathFileInfo, 1)
While Not objInfoFile.AtEndOfStream 
	str1 = objInfoFile.Readline
	If InStr(str1, "Track") > 0 Then
		If InStr(str1, "mp3") > 0 Then
			DebugWrite str1
			s=Split(str1,":")
			If UBound(s) = 1 then
				iReturn = trim(s(UBound(s)))
			End If
		End If
	End If
Wend 
objInfoFile.Close

if IsEmpty(iReturn) = true then
	iReturn = 0
elseif IsNumeric(iReturn) = false then
	iReturn = 0
end if


DebugWrite "iReturn: " & iReturn
WriteFile sPathFileInfoR, iReturn


Sub DebugWrite(sTxt)
	if Len(Trim(sTxt)) = 0 then exit sub
	if debugmode <> 1 Then Exit Sub
	wscript.Echo sTxt
End Sub

Sub WriteFile(sPath, sText)
	if Len(Trim(sPath)) = 0 Then Exit Sub
	With CreateObject("Scripting.FileSystemObject")
		Set objWriteFile = .OpenTextFile (sPath, ForWriting, True)
		objWriteFile.writeline sText
		objWriteFile.Close
	End With
End Sub
