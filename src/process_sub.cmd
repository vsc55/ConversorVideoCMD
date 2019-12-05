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
	if "%~1" == "" (
		echo [SUBS] - [SKIP] - NO SE HA ESPECIFICADO NINGUN ARCHIVO A PREOCESAR^^!^^!
		echo.
		goto:eof
	)
	If not exist "%~1" (
		echo [SUBS] - [SKIP] - EL ARCHIVO A PROCESAR YA NO EXISTE^^!^^!
		echo.
		goto:eof
	)

	echo [SUBS] - PROCESO INICIANDO...
	SETLOCAL
		CALL :FILES_NAME_SET_ALL "%~1"
		:: ******** DEBUG!!!!!!!!!!!!!!!!
		if "!_debug_sa!" == "YES" (
			CALL :PRINT_DEBUG_INFO
			goto:eof
		)
		:: ******** DEBUG!!!!!!!!!!!!!!!!

		call :READ_STREAM "%~1" _read_stream
		if "!_read_stream!" == "1" (
			echo [SUBS] - [SKIP] - NO SE HAN DETECTADO NINGUNA PISTA DE SUBTITULOS^^!^^!
			set _skip_process_run=SKIP
		) else ( CALL :START_PROCESS_CHECK _skip_process_run )
		
		if not defined _skip_process_run ( call :START_PROCESS_RUN %* )

		call :FILES_NAME_CLEAN_ALL
	ENDLOCAL
	echo.
	goto:eof


:START_PROCESS_CHECK
	REM CODIG CHECK, SI NO SE SUPERA Y HAY QUE HACER SKIP USAREMOS >> set "%~1=SKIP"
	goto:eof


:START_PROCESS_RUN
	REM CODIGO PROCESS
	goto:eof

:: **** ELIMINAR ARCHIVOS
:FILES_REMOVE
	if not "%_debug%" == "YES" (
		@call src\gen_func.cmd FUN_FILE_DELETE_FILE !tfStreamS!
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
	) else (
		set tfStreamS="%tPathProce%\%~n1_info_stream_sub.txt"
	)
	goto:eof

:: **** FUNCTIONS
:PRINT_DEBUG_INFO
	echo [SUBS] - tPathFileOrig:          %tPathFileOrig%
	echo [SUBS] - tPathFileConvrt:        %tPathFileConvrt%
	echo [SUBS] - tFileName:              %tFileName%
	echo [SUBS] - tfInfoffmpeg:           %tfInfoffmpeg%

	echo [SUBS] - tfStreamS:              %tfStreamS%
	echo.
	pause
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
