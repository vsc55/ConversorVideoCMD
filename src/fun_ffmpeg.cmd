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




:GET_INFO
	:: @call src\fun_ffmpeg.cmd GET_INFO "path_movie" "path_file_save_value"
	SETLOCAL
		set t_file_read=%~1
		set t_file_save=%~2
		
		if exist "%t_file_read%" (
			set RunFunction=%tPathffmpeg% -i "%t_file_read%"
			@call src\gen_func.cmd RUN_EXE 2 "%t_file_save%"
			(set RunFunction=)
		)
	ENDLOCAL
	goto:eof





