@echo off
cls
setlocal enabledelayedexpansion
title ClearBorde 3.0

:: _stage > C = Config, G = Global, F = File, SKIP_E = File Out Exist, SKIP_L = File Bloqueado
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
set ffmpeg_border_detect_star=120
set ffmpeg_border_detect_dura=120

set default_crf=21
set default_qmin=1
set default_qmax=23
set default_a_br=192k
set default_a_hz=44100
set default_a_process=ACCGAIN
rem set default_a_process=FFMPGE
set default_a_encoder=aac_coder
set default_v_encoder=hevc_nvenc




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
set tPathControls="%tPathTools%\controls.exe"

set tURLBaseTools=https://raw.githubusercontent.com/vsc55/ConversorVideoCMD/master/tools


@call src\gen_func.cmd CHECK_DIR_AND_CREATE "%tPathProce%" _error_falta_algo
@call src\gen_func.cmd CHECK_DIR_AND_CREATE "%tPathConve%" _error_falta_algo
@call src\gen_func.cmd CHECK_DIR_AND_CREATE "%tPathTools%" _error_falta_algo
@call src\gen_func.cmd CHECK_DIR_AND_CREATE "%tPathFF%" _error_falta_algo
if DEFINED _error_falta_algo (
	echo.
	echo *** EXIT: ERROR CODE 1^^!
	pause
	exit /b 1
)

@call src\gen_func.cmd CHECK_FILE_AND_FIX "%tPathffmpeg%" "%tURLBaseTools%/%ffmpeg_bits%/ffmpeg.exe" "ERROR: No se ha localizado el programa FFMPEG ^(%ffmpeg_bits%^)^^^^^^^!" _error_falta_algo
@call src\gen_func.cmd CHECK_FILE_AND_FIX "%tPathffprobe%" "%tURLBaseTools%/%ffmpeg_bits%/ffprobe.exe" "ERROR: No se ha localizado el programa FFPROBE ^(%ffmpeg_bits%^)^^^^^^^!" _error_falta_algo
@call src\gen_func.cmd CHECK_FILE_AND_FIX "%tPathffplay%" "%tURLBaseTools%/%ffmpeg_bits%/ffplay.exe" "ERROR: No se ha localizado el programa FFPLAY ^(%ffmpeg_bits%^)^^^^^^^!" _error_falta_algo
@call src\gen_func.cmd CHECK_FILE_AND_FIX "%tPathaacgain%" "%tURLBaseTools%/aacgain.exe" "No se ha localizado el programa AACGAIN^^^^^^^!" _error_falta_algo
@call src\gen_func.cmd CHECK_FILE_AND_FIX "%tPathControls%" "%tURLBaseTools%/controls.exe" "No se ha localizado el programa CONTROLS^^^^^^^!" _error_falta_algo
if DEFINED _error_falta_algo (
	echo.
	echo *** EXIT: ERROR CODE 2^^!
	pause
	exit /b 2
)


REM DESACTIVAMOS EL BOTON X DE LA VENTANA PARA QUE NO SE PUEDA CERRAR
%tPathControls% false



set OutputVideoFormat=matroska
set OutputVideoType=mkv
set tPathFileOrig=
set tPathFileOrigLock=
set tPathFileConvrt=
set tFileName=


:: GLOBALES - AJUESTES DE RECODIFICACION
:: all_v_encoder = [copy|hevc_nvenc|libx265|h264_nvenc|libx264]
:: all_v_profile = [baseline|main|main10|etc...]
:: all_v_level = [4|5|5.2|etc...]
:: all_qmin = 0    		q minimo -> nvenc
:: all_qmax = 23   		q maximo -> nvenc
:: all_crf= 23      	-> libx265 y libx264
:: all_detect_borde = [NO|YES]
:: all_change_size = [NO|1920:-1|1280:-1]
:: all_a_encoder = [copy|aac_coder]
:: all_a_bitrate = [96K|192K|lo que quieras]
:: TODO: all_a_hz

set all_v_encoder=
set all_qmin=
set all_qmax=
set all_crf=
set all_detect_borde=
set all_change_size=
set all_v_profile=
set all_v_level=
set all_a_encoder=
set all_a_bitrate=
set all_a_hz=
set all_profile=


:INIT_MAIN
echo.

REM ============================================================
REM  MODO AUTOMATICO (preparar/procesar):
REM   - Si hay algun archivo sin .job (y sin convertir) -> FASE PREPARAR (preguntas)
REM   - Despues, en la misma ventana -> FASE WORKER: codifica los preparados.
REM   - Puedes abrir varias ventanas: cuando todos tienen .job, cada una entra
REM     directa como worker y se reparten los archivos por el lock (mkdir atomico).
REM ============================================================

REM ---- Clasificar: hay algun archivo POR PREPARAR (sin .job y sin convertir)? ----
set _need_prepare=0
for %%i in ("%tPathOrige%\*.avi" "%tPathOrige%\*.flv" "%tPathOrige%\*.mp4" "%tPathOrige%\*.mov" "%tPathOrige%\*.mkv") do (
	if not exist "%tPathConve%\%%~ni_fix.%OutputVideoType%" (
		if not exist "%tPathProce%\%%~ni.job" ( set "_need_prepare=1" )
	)
)

REM ---- FASE PREPARAR ----
if "!_need_prepare!" == "1" (
	set _stage=G
	echo.
	@call src\select_profile.cmd SELECT_PROFILE
	echo.
	@call src\select_profile.cmd PRINT_CONFIG_GLOBAL
	echo.
	if "!all_profile!" == "" (
		echo ERROR: No se ha seleccionado ningun perfil.
		pause
		exit /b 1
	)
	echo.
	echo [GLOBAL] - [PREPARAR] - GENERANDO CONFIGURACION DE LOS ARCHIVOS...
	for %%i in ("%tPathOrige%\*.avi" "%tPathOrige%\*.flv" "%tPathOrige%\*.mp4" "%tPathOrige%\*.mov" "%tPathOrige%\*.mkv") do CALL :PREPARE_FILE "%%~fi" "%%~ni"
	echo.
	echo [GLOBAL] - [PREPARAR] - CONFIGURACION COMPLETADA.
)

REM ---- FASE WORKER ----
set _stage=F
echo.
echo [GLOBAL] - [WORKER] - BUSCANDO ARCHIVOS PREPARADOS PARA CODIFICAR...
:WORK_SCAN
set _did=0
for %%i in ("%tPathOrige%\*.avi" "%tPathOrige%\*.flv" "%tPathOrige%\*.mp4" "%tPathOrige%\*.mov" "%tPathOrige%\*.mkv") do CALL :WORK_FILE "%%~fi" "%%~ni"
if "!_did!" == "1" goto WORK_SCAN

echo.
echo [GLOBAL] - [END] - NO QUEDAN ARCHIVOS LIBRES POR PROCESAR
pause
GOTO :eof


:PREPARE_FILE
	REM :PREPARE_FILE  <fullpath> <name>
	set "tPathFileOrig=%~1"
	set "tName=%~2"
	set "tOut=%tPathConve%\%~2_fix.%OutputVideoType%"
	set "tJob=%tPathProce%\%~2.job"
	set "tJobTmp=%tPathProce%\%~2.job.tmp"
	if exist "%tOut%" goto:eof
	if exist "%tJob%" goto:eof
	echo.
	echo ================================================
	echo [PREPARAR] - ARCHIVO: %~2
	CALL :FILES_NAME_SET_ALL "%tPathFileOrig%"
	if "%_debug%" == "YES" ( CALL :PRINT_DEBUG_INFO )
	@call src\fun_ffmpeg.cmd GET_INFO "%tPathFileOrig%" %tfInfoffmpeg%
	call :READ_STREAM "%tPathFileOrig%" _read_stream
	if "%_read_stream%" == "1" (
		echo [PREPARAR] - [SKIP] - SIN STREAMS DETECTADOS
		CALL :FILES_NAME_CLEAN_ALL
		goto:eof
	)
	REM --- cabecera del job: perfil congelado (autosuficiente para el worker) ---
	> "%tJobTmp%" echo all_v_encoder=%all_v_encoder%
	>>"%tJobTmp%" echo all_v_profile=%all_v_profile%
	>>"%tJobTmp%" echo all_v_level=%all_v_level%
	>>"%tJobTmp%" echo all_qmin=%all_qmin%
	>>"%tJobTmp%" echo all_qmax=%all_qmax%
	>>"%tJobTmp%" echo all_crf=%all_crf%
	>>"%tJobTmp%" echo all_a_encoder=%all_a_encoder%
	>>"%tJobTmp%" echo all_a_bitrate=%all_a_bitrate%
	>>"%tJobTmp%" echo all_a_hz=%all_a_hz%
	>>"%tJobTmp%" echo all_change_size=%all_change_size%
	REM --- preguntas por archivo (cada script anade sus claves j_) ---
	@call src\process_video.cmd ASK "%tPathFileOrig%" "%tJobTmp%"
	@call src\process_audio.cmd ASK "%tPathFileOrig%" "%tJobTmp%"
	REM --- commit atomico: renombrar tmp -> job ---
	move /y "%tJobTmp%" "%tJob%" >nul
	echo [PREPARAR] - [OK] - JOB CREADO: %~2.job
	CALL :FILES_NAME_CLEAN_ALL
	goto:eof


:WORK_FILE
	REM :WORK_FILE  <fullpath> <name>
	set "tPathFileOrig=%~1"
	set "tName=%~2"
	set "tOut=%tPathConve%\%~2_fix.%OutputVideoType%"
	set "tJob=%tPathProce%\%~2.job"
	set "tLock=%tPathProce%\%~2.lock"
	if exist "%tOut%" goto:eof
	if not exist "%tJob%" goto:eof
	REM --- reclamo atomico: mkdir falla si el lock ya existe (otro worker lo tiene) ---
	mkdir "%tLock%" 2>nul
	if errorlevel 1 goto:eof
	set _did=1
	echo.
	echo ================================================
	echo [WORKER] - CODIFICANDO: %~2
	CALL :LOAD_JOB "%tJob%"
	CALL :FILES_NAME_SET_ALL "%tPathFileOrig%"
	if "%_debug%" == "YES" ( CALL :PRINT_DEBUG_INFO )
	@call src\process_audio.cmd FILES_NAME_SET_ALL "%tPathFileOrig%"
	@call src\process_video.cmd FILES_NAME_SET_ALL "%tPathFileOrig%"
	@call src\process_sub.cmd FILES_NAME_SET_ALL "%tPathFileOrig%"
	@call src\process_multiplex.cmd FILES_NAME_SET_ALL "%tPathFileOrig%"
	REM --- AUDIO ---
	if not "%j_a_skip%" == "" (
		echo [AUDIO] - [SKIP] - %j_a_skip%
	) else (
		@call src\process_audio.cmd RUN "%tPathFileOrig%" "%j_a_id%" "%j_a_chan%" "%j_sync%"
	)
	REM --- VIDEO ---
	if not "%j_v_skip%" == "" (
		echo [VIDEO] - [SKIP] - %j_v_skip%
	) else (
		@call src\process_video.cmd RUN "%tPathFileOrig%" "%j_crop%" "%j_resize%" "%j_anim%"
	)
	REM --- MULTIPLEX ---
	@call src\process_multiplex.cmd START_PROCESS "%tPathFileOrig%" "%tOut%" %tfProcesAudio% %tfProcesVideo%
	@call src\process_multiplex.cmd FILES_REMOVE_PROCESS_V
	CALL :FILES_NAME_CLEAN_ALL
	if exist "%tOut%" (
		@call src\gen_func.cmd FUN_FILE_DELETE_FILE "%tJob%"
		echo [WORKER] - [OK] - FINALIZADO: %~2
	) else (
		echo [WORKER] - [ERR] - NO SE GENERO LA SALIDA, SE REINTENTARA: %~2
	)
	rmdir /s /q "%tLock%" 2>nul
	goto:eof


:LOAD_JOB
	REM :LOAD_JOB <jobfile> -> carga cada clave=valor como variable de entorno
	for /f "usebackq tokens=1* delims==" %%a in ("%~1") do set "%%a=%%b"
	goto:eof


REM exit /b 0



:: **** ELIMINAR ARCHIVOS
:FILES_REMOVE
	@call src\gen_func.cmd FUN_FILE_DELETE_FILE !tfStreamAll!
	@call src\gen_func.cmd FUN_FILE_DELETE_FILE !tfInfoDuration!
	@call src\gen_func.cmd FUN_FILE_DELETE_FILE !tfInfoffmpeg!

	@call src\gen_func.cmd FUN_FILE_DELETE_FILE !tfStreamCountS!
	@call src\gen_func.cmd FUN_FILE_DELETE_FILE !tfStreamCountA!
	@call src\gen_func.cmd FUN_FILE_DELETE_FILE !tfStreamCountV!
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
		(set tfInfoffmpeg=)
		(set tfStreamAll=)
		(set tfInfoDuration=)
	) else (
		set tfInfoffmpeg="%tPathProce%\%~n1_info_ffmpeg.txt"
		set tfStreamAll="%tPathProce%\%~n1_info_stream.txt"
		set tfInfoDuration="%tPathProce%\%~n1_info_duration.txt"
	)
	goto:eof

:: **** FUNCIONES
:PRINT_DEBUG_INFO
	echo.
	echo [GLOBAL] ********** DEBUG **********
	echo [GLOBAL] - tPathFileOrig -------- ^> %tPathFileOrig%
	echo [GLOBAL] - tLock ---------------- ^> %tLock%
	echo [GLOBAL] - tOut ----------------- ^> %tOut%
	echo [GLOBAL] - tName ---------------- ^> %tName%
	echo [GLOBAL] 
	echo [GLOBAL] - tfInfoffmpeg --------- ^> %tfInfoffmpeg%
	echo [GLOBAL] - tfStreamAll ---------- ^> %tfStreamAll%
	echo [GLOBAL] - tfInfoDuration ------- ^> %tfInfoDuration%
	echo [GLOBAL] ********** DEBUG **********
	echo.
	goto:eof

:READ_STREAM
	SETLOCAL
		call :FILES_NAME_SET_ALL "%~1"
		findstr.exe /i /c:"Stream " !tfInfoffmpeg! > !tfStreamAll!
		set error=%errorlevel%
		call :FILES_NAME_CLEAN_ALL
	ENDLOCAL & (
		set "%~2=%error%"
	)
	goto:eof






rem *** INFO FFMPEG *** > "-map_chapters -1" evita que se copien los capitulos del archivo original.
