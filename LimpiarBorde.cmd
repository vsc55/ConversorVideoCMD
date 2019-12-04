@echo off
cls
setlocal enabledelayedexpansion
title ClearBorde 2.3

:: _stage > C = Config, G = Global, F = File
:VARIABLES
set _HACK_CHEKC_=1987
set _os_bitness=
set _debug=NO
set _debug_sa=NO
set _debug_sv=NO
set _stage=
set ffmpeg_bits=
set ffmpeg_threads=0
set ffmpeg_refs=4
set ffmpeg_fps=23.976
REM set ffmpeg_fps=25.000
set ffmpeg_cv=libx264
set ffmpeg_border_detect_star=0
set ffmpeg_border_detect_dura=20

set default_crf=21
set default_qmin=0
set default_qmax=23
set default_a_br=192k
set default_a_hz=44100
set default_a_process=ACCGAIN
rem set default_a_process=FFMPGE



REM PROFILE - CONFIG
REM set profile_default_animation=Y
set profile_default_animation=N




:CONFIGDEBUGMODE
If exist %~dp0debug_on (
	set _debug=YES
)
If exist %~dp0debug_stop_a (
	set _debug_sa=YES
)
If exist %~dp0debug_stop_v (
	set _debug_sv=YES
)





:CONFPROGSEGUNSO
set _os_bitness=64
IF %PROCESSOR_ARCHITECTURE% == x86 (
	IF NOT DEFINED PROCESSOR_ARCHITEW6432 Set _os_bitness=32
)
If %_os_bitness% == 32 (
	set ffmpeg_bits=x86
) ELSE If %_os_bitness% == 64 (
	set ffmpeg_bits=x64
)




:CONFIG_COLOR
cls
color 1e




if "%_debug%" == "YES" (
	echo.
	echo ***********************************************
	echo ************** DEBUG MODE ACTIVE **************
	echo ***********************************************
	echo.	
)



set _stage=C
set tPath=%~dp0
set tPathOrige=%~dp0Original
set tPathProce=%~dp0Proceso
set tPathConve=%~dp0Convertido
set tPathTools=%~dp0tools
set tPathFF=%tPathTools%\%ffmpeg_bits%
set tPathffmpeg="%tPathFF%\ffmpeg.exe"
set tPathffprobe="%tPathFF%\ffprobe.exe"
set tPathffplay="%tPathFF%\ffplay.exe"
set tPathaacgain="%tPathTools%\aacgain.exe"

set tURLBaseTools=https://raw.githubusercontent.com/vsc55/ConversorVideoCMD/master/tools


@call src\gen_func.cmd CHECK_DIR_AND_CREATE "%tPathProce%" _error_falta_algo
@call src\gen_func.cmd CHECK_DIR_AND_CREATE "%tPathConve%" _error_falta_algo
@call src\gen_func.cmd CHECK_DIR_AND_CREATE "%tPathTools%" _error_falta_algo
@call src\gen_func.cmd CHECK_DIR_AND_CREATE "%tPathFF%" _error_falta_algo
if DEFINED _error_falta_algo (
	echo.
	echo *** EXIT: ERROR CODE 1^!
	pause
	exit /b 1
)

@call src\gen_func.cmd CHECK_FILE_AND_FIX "%tPathffmpeg%" "%tURLBaseTools%/%ffmpeg_bits%/ffmpeg.exe" "ERROR: No se ha localizado el programa FFMPEG ^(%ffmpeg_bits%^)^^^^^^^!" _error_falta_algo
@call src\gen_func.cmd CHECK_FILE_AND_FIX "%tPathffprobe%" "%tURLBaseTools%/%ffmpeg_bits%/ffprobe.exe" "ERROR: No se ha localizado el programa FFPROBE ^(%ffmpeg_bits%^)^^^^^^^!" _error_falta_algo
@call src\gen_func.cmd CHECK_FILE_AND_FIX "%tPathffplay%" "%tURLBaseTools%/%ffmpeg_bits%/ffplay.exe" "ERROR: No se ha localizado el programa FFPLAY ^(%ffmpeg_bits%^)^^^^^^^!" _error_falta_algo
@call src\gen_func.cmd CHECK_FILE_AND_FIX "%tPathaacgain%" "%tURLBaseTools%/aacgain.exe" "No se ha localizado el programa AACGAIN^^^^^^^!" _error_falta_algo
if DEFINED _error_falta_algo (
	echo.
	echo *** EXIT: ERROR CODE 2^!
	pause
	exit /b 2
)



set OutputVideoFormat=matroska
set OutputVideoType=mkv
set tfInfoffmpeg=
set tfInfoBordeA=
set tfInfoBordeE=
set tfInfoBordeC=
set tfInfoSizeOrig=
set tfInfoDuration=
set tfInfoTestPlay=
set tfStreamV_NULL=
set tfStreamV=
set tfStreamA_NULL=
set tfStreamA=
set tfStreamA_A=
set tfStreamA_I=
set tfStreamS_NULL=
set tfStreamS=
set tfInfoFixVol=
set tfInfoFixVolR=
set tfInfoFixInitTime=
set tfInfoFixInitTimeR=
set tfProcesAudio=
set tfProcesAudioConcat=
set tfProcesAudioSilencio=
set tfProcesVideo=
set tPathFileOrig=
set tPathFileConvrt=
set tFileName=


:: GLOBALES - AJUESTES DE RECODIFICACION
:: ffmpeg_cv = [copy|hevc_nvenc|libx265|h264_nvenc|libx264]
:: all_v_profile = [baseline|main|main10|etc...]
:: all_v_level = [4|5|5.2|etc...]
:: all_qmin = 0    q minimo -> nvenc
:: all_qmax = 23   q maximo -> nvenc
:: all_crv= 23      -> libx265 y libx264
:: all_detect_borde = [NO|YES]
:: all_change_size = [NO|1920:-1|1280:-1]
:: all_a_bitrate = [96K|192K|lo que quieras]
:: TODO: all_a_hz, all_v_encoder que remplace a ffmpeg_cv

set all_v_encoder=
set all_qmin=
set all_qmax=
set all_crv=
set all_detect_borde=
set all_change_size=
set all_v_profile=
set all_v_level=
set all_a_bitrate=
set all_a_hz=
set all_profile=


:INIT_SELECT_PROFILE
set _stage=G
echo.
@call src\select_profile.cmd SELECT_PROFILE
echo.
@call src\select_profile.cmd PRINT_CONFIG_GLOBAL
echo.
if "!all_profile!" == "" (
	echo ERROR: No se ha seleccionado ningun perfil.
	exit
)
:SKIP_SELECT_PROFILE



for %%i in ("%tPathOrige%\*.avi" "%tPathOrige%\*.flv" "%tPathOrige%\*.mkv" "%tPathOrige%\*.mp4") do (
	
	set _stage=F
	set tfInfoffmpeg="%tPathProce%\%%~ni_info_ffmpeg.txt"
	set tfInfoBordeA="%tPathProce%\%%~ni_info_borde0.txt"
	set tfInfoBordeE="%tPathProce%\%%~ni_info_borde1.txt"
	set tfInfoBordeC="%tPathProce%\%%~ni_info_borde2.txt"
	set tfInfoSizeOrig="%tPathProce%\%%~ni_info_size_orig.txt"
	set tfInfoTestPlay="%tPathProce%\%%~ni_info_test_play.txt"
	set tfInfoDuration="%tPathProce%\%%~ni_info_duration.txt"
	set tfStreamAll="%tPathProce%\%%~ni_info_stream.txt"
	set tfStreamV="%tPathProce%\%%~ni_info_stream_video.txt"
	set tfStreamA="%tPathProce%\%%~ni_info_stream_audio.txt"
	set tfStreamA_A="%tPathProce%\%%~ni_info_stream_audio_A.txt"
	set tfStreamA_I="%tPathProce%\%%~ni_info_stream_audio_ID.txt"
	set tfStreamS="%tPathProce%\%%~ni_info_stream_sub.txt"
	set tfInfoFixVol="%tPathProce%\%%~ni_info_fix_vol.txt"
	set tfInfoFixVolR="%tPathProce%\%%~ni_info_fix_vol_r.txt"
	set tfInfoFixInitTime="%tPathProce%\%%~ni_info_fix_inittime.txt"
	set tfInfoFixInitTimeR="%tPathProce%\%%~ni_info_fix_inittime_r.txt"
	
	
	set tfProcesAudio="%tPathProce%\%%~ni.m4a"
	set tfProcesAudioConcat="%tPathProce%\%%~ni_concat.wav"
	set tfProcesAudioSilencio="%tPathProce%\%%~ni_silencio.m4a"
	
	
	set tfProcesVideo="%tPathProce%\%%~ni.mkv"
	if "%ffmpeg_cv%" == "h264_nvenc" (
rem		set tfProcesVideo="%tPathProce%\%%~ni.avc"
	) else if "%ffmpeg_cv%" == "hevc_nvenc" (
rem		set tfProcesVideo="%tPathProce%\%%~ni.hevc"
	) else if "%ffmpeg_cv%" == "libx264" (
rem		set tfProcesVideo="%tPathProce%\%%~ni.avc"
	) else if "%ffmpeg_cv%" == "libx265" (
rem		set tfProcesVideo="%tPathProce%\%%~ni.hevc"
	) else if "%ffmpeg_cv%" == "copy" (
		set tfProcesVideo=
	)
	
	
	
	
	
	REM INFO: NOMBRE DEL ARCHIVO A PROCESAR CON SU PATH COMPLETO.
	set tPathFileOrig=%2
	
	REM INFO: NOMBRE DEL ARCHIVO YA PROCESADO CON SU PATH COMPLETO.
	set tPathFileConvrt=%3
	
	REM INFO: NOMBRE DEL ARCHIVO A PROCESAR SIN PATH, SOLO EL NOMBRE DEL ARCHIVO.
	set tFileName=%1
	
	
	
	REM INFO: NOMBRE DEL ARCHIVO A PROCESAR CON SU PATH COMPLETO.
	set tPathFileOrig="%%~fi"
	
	REM INFO: NOMBRE DEL ARCHIVO YA PROCESADO CON SU PATH COMPLETO.
	set tPathFileConvrt="%tPathConve%\%%~ni.%OutputVideoType%"
	
	REM INFO: NOMBRE DEL ARCHIVO A PROCESAR SIN PATH, SOLO EL NOMBRE DEL ARCHIVO.
	set tFileName="%%~nxi"
	
	
	
	echo.
	echo ********************************
	echo [GLOBAL] - [INFO] - PROCESANDO: %%~nxi
	If exist !tPathFileConvrt! (
		echo [GLOBAL] - [SKIP] - YA SE HA PROCESADO^!
		echo.
	) else (
		
		@call src\gen_func.cmd FUN_FILE_DELETE_FILE !tfInfoffmpeg!
		@call src\gen_func.cmd FUN_FILE_DELETE_FILE !tfInfoDuration!
		
		REM GET INFO GENERAL DEL ARCHIVO CON FFMPEG
		set RunFunction=%tPathffmpeg% -i !tPathFileOrig!
		@call src\gen_func.cmd RUN_EXE 2 !tfInfoffmpeg!
		set RunFunction=
		
		
		REM **** DURACION DEL VIDEO
		set RunFunction=%tPathffprobe% -v error -show_entries format=duration -sexagesimal -of default=noprint_wrappers=1:nokey=1 !tPathFileOrig!
		@call src\gen_func.cmd RUN_EXE 1 !tfInfoDuration!
		set RunFunction=
		set /p tDuration=<!tfInfoDuration!
		for /f "delims=." %%A in ("!tDuration!") do set tDuration=%%~A
		echo [GLOBAL] - [INFO] - DURACION: !tDuration!
		echo.
		
		
		@call src\gen_func.cmd FUN_FILE_DELETE_FILE !tfStreamAll!
		@call src\gen_func.cmd FUN_FILE_DELETE_FILE !tfStreamS!
		@call src\gen_func.cmd FUN_FILE_DELETE_FILE !tfStreamA!
		@call src\gen_func.cmd FUN_FILE_DELETE_FILE !tfStreamV!
		
		set tfStreamS_NULL=YES
		set tfStreamA_NULL=YES
		set tfStreamV_NULL=YES
		
		findstr.exe /i /c:"Stream " !tfInfoffmpeg! > !tfStreamAll!
		
		findstr.exe /i /c:"Subtitle: " !tfStreamAll! > !tfStreamS!
		if not errorlevel 1 (set tfStreamS_NULL=NO)
		
		findstr.exe /i /c:"Audio: " !tfStreamAll! > !tfStreamA!
		if not errorlevel 1 (set tfStreamA_NULL=NO)
		
		findstr.exe /i /c:"Video: " !tfStreamAll! > !tfStreamV!
		if not errorlevel 1 (set tfStreamV_NULL=NO)
		
		if "!tfStreamS_NULL!" == "NO" (
			set _stage=FS
			rem call :ProcessSubFix
			rem echo.
		)
		if "!tfStreamA_NULL!" == "NO" (
			set _stage=FA
			@call src\audio_pro.cmd START_PROCESS
			echo.
		)
		if "!tfStreamV_NULL!" == "NO" (
			set _stage=FV
			call :ProcessVideoFix
			echo.
		)
		
		
		set _stage=FM
		call :ProcessMultiplexFiles
		echo.
		
		
		echo [GLOBAL] - [INFO] - FINALIZADO PROCESADO
		echo ********************************
		echo.
	)
)


echo.
echo [GLOBAL] - [END] - TODOS LOS ARCHIVOS HAN SIDO PROCESADOS
pause
GOTO :eof





:ProcessMultiplexFiles
	
	if "%tfStreamV_NULL%" == "YES" (
		echo [MULTIPLEX] - [SKIP] - NO SE HAN DETECTADO NINGUNA PISTA DE VIDEO^!
		GOTO :eof
	)
	If exist !tPathFileConvrt! (
		echo [MULTIPLEX] - [SKIP] - YA SE HA PROCESADO^!
		GOTO :eof
	)
	if not exist !tfProcesAudio! (
		echo [MULTIPLEX] - [STOP] - EL ARCHIVO DE LA PISTA DE AUDIO NO SE HA LOCALIZADO^!
		GOTO :eof
	)
	
	SETLOCAL
	echo [MULTIPLEX] - PROGRESO INICIANDO...
	
	set map_ord=
	set metadata_all=
	set metadata_v=
	set metadata_a=
	set metadata_s=
	
	set RunFunction=%tPathffmpeg% -hide_banner -y -threads %ffmpeg_threads%
	
	If exist !tfProcesVideo! (
		set RunFunction=!RunFunction! -i !tfProcesVideo!
	) else (
		set RunFunction=!RunFunction! -i !tPathFileOrig!
	)
	set RunFunction=!RunFunction! -i !tfProcesAudio!
	
	if "%tfStreamS_NULL%" == "NO" (
		If exist !tfProcesVideo! (
			set RunFunction=!RunFunction! -i !tPathFileOrig!
		)
	)
	
	
	
	set map_ord=!map_ord! -map 0:0
	set map_ord=!map_ord! -map 1:a:0
	if "%tfStreamS_NULL%" == "NO" (
		rem set map_ord=!map_ord! -map 0:m:language:spa
		If exist !tfProcesVideo! (
			set map_ord=!map_ord! -map 2:s
		) else (
			set map_ord=!map_ord! -map 0:s
		)
	)
	
	
	
	rem **** este ejemplo seria para solo la pista 0 de audio
	rem set metadata_s=!metadata_s! -metadata:s:a:0 title=""
	
	set metadata_all=-metadata title=""
	
	set metadata_v=!metadata_v! -metadata:s:v title=""
	set metadata_v=!metadata_v! -metadata:s:v language=und
	
	set metadata_a=!metadata_a! -metadata:s:a title=""
	set metadata_a=!metadata_a! -metadata:s:a language=spa
	
	if "%tfStreamS_NULL%" == "NO" (
		set metadata_s=!metadata_s! -metadata:s:s title=""
		set metadata_s=!metadata_s! -metadata:s:s language=spa
	)
	
	echo [MULTIPLEX] - PROCESANDO....
	
	set RunFunction=!RunFunction! !metadata_all! !metadata_a! !metadata_v! !metadata_s! !map_ord! -c:v copy -c:s copy -c:a copy -f %OutputVideoFormat% !tPathFileConvrt!
	@call src\gen_func.cmd RUN_EXE
	set RunFunction=
	
	
	if not "%_debug%" == "YES" (
		@call src\gen_func.cmd FUN_FILE_DELETE_FILE !tfProcesVideo!
		rem	@call src\gen_func.cmd FUN_FILE_DELETE_FILE !tfProcesAudio!
	)
	
	echo [MULTIPLEX] - FINALIZADO
	ENDLOCAL
	GOTO :eof







	





REM ***************************************************
REM ****           VIDEO - VIDEO - VIDEO           ****
REM ***************************************************

:ProcessVideoFix

	if "%_debug_sv%" == "YES" (
		rem ******** DEBUG!!!!!!!!!!!!!!!!
		echo [VIDEO] - tPathFileOrig:   %tPathFileOrig%
		echo [VIDEO] - tPathFileConvrt: %tPathFileConvrt%
		echo [VIDEO] - tFileName:       %tFileName%
		echo [VIDEO] - tfInfoffmpeg:    %tfInfoffmpeg%
		echo.
		pause
		GOTO :eof
		rem ******** DEBUG!!!!!!!!!!!!!!!!
	)

	if "%tfStreamV_NULL%" == "YES" (
		echo [VIDEO] - [SKIP] - NO SE HAN DETECTADO NINGUNA PISTA DE VIDEO^!
		GOTO :eof
	)
	If exist !tPathFileConvrt! (
		echo [VIDEO] - [SKIP] - YA SE HA PROCESADO^!
		GOTO :eof
	)
	If exist !tfProcesVideo! (
		@CHOICE /C:YN /d N /t 10 /M "[VIDEO] - LA PISTA DE VIDEO YA SE HA PROCESADO ¨QUIERES VOLVER A PROCESARLA [AUDO **NO** EN 10 SEG]"
		IF Errorlevel 2 GOTO VIDEO_CHOICE_PROCESAR_OTRA_VEZ_NO
		IF Errorlevel 1 GOTO VIDEO_CHOICE_PROCESAR_OTRA_VEZ_SI
		GOTO :eof
		
		:VIDEO_CHOICE_PROCESAR_OTRA_VEZ_NO
		echo [VIDEO] - [SKIP] - PISTA DE VIDEO YA PROCESADA^!
		GOTO :eof
		
		:VIDEO_CHOICE_PROCESAR_OTRA_VEZ_SI
		@call src\gen_func.cmd FUN_FILE_DELETE_FILE !tfProcesVideo!
	)
	REM ** SI SE DEFINE COPY NO HAY QUE HACER NADA CON EL VIDEO POR LO QUE SALTAMOS A LA EJECUCION DE FFMPEG **
	if "%ffmpeg_cv%" == "copy" ( 
		echo [VIDEO] - [SKIP] - SE COPIAR LA PISTA ORIGINAL^!
		GOTO :eof
	)	
	
	
	SETLOCAL
	
	echo [VIDEO] - [PROGRESS] - INICIANDO...
	
	REM *** ELIMINA LAS COMILLAS AL COMIENZO Y AL FINAL DEL NOMBRE DEL ARCHIVO
	@call src\gen_func.cmd FUN_CLEAR_TRIM_COMILLAS tFileName
	
	
	@call src\gen_func.cmd FUN_FILE_DELETE_FILE !tfInfoBordeA!
	@call src\gen_func.cmd FUN_FILE_DELETE_FILE !tfInfoBordeE!
	@call src\gen_func.cmd FUN_FILE_DELETE_FILE !tfInfoBordeC!
	@call src\gen_func.cmd FUN_FILE_DELETE_FILE !tfInfoSizeOrig!
	@call src\gen_func.cmd FUN_FILE_DELETE_FILE !tfInfoTestPlay!
	REM TODO: PENDIENTE COMPROBAR SI LA FUNCION DE BORRADO FUNCIONA TAMBIEN CON COMODINES.
	del /f /q "ffmpeg2pass-0.*" 2>nul
	
	
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
	cscript /nologo VideoSizeReal_Crop_ClearLog.vbs !tfInfoBordeE! !tfInfoBordeC!
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
	
	for /f %%i in ('cscript /nologo VideoSizeReal_Size.vbs "!tSizeReal_crop!"') do (
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
	GOTO :eof




rem *** INFO FFMPEG *** > "-map_chapters -1" evita que se copien los capitulos del archivo original.
