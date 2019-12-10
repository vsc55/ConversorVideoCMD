;Fuentes:
; https://www.autoitscript.com/forum/topic/147424-disable-or-remove-close-minimize-maximize-buttons-on-any-window-in-runtime/


; Constants from http://msdn.microsoft.com/en-us/library/windows/desktop/ms646360(v=vs.85).aspx
Const $SC_CLOSE = 0xF060
Const $SC_MOVE = 0xF010
Const $SC_MAXIMIZE = 0xF030
Const $SC_MINIMIZE = 0xF020
Const $SC_SIZE = 0xF000
Const $SC_RESTORE = 0xF120


Func GetMenuHandle($hWindow, $bRevert = False)
   If $bRevert = False Then
	  $iRevert = 0
   Else
	  $iRevert = 1
   EndIf
   $aSysMenu = DllCall("User32.dll", "hwnd", "GetSystemMenu", "hwnd", $hWindow, "int", $iRevert)
   Return $aSysMenu[0]
EndFunc

Func DisableButton($hWindow, $iButton)
   $hSysMenu = GetMenuHandle($hWindow)
   DllCall("User32.dll", "int", "RemoveMenu", "hwnd", $hSysMenu, "int", $iButton , "int", 0)
   DllCall("User32.dll", "int", "DrawMenuBar", "hwnd", $hWindow)
EndFunc

Func EnableButton($hWindow, $iButton)
   $hSysMenu = GetMenuHandle($hWindow, True)
   DllCall("User32.dll", "int", "RemoveMenu", "hwnd", $hSysMenu, "int", $iButton , "int", 0)
   DllCall("User32.dll", "int", "DrawMenuBar", "hwnd", $hWindow)
EndFunc




;No se pasan parametros
If $CmdLine[0]=0 Then Exit
If $CmdLine[1] = "true" Then
   $action = True
ElseIf $CmdLine[1] = "false" Then
   $action = False
Else
   MsgBox(4096, "Error", "Command not found!!")
   Exit
EndIf


$handle = WinGetHandle("[CLASS:ConsoleWindowClass]")
If @error Then
   MsgBox(4096, "Error", "Error: Could not find the correct window")
Else
   If $action = True Then
	  EnableButton($handle, $SC_CLOSE)
   ElseIf $action = False Then
	  DisableButton($handle, $SC_CLOSE)
   Else
	  MsgBox(4096, "Error", "Unknown action!!")
   EndIf
EndIf
