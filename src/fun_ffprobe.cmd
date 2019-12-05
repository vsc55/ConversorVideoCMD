@echo off

:: *********************************** CONVERSION DE FORMATOS MULTIMEDIA ***********************************
:: **                                                                                                     **
:: **                                                                                                     **
:: *********************************************************************************************************

If /i "%_HACK_CHEKC_%" neq "1987" (
	echo ERROR 500!!
	pause
	exit /b 500
)
if "%1" == "" (
	echo ERROR: El archivo se ejecuto independientemente o desde cmd sin argumentos!!
	pause
	exit /b 200
)

:: This portion will use the paramter sent from cmd window.
call :%*
exit /b 0



:GET_RESOLUCION
	:: @call src\fun_ffprobe.cmd GET_RESOLUCION "path_movie" "path_file_save_value" return_value
	SETLOCAL
		set t_file_read=%~1
		set t_file_save=%~2
		
		if exist "%t_file_read%" (
			set RunFunction=%tPathffprobe% -v error -select_streams v:0 -show_entries stream=width,height -of csv=s=x:p=0 "%t_file_read%"
			@call src\gen_func.cmd RUN_EXE 1 "%t_file_save%"
			(set RunFunction=)
			set /p gat_value=<"%t_file_save%"
		) else (
			set gat_value=0
		)

	ENDLOCAL & (
		set "%~3=%gat_value%"
	)
	goto:eof


:GET_DURACION
	:: @call src\fun_ffprobe.cmd GET_DURACION "path_movie" "path_file_save_value" return_value
	SETLOCAL
		set t_file_read=%~1
		set t_file_save=%~2
		
		if exist "%t_file_read%" (
			set RunFunction=%tPathffprobe% -v error -show_entries format=duration -sexagesimal -of default=noprint_wrappers=1:nokey=1 "%t_file_read%"
			@call src\gen_func.cmd RUN_EXE 1 "%t_file_save%"
			(set RunFunction=)
			set /p gat_value=<"%t_file_save%"
		) else ( 
			set gat_value=0
		)

	ENDLOCAL & (
		set "%~3=%gat_value%"
	)
	goto:eof

:DURACION_FORMAT
	:: @call src\fun_ffprobe.cmd DURACION_FORMAT !tDuration! tDuration
	:: eliminamos los milisegudnos.
	for /f "delims=." %%A in ("%~1") do set "%~2=%%~A"