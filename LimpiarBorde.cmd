@echo off
cls
setlocal enabledelayedexpansion
title ClearBorde 3.0

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
set ffmpeg_border_detect_star=0
set ffmpeg_border_detect_dura=20

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
if DEFINED _error_falta_algo (
	echo.
	echo *** EXIT: ERROR CODE 2^^!
	pause
	exit /b 2
)



set OutputVideoFormat=matroska
set OutputVideoType=mkv
set tPathFileOrig=
set tPathFileConvrt=
set tFileName=


:: GLOBALES - AJUESTES DE RECODIFICACION
:: all_v_encoder = [copy|hevc_nvenc|libx265|h264_nvenc|libx264]
:: all_v_profile = [baseline|main|main10|etc...]
:: all_v_level = [4|5|5.2|etc...]
:: all_qmin = 0    		q minimo -> nvenc
:: all_qmax = 23   		q maximo -> nvenc
:: all_crv= 23      	-> libx265 y libx264
:: all_detect_borde = [NO|YES]
:: all_change_size = [NO|1920:-1|1280:-1]
:: all_a_encoder = [copy|aac_coder]
:: all_a_bitrate = [96K|192K|lo que quieras]
:: TODO: all_a_hz

set all_v_encoder=
set all_qmin=
set all_qmax=
set all_crv=
set all_detect_borde=
set all_change_size=
set all_v_profile=
set all_v_level=
set all_a_encoder=
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
	
	REM INFO: NOMBRE DEL ARCHIVO A PROCESAR CON SU PATH COMPLETO.
	set tPathFileOrig="%%~fi"
	
	REM INFO: NOMBRE DEL ARCHIVO YA PROCESADO CON SU PATH COMPLETO.
	set tPathFileConvrt="%tPathConve%\%%~ni.%OutputVideoType%"
	
	REM INFO: NOMBRE DEL ARCHIVO A PROCESAR SIN PATH, SOLO EL NOMBRE DEL ARCHIVO.
	set tFileName="%%~nxi"
	
	echo.
	echo ********************************
	echo [GLOBAL] - [INFO] - PROCESANDO: !tFileName!
	REM ******** DEBUG!!!!!!!!!!!!!!!!
	if "%_debug%" == "YES" ( CALL :PRINT_DEBUG_INFO )
	REM ******** DEBUG!!!!!!!!!!!!!!!!


	If exist !tPathFileConvrt! (
		echo [GLOBAL] - [SKIP] - YA SE HA PROCESADO^^!^^!
	) else (
		CALL :FILES_NAME_SET_ALL !tPathFileOrig!
		CALL :FILES_REMOVE

		REM GET INFO GENERAL DEL ARCHIVO CON FFMPEG Y OBTENEMOS LOS STREAM
		@call src\fun_ffmpeg.cmd GET_INFO !tPathFileOrig! !tfInfoffmpeg!

		call :READ_STREAM !tPathFileOrig! _read_stream

		if "!_read_stream!" == "1" (
			echo [GLOBAL] - [SKIP] - NO SE HAN DETECTADO NINGUNA STREAM EN EL ARCHIVO^^!^^!
		) else (
			REM **** DURACION DEL VIDEO
			@call src\fun_ffprobe.cmd GET_DURACION !tPathFileOrig! !tfInfoDuration! tDuration
			@call src\fun_ffprobe.cmd DURACION_FORMAT !tDuration! tDuration
			echo [GLOBAL] - [INFO] - DURACION: !tDuration!
			echo.
			
			@call src\process_sub.cmd FILES_NAME_SET_ALL !tPathFileOrig!
			@call src\process_audio.cmd FILES_NAME_SET_ALL !tPathFileOrig!
			@call src\process_video.cmd FILES_NAME_SET_ALL !tPathFileOrig!
			@call src\process_multiplex.cmd FILES_NAME_SET_ALL !tPathFileOrig!


			rem			call src\fun_ffmpeg.cmd COUNT_STREAM !tPathFileOrig! !tfStreamCountS! "Subtitle" _count_steam_sub
			rem			call src\fun_ffmpeg.cmd COUNT_STREAM !tPathFileOrig! !tfStreamCountA! "Audio" _count_steam_audio
			rem			call src\fun_ffmpeg.cmd COUNT_STREAM !tPathFileOrig! !tfStreamCountV! "Video" _count_steam_video


			set _stage=FS
			@call src\process_sub.cmd START_PROCESS !tPathFileOrig!

			set _stage=FA
			@call src\process_audio.cmd START_PROCESS !tPathFileOrig!
			

			REM :PRUEBOTRAVEZ
			set _stage=FV
			@call src\process_video.cmd START_PROCESS !tPathFileOrig!
			REM PAUSE
			REM GOTO PRUEBOTRAVEZ


			set _stage=FM
			@call src\process_multiplex.cmd START_PROCESS !tPathFileOrig! !tPathFileConvrt! !tfProcesAudio! !tfProcesVideo!

			REM DESACTIVAR PARA DEPURAR @@ DEBUG MODE @@
			if 1 == 2 (
				@call src\process_sub.cmd FILES_REMOVE
				@call src\process_audio.cmd FILES_REMOVE
				@call src\process_video.cmd FILES_REMOVE
				@call src\process_multiplex.cmd FILES_REMOVE
			) else (
				@call src\process_multiplex.cmd FILES_REMOVE_PROCESS_V
			)

			@call src\process_sub.cmd FILES_NAME_CLEAN_ALL
			@call src\process_audio.cmd FILES_NAME_CLEAN_ALL
			@call src\process_video.cmd FILES_NAME_CLEAN_ALL
			@call src\process_multiplex.cmd FILES_NAME_CLEAN_ALL

			echo [GLOBAL] - [INFO] - FINALIZADO PROCESADO
			echo ********************************
		)

		
		REM DESACTIVAR PARA DEPURAR @@ DEBUG MODE @@
		if 1 == 2 (
			if not "%_debug%" == "YES" ( CALL :FILES_REMOVE )
		)
		CALL :FILES_NAME_CLEAN_ALL
	)
	echo.
)

echo.
echo [GLOBAL] - [END] - TODOS LOS ARCHIVOS HAN SIDO PROCESADOS
pause
GOTO :eof
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
	echo [GLOBAL] - tPathFileConvrt ------ ^> %tPathFileConvrt%
	echo [GLOBAL] - tFileName ------------ ^> %tFileName%
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
