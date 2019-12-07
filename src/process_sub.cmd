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



:START_PROCESS
	echo [SUBS] - PROCESO INICIANDO...
	if "%~1" == "" (
		echo [SUBS] - [SKIP] - NO SE HA ESPECIFICADO NINGUN ARCHIVO A PREOCESAR^^!^^!
	) else If not exist "%~1" (
		echo [SUBS] - [SKIP] - EL ARCHIVO A PROCESAR YA NO EXISTE^^!^^!
	) else (
		SETLOCAL
			CALL :FILES_NAME_SET_ALL "%~1"

			REM ******** DEBUG!!!!!!!!!!!!!!!!
			if "%_debug%" == "YES" ( CALL :PRINT_DEBUG_INFO )
			REM ******** DEBUG!!!!!!!!!!!!!!!!

			CALL :START_PROCESS_CHECK _skip_process_run "%~1"
			if not defined _skip_process_run ( call :START_PROCESS_RUN %* )

			call :FILES_NAME_CLEAN_ALL
		ENDLOCAL
	)
	echo.
	goto:eof


:START_PROCESS_CHECK
	call :READ_STREAM "%~2" _read_stream
	if "!_read_stream!" == "1" (
		echo [SUBS] - [SKIP] - NO SE HA DETECTADO NINGUNA PISTA DE SUBTITULOS^^!^^!
		set "%~1=SKIP"
		GOTO :eof
	)

	REM CODIGO PARA VALIDAR SI TODO ESTA CORRECTO PARA PROCESAR, PARA SALTAR EL PROCESADO RETORNAMOS EN %1 SKIP.
	goto:eof


:START_PROCESS_RUN
	SETLOCAL
		set t_file=%~1
		echo [SUBS] - [SKIP] - NO IMPLEMENTADO AUN^^!^^!

		REM *********** CODIGO PROCESS ***********
		REM *********** CODIGO PROCESS ***********
		REM *********** CODIGO PROCESS ***********

	ENDLOCAL
	echo [SUBS] - [FINALIZADO]
	goto:eof

:: **** ELIMINAR ARCHIVOS
:FILES_REMOVE
	if not "%_debug%" == "YES" (
		@call src\gen_func.cmd FUN_FILE_DELETE_FILE !tfStreamS!
		@call src\gen_func.cmd FUN_FILE_DELETE_FILE !tfStreamCountS!
	)
	goto:eof


:: **** CONTROL VARIABLES FILES
:FILES_NAME_CLEAN_ALL
	CALL :FILES_NAME_CLEAN
	goto:eof

:FILES_NAME_CLEAN
	CALL :FILES_NAME_SET
	goto:eof

:FILES_NAME_SET_ALL
	CALL :FILES_NAME_SET %*
	goto:eof

:FILES_NAME_SET
	if "%~1" == "" (
		(set tfStreamS=)
		(set tfStreamCountS=)
	) else (
		set tfStreamS="%tPathProce%\%~n1_info_stream_sub.txt"
		set tfStreamCountS="%tPathProce%\%~n1_info_stream_count_s.txt"
	)
	goto:eof

:: **** FUNCTIONS
:PRINT_DEBUG_INFO
	echo.
	echo [SUBS] ********** DEBUG **********
	echo [SUBS] - tfStreamS:              %tfStreamS%
	echo [SUBS] - tfStreamCountS:         %tfStreamCountS%
	echo [SUBS] ********** DEBUG **********
	echo.
	goto:eof

:READ_STREAM
	SETLOCAL
		call :FILES_NAME_SET_ALL "%~1"
		findstr.exe /i /c:"Subtitle: " !tfStreamAll! > !tfStreamS!
		set error=%errorlevel%
		call :FILES_NAME_CLEAN_ALL
	ENDLOCAL & (
		set "%~2=%error%"
	)
	goto:eof
