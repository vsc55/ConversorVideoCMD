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
	If InStr(str1, "Parsed_ashowinfo_") > 0 Then
		If InStr(str1, "pts_time:") > 0 Then
				
			s=Split(str1," ")
			For i=LBound(s) To UBound(s)
				b=Split(s(i),":")
				if b(0) = "pts_time" then
					DebugWrite str1
					iReturn = trim(b(1))
				end if
			Next
			
		End If
	End If
Wend 
objInfoFile.Close

if IsEmpty(iReturn) = true then
	iReturn = 0
elseif IsNumeric(iReturn) = false then
	iReturn = 0
else
	'TENEMOS QUE DIVIDIR EL TIEMPO A LA MITAD PARA QUE EL AUDIO ESTE SINCRONIZADO, EN TIEMPOS ALTOS ESTO FALLA
	'TODO: PENDIENTE MIRAR POR QUE SUCEDE ESTO
	'!!!!!!INFO!!!!!!: ESTE PROBLEMA ERA DEVIDO AL RECODIFICAR CON EL CODEC AAC Y AÑADIR LA PISTA DEL SILENCIO ENTRE DICHAS PISTAS DE AUDIO AÑADIA UNOS SEGUNDOS O MILISEGUNDOS PRODUCIENDO LOS DESFASES.
	'                  ANULAMOS ESTA DIVISON YA QUE AHORA SE GENERA UN WEV QUE NO SUBRE ESA DESINCRONIZACION.
	'iReturn=Replace((Cdbl(Replace(iReturn,".",",")) / 2),",",".")
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
