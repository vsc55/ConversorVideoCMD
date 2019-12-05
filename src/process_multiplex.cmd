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
		echo [MULTIPLEX] - [STOP] - NO SE HA ESPECIFICADO NINGUN ARCHIVO A PREOCESAR^^!^^!
		echo.
		goto:eof
	)
	If not exist "%~1" (
		echo [MULTIPLEX] - [STOP] - EL ARCHIVO A PROCESAR YA NO EXISTE^^!^^!
		echo.
		goto:eof
	)
	If exist "%~2" (
		echo [MULTIPLEX] - [STOP] - YA SE HA PROCESADO^^!^^!
		echo.
		GOTO :eof
	)
	If not exist "%~3" (
		echo [MULTIPLEX] - [STOP] - EL ARCHIVO DE LA PISTA DE AUDIO NO SE HA LOCALIZADO^^!^^!
		echo.
		GOTO :eof
	)

	echo [MULTIPLEX] - PROGRESO INICIANDO...
	SETLOCAL
		CALL :FILES_NAME_SET_ALL "%~1"
		:: ******** DEBUG!!!!!!!!!!!!!!!!
		if "!_debug_sa!" == "YES" (
			CALL :PRINT_DEBUG_INFO
			goto:eof
		)
		:: ******** DEBUG!!!!!!!!!!!!!!!!

		CALL :START_PROCESS_CHECK _skip_process_run
		if not defined _skip_process_run ( call :START_PROCESS_RUN %* )

		call :FILES_NAME_CLEAN_ALL
	ENDLOCAL
	echo.
	goto:eof


:START_PROCESS_CHECK
	REM CODIG CHECK, SI NO SE SUPERA Y HAY QUE HACER SKIP USAREMOS >> set "%~1=SKIP"
REM	if "%tfStreamV_NULL%" == "YES" (
REM		echo [MULTIPLEX] - [SKIP] - NO SE HAN DETECTADO NINGUNA PISTA DE VIDEO^!
REM		GOTO :eof
REM	)
	goto:eof


:START_PROCESS_RUN
	SETLOCAL
		set t_file_orig=%~1
		set t_file_dest=%~2
		set t_file_audio=%~3
		set t_file_video=%~4

		set map_ord=
		set metadata_all=
		set metadata_v=
		set metadata_a=
		set metadata_s=
		
		set RunFunction=%tPathffmpeg% -hide_banner -y -threads %ffmpeg_threads%
		
		if not "%t_file_video%" == "" (
			If exist "%t_file_video%" (
				set _vsource=%t_file_video%
			)	
		)
		if not defined _vsource ( set _vsource=%t_file_orig% )
		set _asource=%t_file_audio%


		set RunFunction=!RunFunction! -i "%_vsource%"
		set RunFunction=!RunFunction! -i "%_asource%"
		
rem		if "%tfStreamS_NULL%" == "NO" (
rem			If exist !tfProcesVideo! (
rem				set RunFunction=!RunFunction! -i !tPathFileOrig!
rem			)
rem		)
		
		
		
		set map_ord=!map_ord! -map 0:0
		set map_ord=!map_ord! -map 1:a:0
rem		if "%tfStreamS_NULL%" == "NO" (
rem			rem set map_ord=!map_ord! -map 0:m:language:spa
rem			If exist !tfProcesVideo! (
rem				set map_ord=!map_ord! -map 2:s
rem			) else (
rem				set map_ord=!map_ord! -map 0:s
rem			)
rem		)
		
		
		
		rem **** este ejemplo seria para solo la pista 0 de audio
		rem set metadata_s=!metadata_s! -metadata:s:a:0 title=""
		
		set metadata_all=-metadata title=""
		
		set metadata_v=!metadata_v! -metadata:s:v title=""
		set metadata_v=!metadata_v! -metadata:s:v language=und
		
		set metadata_a=!metadata_a! -metadata:s:a title=""
		set metadata_a=!metadata_a! -metadata:s:a language=spa
		
rem		if "%tfStreamS_NULL%" == "NO" (
rem			set metadata_s=!metadata_s! -metadata:s:s title=""
rem			set metadata_s=!metadata_s! -metadata:s:s language=spa
rem		)
		
		echo [MULTIPLEX] - PROCESANDO....
		
		set RunFunction=!RunFunction! !metadata_all! !metadata_a! !metadata_v! !metadata_s! !map_ord! -c:v copy -c:s copy -c:a copy -f %OutputVideoFormat% "%t_file_dest%"
		@call src\gen_func.cmd RUN_EXE
		(set RunFunction=)
		
	ENDLOCAL
	echo [MULTIPLEX] - [FINALIZADO]
	goto:eof


:: **** ELIMINAR ARCHIVOS
:FILES_REMOVE
	if not "%_debug%" == "YES" (
		CALL :FILES_REMOVE_PROCESS_V
		CALL :FILES_REMOVE_PROCESS_A
	)
	goto:eof

:FILES_REMOVE_PROCESS_V
	@call src\gen_func.cmd FUN_FILE_DELETE_FILE !tfProcesVideo!
	goto:eof

:FILES_REMOVE_PROCESS_A
	@call src\gen_func.cmd FUN_FILE_DELETE_FILE !tfProcesAudio!
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
		rem (set tfStreamS=)
	) else (
		rem set tfStreamS="%tPathProce%\%~n1_info_stream_sub.txt"
	)
	goto:eof

:: **** FUNCTIONS
:PRINT_DEBUG_INFO
	echo [SUBS] - tPathFileOrig:          %tPathFileOrig%
	echo [SUBS] - tPathFileConvrt:        %tPathFileConvrt%
	echo [SUBS] - tFileName:              %tFileName%
	echo [SUBS] - tfInfoffmpeg:           %tfInfoffmpeg%
	echo.
	pause
	goto:eof
