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
		echo [VIDEO] - [SKIP] - NO SE HA ESPECIFICADO NINGUN ARCHIVO A PREOCESAR^^!^^!
		echo.
		goto:eof
	)
	If not exist "%~1" (
		echo [VIDEO] - [SKIP] - EL ARCHIVO A PROCESAR YA NO EXISTE^^!^^!
		echo.
		goto:eof
	)

	echo [VIDEO] - [PROGRESS] - INICIANDO...
	SETLOCAL
		CALL :FILES_NAME_SET_ALL "%~1"
		:: ******** DEBUG!!!!!!!!!!!!!!!!
		if "!_debug_sv!" == "YES" (
			CALL :PRINT_DEBUG_INFO
			goto:eof
		)
		:: ******** DEBUG!!!!!!!!!!!!!!!!

		call :READ_STREAM "%~1" _read_stream
		if "!_read_stream!" == "1" (
			echo [VIDEO] - [SKIP] - NO SE HAN DETECTADO NINGUNA PISTA DE VIDEO^^!^^!
			set _skip_process_run=SKIP
		) else ( CALL :START_PROCESS_CHECK _skip_process_run )

		if not defined _skip_process_run ( call :START_PROCESS_RUN %* )
		
		call :FILES_NAME_CLEAN_ALL
	ENDLOCAL
	echo.
	goto:eof
	

:START_PROCESS_CHECK
	if exist !tfProcesVideo! (
		@CHOICE /C:YN /d N /t 10 /M "[VIDEO] - LA PISTA DE VIDEO YA SE HA PROCESADO ¨QUIERES VOLVER A PROCESARLA [AUDO **NO** EN 10 SEG]"
		IF Errorlevel 2 (
			echo [VIDEO] - [SKIP] - PISTA DE VIDEO YA PROCESADA^^!^^!
			set "%~1=SKIP"
			GOTO :eof
		)
		CALL src\gen_func.cmd FUN_FILE_DELETE_FILE !tfProcesVideo!
	)

	REM ** SI SE DEFINE COPY NO HAY QUE HACER NADA CON EL VIDEO, POR LO QUE SALTAMOS A LA EJECUCION DE FFMPEG **
	if "%ffmpeg_cv%" == "copy" ( 
		echo [VIDEO] - [SKIP] - SE COPIAR LA PISTA ORIGINAL^^!
		set "%~1=SKIP"
		GOTO :eof
	)

	:: TODO: PENDIENTE VALIDAR SI TODOS LOS PARAMETROS GLOBALES SE HAN DEFINIDO Y SON CORRECTOS.
	goto:eof


:START_PROCESS_RUN
	SETLOCAL
		set t_file=%~1
		call :FILES_REMOVE_TEMP
	

		set tSizeReal_crop=
		set tSizeReal_size=
		set tSizeOrig_size=
		set tWidthOrig=
	
	
	
		REM ******************************
		REM *** GET INFO FILE ORIGINAL ***
		REM ******************************
		
	REM **** Resolucion orginal
	set RunFunction=%tPathffprobe% -v error -select_streams v:0 -show_entries stream=width,height -of csv=s=x:p=0 !tPathFileOrig!
 	@call src\gen_func.cmd RUN_EXE 1 !tfInfoSizeOrig!
 	set RunFunction=
	set /p tSizeOrig_size=<!tfInfoSizeOrig!
	REM ******************************
	REM ******************************
	
	
	
	
	
	
	REM ********************************************************
	REM *** DETECCION DEL TAMA¥O DEL VIDEO SIN BORDES NEGROS ***
	REM ********************************************************
	
	if "%all_detect_borde%" == "NO" (
		echo [VIDEO] - [SKIP] - NO SE EFECTUA DETECCION DE BORDES NEGROS [GLOBAL]
		goto RESIZE_VIDEO_INIT
	)
	@CHOICE /C:YN /d Y /t 10 /M "[VIDEO] - ¨DESEAS DETECTAR BORDE NEGRO SUPERIOR HE INFERIOR [AUTO **SI** EN 10 SEG]"
	IF Errorlevel 2 GOTO RESIZE_VIDEO_INIT
	IF Errorlevel 1 GOTO DETECT_BORDER_INIT
	GOTO :eof
	
	
	:DETECT_BORDER_INIT
	echo [VIDEO] - [PROGRESS] - DETECTANDO TAMA¥O REAL SIN BORDES...
	set tDetectStar=%ffmpeg_border_detect_star%
	set tDetectDura=%ffmpeg_border_detect_dura%
	
	@call src\gen_func.cmd GetWidthByResolution x %tSizeOrig_size% tWidthOrig
	
	:DETECT_BORDER_INIT_SCAN
	set tDetectNewScan=NONE
	set tSizeReal_crop=
	set /a tDetectStop=!tDetectStar! + !tDetectDura!
	
	
	echo [VIDEO] - [PROGRESS] - INICIANDO SCAN DE BORDES DE !tDetectDura! SEGUNDOS EMPEZANDO DESDE EL SEGUNDO !tDetectStar!...
	set RunFunction=%tPathffmpeg% -ss !tDetectStar! -to !tDetectStop! -i !tPathFileOrig! -vf cropdetect -f null -
 	@call src\gen_func.cmd RUN_EXE 2 !tfInfoBordeA!
 	set RunFunction=
	
	
	
	
	echo [VIDEO] - [PROGRESS] - ANALIZANDO RESULTADOS...
	findstr.exe  /i /c:"Parsed_cropdetect_" !tfInfoBordeA! > !tfInfoBordeE!
	cscript /nologo src/VideoSizeReal_Crop_ClearLog.vbs !tfInfoBordeE! !tfInfoBordeC!
	IF errorlevel 3 echo "ERROR 3"
	IF errorlevel 2 echo "ERROR 2"
	IF errorlevel 1 echo "ERROR 1"
	
	if "%_debug%" == "YES" (
		echo [VIDEO] - [DEBUG] - STOP DEPUES DE ANALIZAR RESULTADOS ^!^!^!^!
		PAUSE
	)
	
	
	for /F "usebackq tokens=*" %%i in (!tfInfoBordeC!) do (
		FOR /f "tokens=1,2 delims=-" %%a IN ("%%i") do (
			rem RES: %%a
			rem count: %%b
			for /f "delims=:" %%A in ("%%a") do (
				if %%~A == !tWidthOrig! (
					if %%b GTR 5 (
						echo [VIDEO]   -- MUESTRA: %%a  -- REPETIDA: %%b 
						set tSizeReal_crop=%%a
					) else (
						if "%_debug%" == "YES" (echo [VIDEO] - [DEBUG] - ORIG ^(!tWidthOrig!^) - MUESTRA ^(%%A^) - COUNT ^(%%b^) - MUESTRA_ALL ^(%%i^)   - NO VALIDA^!^!^!^!^!)
					)
				) else (
					if "%_debug%" == "YES" (echo [VIDEO] - [DEBUG] - ORIG ^(!tWidthOrig!^) - MUESTRA ^(%%a^) - MUESTRA_ALL ^(%%i^)   - NO VALIDA^!^!^!^!^!)
				)
			)
		)
	)
	
	
	echo.
	if "!tSizeReal_crop!" == "" (
		SET tDetectNewScan=YES
		echo [VIDEO] - NO SE ENCONTRO NINGUNA MUESTRA VALIDA, A¥ADA NUEVOS DATOS DE MUESTREO:
	) else (
		
		@CHOICE /C:YN /M "[VIDEO] - ¨DESEAS HACER OTRO MUESTREO CON OTROS VALORES"
		IF Errorlevel 2 SET tDetectNewScan=NO
		IF Errorlevel 1 SET tDetectNewScan=YES
	)
	
	if /i "!tDetectNewScan!" equ "YES" (
		set /p InputNewtDetectStar="[VIDEO] - INICIAR SCAN A LOS [!tDetectStar! SEGUDNOS]:"
		if /i "!InputNewtDetectStar!" neq "" (
			set tDetectStar=!InputNewtDetectStar!
			echo [VIDEO] - [MODIFICADO] INICIARA EL SCAN DESDE EL SEGUNDO: !tDetectStar!
		)
		set /p InputNewtDetectDura="[VIDEO] - DURACION DEL SCAN [!tDetectDura! SEGUNDOS]:"
		if /i "!InputNewtDetectDura!" neq "" (
			set tDetectDura=!InputNewtDetectDura!
			echo [VIDEO] - [MODIFICADO] - LA DURACION DEL SCAN ES AHORA DE: !tDetectDura! SEGUNDOS
		)
		echo.
		goto :DETECT_BORDER_INIT_SCAN
	)
	
	
	REM TODO: PENDIENTE DETECTAR QUE RESULTADO TIENE UN COUNT MAYOUR PARA USAR ESE COMO SELECCION POR DEFECTO.
	echo.
	set /p InputNewSize="[VIDEO] - CONFIRMA QUE LE NUEVO TAMA¥O ES [!tSizeReal_crop!]:"
	if /i "!InputNewSize!" neq "" (
		set tSizeReal_crop=!InputNewSize!
		echo [VIDEO] - [MODIFICADO] - EL NUEVO TAMA¥O SE HA DEFINIDO EN: !tSizeReal_crop!
	)
	
	for /f %%i in ('cscript /nologo src/VideoSizeReal_Size.vbs "!tSizeReal_crop!"') do (
		set tSizeReal_size=%%i
	)
	echo.
	
	REM ********************************************************
	REM ********************************************************
	
	
	
	
	
	
	REM **************************************************************
	REM *** DETECTAR SI EL TAMA¥O ORIGINAL Y EL NUEVO SON EL MISMO ***
	REM **************************************************************
	
	if "!tSizeReal_size!" == "!tSizeOrig_size!" (
		@CHOICE /C:YN /M "[VIDEO] - ¨NO SE HAN DETECTADO BORDES, DESEAS CANCELAR LA RECODIFICACION?"
		IF Errorlevel 2 GOTO NOBORDE_NO
		IF Errorlevel 1 GOTO NOBORDE_YES
		GOTO :eof

		:NOBORDE_YES
			echo [VIDEO] - [SKIP] EN ESTE ARCHIVO NO SE HAN DETECTADO BORDES, SE OMITE^!^!^!^!^!^!^!^!^!
			goto END_VIDEO_FIX

		:NOBORDE_NO
			set tSizeReal_crop=
			echo.
	) 
	
	if not "!tSizeReal_crop!"  == "" (
		echo [VIDEO] - [TEST] - PLAY VERSION ORIGNAL....
		set RunFunction=%tPathffplay% !tPathFileOrig!
		@call src\gen_func.cmd RUN_EXE
		set RunFunction=
		
		echo [VIDEO] - [TEST] - PLAY VERSION RECORTADA....
		set RunFunction=%tPathffplay% -vf crop=!tSizeReal_crop! !tPathFileOrig!
		if "%_debug%" == "YES" (
			@call src\gen_func.cmd RUN_EXE
		) else (
			@call src\gen_func.cmd RUN_EXE 3 !tfInfoTestPlay!
		)
		set RunFunction=
	)
	
	REM **************************************************************
	REM **************************************************************
	
	
	
	
	
	
	REM *********************************************************
	REM *** DEFINIMOS SI DESEAMOS CAMBIAR EL TAMA¥O DEL VIDEO ***
	REM *********************************************************
	
	:RESIZE_VIDEO_INIT
	
	if not "!tSizeReal_crop!" == "" (
		@call src\gen_func.cmd GetWidthByResolution : %tSizeReal_crop% tWidthOrig
	) else (
		@call src\gen_func.cmd GetWidthByResolution x %tSizeOrig_size% tWidthOrig
		set tSizeReal_size=%tSizeOrig_size%
	)
	
	set OutNewSize=
	if "%all_change_size%" == "NO" (
		echo [VIDEO] - [SKIP] - NO SE EFECTUA CAMBIO DE TAMA¥O [GLOBAL]
		echo.
	) else if "%all_change_size%" == "" (
		echo.
		@call src\opt_encoder.cmd SELECT_NEW_SIZE !tWidthOrig! OutNewSize
		echo.
	) else (
		set OutNewSize=%all_change_size%
	)
	
	REM *********************************************************
	REM *********************************************************
	


	
	:INIT_VIDEO_RECODIFICATION
	
	set RunFunction=%tPathffmpeg% -hide_banner -y -threads %ffmpeg_threads% -i !tPathFileOrig! -an -sn -map_chapters -1
	set video_f=
	set video_e=
	
	set map_ord=
	set metadata_v=
	
	set opt_v_q=
	set opt_v_qmin=
	set opt_v_qmax=
	set opt_v_CRF=
	set opt_v_profile=
	set opt_v_level=
	
	set metadata_v=!metadata_v! -metadata title=""
	set metadata_v=!metadata_v! -metadata:s:v title=""
	set metadata_v=!metadata_v! -metadata:s:v language=und
	
	set map_ord=-map 0:0
	
	if not "!tSizeReal_crop!" == "" (
		set video_f=crop=!tSizeReal_crop!
	)
	if not "!OutNewSize!" == "" (
		if not "!video_f!" == "" (
			set video_f=!video_f!, scale=!OutNewSize!
		) else (
			set video_f=scale=!OutNewSize!
		)
	)
	if not "!video_f!" == "" (set video_f=-vf !video_f!)
	
	if "%ffmpeg_cv%" == "h264_nvenc" (
	
		REM ****** H264 - GPU ******
		REM ****** VERSION POR COMPRESION CONSTANT RATE FACTOR (CRF)
		REM ******
		REM ****** INFO -> ffmpeg -hide_banner -h encoder=h264_nvenc
		
		
		set opt_v_profile=
		if "%all_v_profile%" == "SKIPSELECT" (
			echo [VIDEO] - [SKIP] - SET PROFILE ENCODE [GLOBAL]
		) else  (
			set opt_v_profile=%all_v_profile%
		)
		
		set opt_v_level=
		if "%all_v_level%" == "SKIPSELECT" (
			echo [VIDEO] - [SKIP] - SET LEVEL RESTRICTION [GLOBAL]
		) else  (
			set opt_v_level=%all_v_level%
		)
		
		set opt_v_qmin=%all_qmin%
		set opt_v_qmax=%all_qmax%
		if "!opt_v_qmin!" == "!opt_v_qmax!" (set opt_v_q=!opt_v_qmax!)
		
		set video_e=-c:v %ffmpeg_cv%
		set video_e=!video_e! -pix_fmt yuv420p 
		set video_e=!video_e! -preset slow
		
		if "!opt_v_q!" == "" (
			if not "!opt_v_qmin!" == "" (set video_e=!video_e! -qmin !opt_v_qmin!)
			if not "!opt_v_qmax!" == "" (set video_e=!video_e! -qmax !opt_v_qmax!)
		) else (
			set video_e=!video_e! -rc constqp -qp !opt_v_q!
		)
		
		set video_e=!video_e! -rc-lookahead:v 32
		set video_e=!video_e! -refs %ffmpeg_refs%
		set video_e=!video_e! -r %ffmpeg_fps%
		set video_e=!video_e! -movflags +faststart
		
		set OutputVideoFormat="avc"
		
rem 	set video_e=-c:v %ffmpeg_cv% -preset llhq
rem		if not "!opt_v_profile!" == "" (set video_e=!video_e! -profile:v !opt_v_profile!)
rem		if not "!opt_v_level!" == ""   (set video_e=!video_e! -level:v !opt_v_level!)
		
		
		rem set video_e=-c:v %ffmpeg_cv% -preset llhq -profile:v !opt_v_profile! -level !opt_v_level! -rc-lookahead:v 32 -refs %ffmpeg_refs% -movflags +faststart -qmin !opt_v_qmin! -qmax !opt_v_qmax!
		rem set video_e=-c:v %ffmpeg_cv% -preset llhq -rc-lookahead:v 32 -refs %ffmpeg_refs% -movflags +faststart -qmin !opt_v_qmin! -qmax !opt_v_qmax!
		
	) else if "%ffmpeg_cv%" == "hevc_nvenc" (
	
		REM ****** H265 - GPU ******
		REM ****** VERSION POR COMPRESION CONSTANT RATE FACTOR (CRF)
		REM ******
		REM ****** INFO -> ffmpeg -hide_banner -h encoder=hevc_nvenc
		
		set opt_v_profile=
		if "%all_v_profile%" == "SKIPSELECT" (
			echo [VIDEO] - [SKIP] - SET PROFILE ENCODE [GLOBAL]
		) else  (
			set opt_v_profile=%all_v_profile%
		)
		
		set opt_v_level=
		if "%all_v_level%" == "SKIPSELECT" (
			echo [VIDEO] - [SKIP] - SET LEVEL RESTRICTION [GLOBAL]
		) else  (
			set opt_v_level=%all_v_level%
		)
		
		set opt_v_qmin=%all_qmin%
		set opt_v_qmax=%all_qmax%
		if "!opt_v_qmin!" == "!opt_v_qmax!" (set opt_v_q=!opt_v_qmax!)
		
		set video_e=-c:v %ffmpeg_cv%
		set video_e=!video_e! -tier high
		
		if "%all_v_profile%" == "main10" (
			set video_e=!video_e! -pix_fmt p010le
		) else (
			set video_e=!video_e! -pix_fmt yuv420p
		)
		
		set video_e=!video_e! -preset slow
		
		if not "!opt_v_profile!" == "" (set video_e=!video_e! -profile:v !opt_v_profile!)
		if not "!opt_v_level!" == ""   (set video_e=!video_e! -level:v !opt_v_level!)
		
		if "!opt_v_q!" == "" (
			if not "!opt_v_qmin!" == "" (set video_e=!video_e! -qmin !opt_v_qmin!)
			if not "!opt_v_qmax!" == "" (set video_e=!video_e! -qmax !opt_v_qmax!)
		) else (
			set video_e=!video_e! -rc constqp -qp !opt_v_q!
		)
		
		set video_e=!video_e! -rc-lookahead:v 32
		set video_e=!video_e! -refs %ffmpeg_refs%
		set video_e=!video_e! -r %ffmpeg_fps%
		set video_e=!video_e! -movflags +faststart
		
		set OutputVideoFormat="hevc"
		
rem		set video_e=-c:v %ffmpeg_cv% -preset llhq
		
		
		
		REM !!!!!!!!!!!!!! PENDIENTE AFINAR QMAX PARA QUE NO OCUPEN TANTO LOS VIDEOS!!!!!!!!!!!!! qmin 16 - qmax 23
		REM set opt_v_profile=main
		REM set opt_v_level=4.1
		REM set video_e=-c:v %ffmpeg_cv% -preset llhq -profile:v !opt_v_profile! -level !opt_v_level! -rc-lookahead:v 32 -refs %ffmpeg_refs% -movflags +faststart -qmin !opt_v_qmin! -qmax !opt_v_qmax!
		
	) else if "%ffmpeg_cv%" == "libx264" (
	
		REM **** CPU - H264
		REM ****** VERSION POR COMPRESION CONSTANT RATE FACTOR (CRF)
		REM ******
		REM ****** INFO -> ffmpeg -hide_banner -h encoder=libx264
		set OutputVideoFormat="avc"
		set opt_v_CRF=%default_crf%
		set video_e=-c:v %ffmpeg_cv% -pix_fmt yuv420p -crf !opt_v_CRF! -preset slow -refs %ffmpeg_refs% -r %ffmpeg_fps% -movflags +faststart
		
	) else if "%ffmpeg_cv%" == "libx265" (
	
		REM **** CPU - H265
		REM ****** VERSION POR COMPRESION CONSTANT RATE FACTOR (CRF)
		REM ******
		REM ****** INFO -> ffmpeg -hide_banner -h encoder=libx265
		set OutputVideoFormat="hevc"
rem		set opt_v_CRF=%default_crf%
		set opt_v_CRF=%all_qmin%

		set video_e=-c:v %ffmpeg_cv% -pix_fmt yuv420p
		
		if not "!opt_v_CRF!" == "" (
			set video_e=!video_e! -crf !opt_v_CRF!
		)
		
		set video_e=!video_e! -preset slow
		
		if not "!opt_v_profile!" == "" (set video_e=!video_e! -profile:v !opt_v_profile!)
		if not "!opt_v_level!" == ""   (set video_e=!video_e! -level:v !opt_v_level!)
		
		set video_e=!video_e! -refs %ffmpeg_refs% -r %ffmpeg_fps% -movflags +faststart
	)
	
	REM **** PARTHCE TEMPORA PARA PROBAR EL ARCHIVO TERMPORAL EN FORMATO MKV
	set OutputVideoFormat="matroska"
	
	
	
	echo.
	@CHOICE /C:YN /d !profile_default_animation! /t 10 /M "[VIDEO] - ES UN VIDEO DE ANIMACION [AUTO **!profile_default_animation!** EN 10 SEG]"
	IF Errorlevel 2 GOTO VIDEO_CHOICE_IS_ANIMATION_NO
	IF Errorlevel 1 GOTO VIDEO_CHOICE_IS_ANIMATION_SI
	GOTO :eof
	
	:VIDEO_CHOICE_IS_ANIMATION_SI
	set video_e=!video_e! -tune animation
	echo [VIDEO] - [TUNE] - ANIMATION: SI
	GOTO VIDEO_CHOICE_IS_ANIMATION_END

	:VIDEO_CHOICE_IS_ANIMATION_NO
	echo [VIDEO] - [TUNE] - ANIMATION: NO
	GOTO VIDEO_CHOICE_IS_ANIMATION_END
	
	:VIDEO_CHOICE_IS_ANIMATION_END
	echo.
	
	
	echo.
	echo [VIDEO] - [INFO] - IN:
	echo [VIDEO] - [INFO] -- TAMA¥O INICIAL: !tSizeReal_size!
	echo [VIDEO] - [INFO]
	echo [VIDEO] - [INFO] - OUT:
	echo [VIDEO] - [INFO] -- ENCODING: %ffmpeg_cv%
	echo [VIDEO] - [INFO] -- FORMATO SALIDA: %OutputVideoFormat% [%OutputVideoType%]
	if not "!tSizeReal_crop!" == "" (
		echo [VIDEO] - [INFO] -- RECORTAR A: !tSizeReal_crop!
	)
	if not "!OutNewSize!" ==  "" (
		echo [VIDEO] - [INFO] -- REDIMENSAION A: !OutNewSize!
	)
	if not "!opt_v_profile!" == "" (
		echo [VIDEO] - [INFO] -- ENCODING PROFILE: !opt_v_profile!
	)
	if not "!opt_v_level!" == "" (
		echo [VIDEO] - [INFO] -- ENCODING LEVEL: !opt_v_level!
	)
	if not "!opt_v_CRF!" == "" (
		echo [VIDEO] - [INFO] -- CFR FIJO A: !opt_v_CRF!
	) else (
		if not "!opt_v_q!" == "" (
			echo [VIDEO] - [INFO] -- CFR FIJO A: !opt_v_q!
		) else (
			if not "!opt_v_qmin!!opt_v_qmax!" == "" (
				echo [VIDEO] - [INFO] -- CFR DINAMICO:
				if not "!opt_v_qmin!" == "" (
					echo [VIDEO] - [INFO] ---- QMIN: !opt_v_qmin!
				)
				if not "!opt_v_qmax!" == "" (
					echo [VIDEO] - [INFO] ---- QMAX: !opt_v_qmax!
				)
			)
		)
	)
	
	echo.
	echo [VIDEO] - PROCESANDO....
	
	set RunFunction=!RunFunction! !metadata_v! !video_f! !video_e! !map_ord! -f %OutputVideoFormat% !tfProcesVideo!
	@call src\gen_func.cmd RUN_EXE
	set RunFunction=
	
	
	:END_VIDEO_FIX
	
	echo [VIDEO] - FINALIZADO
	ENDLOCAL
	

	goto:eof



:: **** ELIMINAR ARCHIVOS
:FILES_REMOVE
	if not "%_debug%" == "YES" (
		@call src\gen_func.cmd FUN_FILE_DELETE_FILE !tfStreamV!
		call :FILES_REMOVE_TEMP
	)
	goto:eof

:FILES_REMOVE_TEMP
	@call src\gen_func.cmd FUN_FILE_DELETE_FILE !tfInfoBordeA!
	@call src\gen_func.cmd FUN_FILE_DELETE_FILE !tfInfoBordeE!
	@call src\gen_func.cmd FUN_FILE_DELETE_FILE !tfInfoBordeC!
	@call src\gen_func.cmd FUN_FILE_DELETE_FILE !tfInfoSizeOrig!
	@call src\gen_func.cmd FUN_FILE_DELETE_FILE !tfInfoTestPlay!
	CALL :FILES_REMOVE_FFMPEG2PASS
	goto:eof

:FILES_REMOVE_FFMPEG2PASS
	REM TODO: PENDIENTE COMPROBAR SI LA FUNCION DE BORRADO FUNCIONA TAMBIEN CON COMODINES.
	del /f /q "ffmpeg2pass-0.*" 2>nul
	goto:eof

:: **** CONTROL VARIABLES FILES
:FILES_NAME_CLEAN_ALL
	CALL :FILES_NAME_CLEAN
	CALL :FILES_NAME_TEMP_CLEAN
	goto:eof

:FILES_NAME_CLEAN
	CALL :FILES_NAME_SET
	goto:eof

:FILES_NAME_TEMP_CLEAN
	call :FILES_NAME_TEMP_SET
	goto:eof

:FILES_NAME_SET_ALL
	CALL :FILES_NAME_SET %*
	CALL :FILES_NAME_TEMP_SET %*
	goto:eof

:FILES_NAME_SET
	if "%~1" == "" (
		(set tfStreamV=)
		(set tfProcesVideo=)
	) else (
		set tfStreamV="%tPathProce%\%~n1_info_stream_video.txt"
		set tfProcesVideo="%tPathProce%\%~n1.mkv"
	)
	goto:eof

:FILES_NAME_TEMP_SET
	if "%~1" == "" (
		(set tfInfoBordeA=)
		(set tfInfoBordeE=)
		(set tfInfoBordeC=)
		(set tfInfoSizeOrig=)
		(set tfInfoTestPlay=)
	) else (
		set tfInfoBordeA="%tPathProce%\%~n1_info_borde0.txt"
		set tfInfoBordeE="%tPathProce%\%~n1_info_borde1.txt"
		set tfInfoBordeC="%tPathProce%\%~n1_info_borde2.txt"
		set tfInfoSizeOrig="%tPathProce%\%~n1_info_size_orig.txt"
		set tfInfoTestPlay="%tPathProce%\%~n1_info_test_play.txt"
	)
	goto:eof


:: **** FUNCIONES
:PRINT_DEBUG_INFO
	echo [VIDEO] - tPathFileOrig:     %tPathFileOrig%
	echo [VIDEO] - tPathFileConvrt:   %tPathFileConvrt%
	echo [VIDEO] - tfInfoffmpeg:      %tfInfoffmpeg%

	echo [VIDEO] - tfStreamV:         %tfStreamV%
	echo [VIDEO] - tfProcesVideo:     %tfProcesVideo%
	echo [VIDEO] - tfInfoBordeA:      %tfInfoBordeA%
	echo [VIDEO] - tfInfoBordeE:      %tfInfoBordeE%
	echo [VIDEO] - tfInfoBordeC:      %tfInfoBordeC%
	echo [VIDEO] - tfInfoSizeOrig:    %tfInfoSizeOrig%
	echo [VIDEO] - tfInfoTestPlay:    %tfInfoTestPlay%
	echo.
	pause
	goto:eof

:READ_STREAM
	SETLOCAL
		call :FILES_NAME_SET_ALL "%~1"
		findstr.exe /i /c:"Video: " !tfStreamAll! > !tfStreamV!
		set error=%errorlevel%
		call :FILES_NAME_CLEAN_ALL
	ENDLOCAL & (
		set "%~2=%error%"
	)
	goto:eof