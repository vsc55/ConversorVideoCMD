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
		
		if exist "!t_file_read!" (
			set RunExternal=%tPathffmpeg% -i "!t_file_read!"
			@call src\gen_func.cmd RUN_SUB_EXE 2 "!t_file_save!"
		)
	ENDLOCAL
	goto:eof


:COUNT_STREAM
	:: @call src\fun_ffmpeg.cmd COUNT_STREAM "path file" "path_save_count" "[Audio|Video|Subtitle]" return_count
	SETLOCAL
		set t_file_read=%~1
		set t_file_save=%~2
		set t_type=%~3

		if exist !t_file_read! (
			set RunExternal=%tPathffmpeg% -i "!t_file_read!" 2^>^&1 ^| findstr /R /C:"Stream " ^| findstr /R /C:" !t_type!: " ^| find /c /v ""
			call src\gen_func.cmd RUN_SUB_EXE 3 "!t_file_save!" t_count
		)
		if not defined t_count ( 
			set t_count=0 
		) else (
			REM FUENTE DE LA FUNCION: https://superuser.com/questions/404338/check-for-only-numerical-input-in-batch-file
			echo !t_count!|findstr /xr "[1-9][0-9]* 0" >nul && (
				REM ES UN NUMERO, NO HACEMOS NADA
			) || (
				set t_count=0
			)
		)
	ENDLOCAL & (
		if not "%~4" == "" ( set "%~4=%t_count%" )
	)
	goto:eof

