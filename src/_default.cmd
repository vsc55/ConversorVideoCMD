@echo off

:: *********************************** CONVERSION DE FORMATOS MULTIMEDIA ***********************************
:: **                                                                                                     **
:: **                                                                                                     **
:: *********************************************************************************************************

If /i "%_HACK_CHEKC_%" neq "1987" (
	echo Process Abort 500
	pause
	exit /b 500
)
if "%1" == "" (
	echo El archivo se ejecuto independientemente o desde cmd sin argumentos.
	pause
	exit /b 200
)


:: This portion will use the paramter sent from cmd window.
:: FIX: Hay que crear una var con los argumentos recibidos para no perder simbolos especiales en los string
::      como por ejemplo "ERROR: Algo ^(x68^)^^^^^^^!", si no se hace obtendriamos "ERROR: Algo ^(x68^)^^".
::		https://superuser.com/questions/1292476/call-subroutine-where-parameter-contains-ampersand-in-batch-file
set "CallArgsFix=%*"
call :!CallArgsFix!
(set CallArgsFix=)
exit /b 0


:: :FUNCTION
::  ... CODE ...
::  goto:eof
