@echo off

:: *********************************** CONVERSION DE FORMATOS MULTIMEDIA ***********************************
:: **                                                                                                     **
:: **                                                                                                     **
:: *********************************************************************************************************

If /i "%_HACK_CHEKC_%" neq "1987" (
	echo Process Abort 500
	pause
	exit
)

if "%1" == "" (
	echo The file was either run regardless or from cmd without arguments. 
	pause
	exit /b 2
)

:: This portion will use the paramter sent from cmd window.
call :%*
goto :END


:: - FUNCINES.................


:END
exit /b 0
