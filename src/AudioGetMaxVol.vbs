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

Set objInfoFile = objFSO.OpenTextFile(sPathFileInfo, ForReading)
While Not objInfoFile.AtEndOfStream 
	str1 = objInfoFile.Readline
	If InStr(str1, "Parsed_volumedetect_") > 0 Then
		If InStr(str1, "max_volume:") > 0 Then
			DebugWrite str1
			s=Split(str1,":")			
			If UBound(s) = 1 then
				iReturn = trim(s(UBound(s)))
				s=Split(iReturn," ")
				If UBound(s) = 1 then
					iReturn=Trim(s(0))
				End If
			End If
		End If
	End If
Wend 
objInfoFile.Close

if IsEmpty(iReturn) = true then
	iReturn = 0
elseif IsNumeric(iReturn) = false then
	iReturn = 0
elseif iReturn = "0.0" then
	iReturn = 0
end if



if iReturn > 0 then
	'si el valor es positivo quiere decir que el volumen esta por encima del nivel vase, por lo que lo dejamos en 0
	'para omitir el aumento de volumen.
	iReturn = 0
else 
	'eliminamos el simbolo - para combertir el valor en numero positivo. No usamos "iReturn * -1" ya que se come los decimales.
	'iReturn = Right(iReturn, len(iReturn) -1)
	iReturn=Replace((Cdbl(Replace(iReturn,".",",")) * -1),",",".")
end if


DebugWrite iReturn

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
