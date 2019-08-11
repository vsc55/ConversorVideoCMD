'debugmode = 0 	Debug OFF
'debugmode = 1 	Debug ON

Const ForReading = 1, ForWriting = 2, debugmode = 0
Dim sPathStreamA_A, sPathStreamA, sPathStreamID, sReturn, iReturn, j

Set objFSO = CreateObject("Scripting.FileSystemObject")
Set objDict = CreateObject("Scripting.Dictionary")
Set objArgs = WScript.Arguments

if objArgs.Count = 3 then
	sPathStreamA_A = objArgs(0)
	sPathStreamA = objArgs(1)
	sPathStreamID = objArgs(2)
	if Len(Trim(sPathStreamA_A)) = 0 then
		DebugWrite "ERROR 2: Arg1 es null!"
		WScript.Quit 2
	elseif Len(Trim(sPathStreamA)) = 0 then
		DebugWrite "ERROR 3: Arg2 es null!"
		WScript.Quit 3
	elseif Len(Trim(sPathStreamID)) = 0 then
		DebugWrite "ERROR 4: Arg3 es null!"
		WScript.Quit 4
	end if
	If objFSO.FileExists(sPathStreamA_A) = false Then 
		DebugWrite "ERROR 5: Archivos fuente (" & sPathStreamA_A & ") no existe!"
		WScript.Quit 5
	end if
else
	DebugWrite "ERROR 1: Faltan Argumentos!"
	WScript.Quit 1
end if


CreateFile(sPathStreamA)
CreateFile(sPathStreamID)


j = 0
Set objStreamA_A = objFSO.OpenTextFile(sPathStreamA_A, ForReading)
While Not objStreamA_A.AtEndOfStream 
	str1 = Trim(objStreamA_A.Readline)
	if len(str1) > 0 then
		objDict.add j, str1
		j=j+1
	end if
Wend 
objStreamA_A.Close


DebugWrite "TOTAL PISTAS:" & objDict.count

if objDict.Count = 0 then
	DebugWrite "ERROR 6: No hay pistas de audio!"
	WScript.Quit 6
elseif objDict.Count = 1 then
	sReturn = objDict.Item(0)
else
	Set tmpDict = CreateObject("Scripting.Dictionary")
	
	'BUSCAMOS (SPA)
	j = 0
	For i = 0 To objDict.Count - 1
		DebugWrite "ALL: " & objDict.Item(i)
		str1 = objDict.Item(i)
		If InStr(str1, "(spa)") > 0 Then
			tmpDict.add j, str1
			j=j+1
		end if
	Next 
	
	'SI NO HAY RESULTADOS DE (SPA), BUSCAMOS (DEFAULT)
	if tmpDict.Count = 0 then
		j = 0
		For i = 0 To objDict.Count - 1
			str1 = objDict.Item(i)
			If InStr(str1, "(default)") > 0 Then
				tmpDict.add j, str1
				j=j+1
			end if
		Next
	end if
	
	'SI TAMPOCO HAY RESULTADOS DE (DEFAULT), BUSCAMOS 5.1
	if tmpDict.Count = 0 then
		j = 0
		For i = 0 To objDict.Count - 1
			str1 = objDict.Item(i)
			If InStr(str1, "5.1") > 0 Then
				tmpDict.add j, str1
				j=j+1
			end if
		Next
	end if
	
	
	if tmpDict.Count = 0 then
		'SI NO SE HA ENCONTRADO NINGUN RESLUTADO CON LOS FILTROS ANTERIORES, USAMOS LA PISTA 1.
		sReturn = objDict.Item(0)
	elseif tmpDict.Count = 1 then
		sReturn = tmpDict.Item(0)
	elseif tmpDict.Count > 1 then
		DebugWrite "--------------------------------------------------"
		DebugWrite "PISTAS DETECTADAS:" & tmpDict.count
		DebugWrite "--------------------------------------------------"
	
		'SI HAY MAS DE 1 RESULTADO, BUSCAMOS SI HAY ALGUNO MARCADO COMO (DEFAULT)
		For i = 0 To tmpDict.Count - 1
			DebugWrite "TMP: " & tmpDict.Item(i)
			str1 = tmpDict.Item(i)
			If InStr(str1, "(default)") > 0 Then
				sReturn = str1
				Exit For
			End If
		Next
		
		If Len(sReturn) = 0 then
			'SI NO SE HA ENCONTRADO NINGUN PISTA CON (DEFAULT), BUSCAMOS LA PRIMERA QUE TENGA 5.1
			For i = 0 To tmpDict.Count - 1
				str1 = tmpDict.Item(i)
				If InStr(str1, "5.1") > 0 Then
					sReturn = str1
					Exit For
				End If
			Next
		End If
		
		If Len(sReturn) = 0 then
			'SI NO SE LOCALIZA NINGUNA QUE TENGA 5.1 COGEMOS LA PRIMERA PISTA DE LA LISTA QUE SE HA FILTRADO ANTERIORMENTE
			sReturn = tmpDict.Item(0)
		End If
		
		DebugWrite "--------------------------------------------------"
	End if
	
end if
DebugWrite "sReturn: " & sReturn


if len(trim(sReturn)) > 0 then
	'sReturn ="Stream #0:1(spa): Audio: ac3, 48000 Hz, 5.1(side), fltp, 384 kb/s (default)"
	'sReturn ="Stream #0:1: Audio: ac3, 48000 Hz, 5.1(side), fltp, 384 kb/s (default)"
	
	iReturn = split(split(Split(sReturn," ")(1),":")(1),"(")(0)
end if
DebugWrite "iReturn: " & iReturn


WriteFile sPathStreamA, sReturn
WriteFile sPathStreamID, iReturn





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

Sub CreateFile(sPath)
	if Len(Trim(sPath)) = 0 Then Exit Sub
	With CreateObject("Scripting.FileSystemObject")
		If .FileExists(sPath) = false  Then .CreateTextFile(sPath)
	End With
End Sub
