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
	echo [AUDIO] - PROCESO INICIANDO...
	if "%~1" == "" (
		echo [AUDIO] - [SKIP] - NO SE HA ESPECIFICADO NINGUN ARCHIVO A PREOCESAR^^!^^!
	) else If not exist "%~1" (
		echo [AUDIO] - [SKIP] - EL ARCHIVO A PROCESAR YA NO EXISTE^^!^^!
	) else (
		SETLOCAL
			CALL :FILES_NAME_SET_ALL "%~1"

			REM ******** DEBUG!!!!!!!!!!!!!!!!
			if "%_debug%" == "YES" ( CALL :PRINT_DEBUG_INFO )
			REM ******** DEBUG!!!!!!!!!!!!!!!!

			CALL :START_PROCESS_CHECK _skip_process_run "%~1"
			if not defined _skip_process_run ( CALL :START_PROCESS_RUN %* )
			
			CALL :FILES_REMOVE_FIX_SILENCIO
			CALL :FILES_NAME_CLEAN_ALL
		ENDLOCAL
	)
	echo.
	goto:eof


:START_PROCESS_CHECK
	CALL :READ_STREAM "%~2" _read_stream
	if "!_read_stream!" == "1" (
		echo [AUDIO] - [SKIP] - NO SE HA DETECTADO NINGUNA PISTA DE AUDIO^^!^^!
		set "%~1=SKIP"
		GOTO :eof
	)
	if "%all_a_encoder%" == "copy" (
		echo [AUDIO] - [SKIP] - SE COPIARA LA PISTA ORIGINAL
		set "%~1=SKIP"
	)
	if exist !tfProcesAudio! (
		@CHOICE /C:YN /d N /t 10 /M "[AUDIO] - LA PISTA DE AUDIO YA SE HA PROCESADO ¨QUIERES VOLVER A PROCESARLA [AUTO **NO** EN 10 SEG]"
		IF Errorlevel 2 (
			echo [AUDIO]
			echo [AUDIO] - [SKIP] - PISTA DE AUDIO YA PROCESADA
			set "%~1=SKIP"
			GOTO :eof
		)
		echo [AUDIO]
		CALL :FILES_REMOVE_FIX
	)
	CALL :GET_ID _audio_id_pista
	if "!_audio_id_pista!" == "" (
		echo [AUDIO] - [ERR^^!] - NO SE HA DETECTADO NINGUNA PISTA DE AUDIO CORRECTA^^!^^!^^!
		set "%~1=ERROR"
		GOTO :eof
	)

	if "!all_a_bitrate!" == "" (
		echo [AUDIO] - [ERR^^!] - NO SE HA DEFINIDO BITRATE^^!^^!^^!
		set "%~1=ERROR"
		GOTO :eof
	)
	
	REM TODO: PENDIENTE VALIDAR SI TODOS LOS PARAMETROS GLOBALES SE HAN DEFINIDO Y SON CORRECTOS.
	goto:eof


:START_PROCESS_RUN
	SETLOCAL
		set t_file=%~1
		CALL :FILES_REMOVE_TEMP

		REM ***************************
		REM *** BUSCAMOS PISTA DE AUDIO/VIDEO
		REM ***************************
		(set t_audio_id_pista=)
		CALL :GET_ID t_audio_id_pista


		REM *********************************************
		REM *** COMPROBAMOS SI EL AUDIO ESTA SINCRONIZADO
		REM *********************************************
		echo|set /p="[AUDIO] - [SYNC] - [SCAN] - COMPROBANDO SI EL AUDIO Y EL VIDEO INICIAN A LA VEZ..."

		(set t_sync_v_a=)
		(set t_sync_v_a_status=)
		CALL :CHECK_SYNC_AUDIO_VIDEO "%t_file%" "!t_audio_id_pista!" t_sync_v_a t_sync_v_a_status

		REM t_sync_v_a_status:
		REM -- OK - TODO OK
		REM -- NO - AUDIO NO SINCRONIZADO, HAY QUE A¥ADIR SILENCIO
		REM -- ERROR1 -> NO SE HA LOCALIZADO pts_time
		REM -- ERROR2 -> NO SE HA CREADO EL ARCHIVO DE AUDIO CON EL SILENCIO A¥ADIDO

		if "!t_sync_v_a_status!" == "OK" (
			echo|set /p="[OK]"
			echo.
		) else if "!t_sync_v_a_status!" == "NO" (
			echo|set /p="[^!^!]"
			echo.
			echo [AUDIO] - [SYNC]
			
			call :SELECT_SYNC_SEG !t_sync_v_a! t_sync_v_a
			if "!t_sync_v_a!" == "0" (
				(set t_sync_v_a_status=OK)
			) else (
				echo [AUDIO] - [SYNC] - [FIX ] - SE A¥ADIRA AL INICIO UN SILENCIO DE: !t_sync_v_a! SEG
				CALL :FILES_REMOVE_FIX_SILENCIO

				REM ***** INI - CODIGO DE PRUEBAS - NO ES NECESARIO YA QUE EL SILENCIO SE GENERA DIRECTAMENTE AL EXTRAER LA PISTA DE AUDIO *****
				echo|set /p="[AUDIO] - [SYNC] - [FIX ] - GENERANDO SILENCIO..."
				CALL :FIX_SILENCIO_GEN "!t_sync_v_a!" "!all_a_hz!" "stereo" !tfProcesAudioSilencio!
				echo|set /p="  [OK]"
				echo.
				REM ***** END - CODIGO DE PRUEBAS - NO ES NECESARIO YA QUE EL SILENCIO SE GENERA DIRECTAMENTE AL EXTRAER LA PISTA DE AUDIO *****


				REM ***** AVISO!!!! ****** TENEMOS QUE GENERAR PRIMERO EL WAV YA QUE SI LO GENERAMOS DIRECTAMENTE EN AAC EN LA UNION DEL SILENCION CON 
				REM                        LA PISTA DE AUDIO A¥ADE UNOS SEGUNDOS MAS DE TIEMPO Y SE DESINCRONIZA.
				REM                        https://trac.ffmpeg.org/ticket/7846

				echo|set /p="[AUDIO] - [SYNC] - [FIX ] - A¥ADIENDO SILENCIO A LA PISTA DE AUDIO..."
				CALL :FIX_SILENCIO_ADD "!t_sync_v_a!" "!all_a_hz!" "stereo" "!t_audio_id_pista!" !tPathFileOrig! !tfProcesAudioSilencio! !tfProcesAudioConcat!
					If exist !tfProcesAudioConcat! (
					echo|set /p="[OK]"
					echo.
					(set t_sync_v_a_status=OK)
				) else (
					echo|set /p="[ERR^!^!]"
					echo.
					CALL :FILES_REMOVE_FIX_SILENCIO
					(set t_sync_v_a_status=ERROR2)
				)
			)
		) else (
			if "!t_sync_v_a_status!" == "ERROR1" ( 
				echo|set /p="[ERR] - NO SE HA LOCALIZADO pts_time^!^!^!^!
			) else (
				echo|set /p="[!t_sync_v_a_status!]^!^!^!^!"
			)
			echo.
		)

		if "!t_sync_v_a_status!" == "OK" (
			REM ******************************************
			REM ******************************************
			REM ******************************************
			REM TODO: Pendiente configurar numero de canales

			set t_audio_ccanales=
			findstr.exe /i /c:"5.1" !tfStreamA_A! >nul
			if not errorlevel 1 (
				set t_audio_ccanales=5.1 A STEREO
			) else (
				set t_audio_ccanales=STEREO
			)
			echo [AUDIO]
			CALL :FIX_VOLUMEN "!t_audio_id_pista!" "!all_a_bitrate!" "!all_a_hz!" "!t_audio_ccanales!" !tPathFileOrig! !tfProcesAudioConcat! !tfProcesAudio! t_audio_fix_vol t_audio_fix_vol_status
		)

	ENDLOCAL
	echo [AUDIO]
	echo [AUDIO] - [FINALIZADO]
	goto:eof



:GET_ID
	cscript /nologo src/AudioGetID.vbs !tfStreamA! !tfStreamA_A! !tfStreamA_I!
	SETLOCAL
		set /p id_pista=<!tfStreamA_I!
	ENDLOCAL & (
		set "%~1=%id_pista%"
	)
	goto:eof

:: **** CONTROL Y NORMALIZACION DE LA SINCRONIZACION DE LA PISTA DE AUDIO
:FIX_SILENCIO_GEN
	SETLOCAL
		set t_sec_add=%~1
		set t_hz=%~2
		set t_channel=%~3
		set t_file=%~4

		set RunExternal=%tPathffmpeg% -hide_banner -y -threads %ffmpeg_threads% -y
		set RunExternal=!RunExternal! -filter_complex "aevalsrc=0:d=!t_sec_add!:sample_rate=!t_hz!:channel_layout=!t_channel!"
		set RunExternal=!RunExternal! "!t_file!"
		CALL src\gen_func.cmd RUN_SUB_EXE
	ENDLOCAL
	goto:eof

:FIX_SILENCIO_ADD
	SETLOCAL
		set t_sec_add=%~1
		set t_hz=%~2
		set t_channel=%~3
		set t_id_pista=%~4
		set t_file_orig=%~5
		set t_file_silen=%~6
		set t_file_concat=%~7

		set RunExternal=%tPathffmpeg% -hide_banner -y -threads %ffmpeg_threads% -y
		set RunExternal=!RunExternal! -i "!t_file_orig!" -vn -sn -map_chapters -1
		set RunExternal=!RunExternal! -filter_complex "aevalsrc=0|:d=!t_sec_add!:sample_rate=!t_hz!:channel_layout=!t_channel![silence];[silence][0:a]concat=n=2:v=0:a=!t_id_pista![out]" -map [out]
		set RunExternal=!RunExternal! "!t_file_concat!"
		@call src\gen_func.cmd RUN_SUB_EXE
	ENDLOCAL
	goto:eof



:SELECT_SYNC_SEG
	SETLOCAL
		set t_sync_v_a=%~1
		@CHOICE /C:YN /d Y /t 10 /M "[AUDIO] - [SYNC] - [FIX ] - ¨DESEAS USAR EL VALOR DETECTADO DE [%t_sync_v_a% SEG] - [AUTO **SI** EN 10 SEG]"
		IF Errorlevel 2 (
			set /p NewVal="[AUDIO] - [SYNC] - [FIX ] - CUANTO SILENCIO HAY QUE A¥ADIR AL INCIO [%t_sync_v_a% SEG]:"
			if DEFINED NewVal (
				if not "%t_sync_v_a%" == "!NewVal!" (
					REM TODO: PENDIENTE VALIDAR SI NewVal ES UN NUMERO CORRECTO!!!
					(set t_sync_v_a=!NewVal!)
				)
			)
		)
	ENDLOCAL & (
		set "%~2=%t_sync_v_a%"
	)
	goto:eof


:CHECK_SYNC_AUDIO_VIDEO
	SETLOCAL
		set t_file=%~1
		set t_id_pista_a=%~2
		(set t_sync_va=)
		(set t_return=)

		set RunExternal=%tPathffmpeg% -hide_banner -y -threads %ffmpeg_threads% -i "!t_file!" -af "ashowinfo" -map 0:!t_id_pista_a! -y -f alaw -frames:a !t_id_pista_a! nul
		CALL src\gen_func.cmd RUN_SUB_EXE 2 !tfInfoFixInitTime!
		
		cscript /nologo src/AudioGetInitTime.vbs !tfInfoFixInitTime! !tfInfoFixInitTimeR!
		(set /p t_sync_va=<!tfInfoFixInitTimeR!)

		if "!t_sync_va!" == "" ( (set t_return=ERROR1) )
		if /i !t_sync_va! neq 0 ( (set t_return=NO) ) else ( (set t_return=OK) )
	ENDLOCAL&(
		set "%~3=%t_sync_va%"
		set "%~4=%t_return%"
	)
	goto:eof


:: **** CONTROL DEL VOLUMEN Y NORMALIZACION
:FIX_VOLUMEN
	:: call :FIX_VOLUMEN "!t_audio_id_pista!" "!all_a_bitrate!" "!all_a_hz!" "!t_audio_ccanales!" !tPathFileOrig! !tfProcesAudioConcat! !tfProcesAudio! t_audio_fix_vol t_audio_fix_vol_status
	(set t_audio_fix_vol=)
	(set t_audio_fix_vol_status=)
	IF "%default_a_process%" == "ACCGAIN" ( 
		CALL :FIX_VOLUMEN_AACGAIN %*
	) else (
		CALL :FIX_VOLUMEN_FFMPEG %*
	)
	goto:eof

:FIX_VOLUMEN_FFMPEG
	:: TODO: Pendiente probar despues de la adaptacion!!
	SETLOCAL
		set t_id_pista=%~1
		set t_bitrate=%~2
		set t_hz=%~3
		set t_ccanales=%~4
		set t_file_orig=%~5
		set t_file_concat=%~6
		set t_file_out=%~7

		(set t_audio_fix_vol=)
		(set t_return=OK)

		
		echo [AUDIO] - [VOLF] - [SCAN] - ANALIZANDO VOLUMEN...
		set RunExternal=%tPathffmpeg% -hide_banner -y -threads %ffmpeg_threads%
		if exist "!t_file_concat!" (
			set RunExternal=!RunExternal! -i "!t_file_concat!"
			set RunExternal=!RunExternal! -map 0:a
		) else (
			set RunExternal=!RunExternal! -i "!t_file_orig!"
			set RunExternal=!RunExternal! -map 0:!t_id_pista!
			set RunExternal=!RunExternal! -vn -sn -map_chapters -1
		)
		set RunExternal=!RunExternal! -af volumedetect -f null -
		CALL src\gen_func.cmd RUN_SUB_EXE 2 !tfInfoFixVol!
		cscript /nologo src/AudioGetMaxVol.vbs !tfInfoFixVol! !tfInfoFixVolR!
		(set /p t_audio_fix_vol=<!tfInfoFixVolR!)

		if "!t_audio_fix_vol!" == "" (
			echo [AUDIO] - [VOLF] - [ERR^^!] - NO SE HA LOCALIZADO max_volume^^!^^!^^!^^!
			(set t_return=ERROR1)
		) else (
			if /i !t_audio_fix_vol! leq 0 (
				echo [AUDIO] - [VOLF] - [SKIP] - IGNORANDO AJUSTE RECOMENDADO [!t_audio_fix_vol!]
				set t_audio_fix_vol=0
			) else (
				echo [AUDIO] - [VOLF] - [FIX ] - APLICANDO AJUSTE RECOMENDADO [!t_audio_fix_vol!]...
			)
		)

		if "!t_return!" == "OK" (
			echo [AUDIO] - [VOLF] - [REC ] - RECODIFICANDO AUDIO !t_ccanales! CON UN BITRATE [!t_bitrate!]...

			set RunExternal=%tPathffmpeg% -hide_banner -threads %ffmpeg_threads% -y

			if exist "!t_file_concat!" (
				set RunExternal=!RunExternal! -i "!t_file_concat!"
				if "!t_audio_fix_vol!" == "0" (
					set RunExternal=!RunExternal! -map 0:a
				) else (
					set RunExternal=!RunExternal! -filter_complex "[0:a]volume=!t_audio_fix_vol!dB:precision=fixed[out]" -map [out]
				)
			) else (
				set RunExternal=!RunExternal! -i "!t_file_orig!"
				set RunExternal=!RunExternal! -vn -sn -map_chapters -1
				if "!t_audio_fix_vol!" == "0" (
					set RunExternal=!RunExternal! -map 0:!t_id_pista!
				) else (
					set RunExternal=!RunExternal! -filter_complex "[0:!t_id_pista!]volume=!t_audio_fix_vol!dB:precision=fixed[out]" -map [out]
				)
			)

			if not "!t_bitrate!" == "" (
				set RunExternal=!RunExternal! -b:a !t_bitrate!
			)

			REM set RunExternal=!RunExternal! -c:a aac -strict experimental

			set RunExternal=!RunExternal! -ar !t_hz!
			set RunExternal=!RunExternal! -ac 2
			set RunExternal=!RunExternal! -aac_coder twoloop

			set RunExternal=!RunExternal! "!t_file_out!"

			CALL src\gen_func.cmd RUN_SUB_EXE
		)

	ENDLOCAL & (
		set "%~8=%t_audio_fix_vol%"
		set "%~9=%t_return%"
	)
	goto:eof


:FIX_VOLUMEN_AACGAIN
	SETLOCAL
		set t_id_pista=%~1
		set t_bitrate=%~2
		set t_hz=%~3
		set t_ccanales=%~4
		set t_file_orig=%~5
		set t_file_concat=%~6
		set t_file_out=%~7

		(set t_audio_fix_vol=)
		(set t_return=OK)

		echo [AUDIO] - [VOLF] - [REC ] - RECODIFICANDO AUDIO [PISTA !t_id_pista!] !t_ccanales! CON UN BITRATE [!t_bitrate!]...

		set RunExternal=%tPathffmpeg% -hide_banner -y -threads %ffmpeg_threads% -y
	
		if exist "!t_file_concat!" (
			set RunExternal=!RunExternal! -i "!t_file_concat!"
			set RunExternal=!RunExternal! -map 0:a
		) else (
			set RunExternal=!RunExternal! -i "!t_file_orig!"
			set RunExternal=!RunExternal! -vn -sn -map_chapters -1
			set RunExternal=!RunExternal! -map 0:!t_id_pista!
		)
	
		if not "!t_bitrate!" == "" (
			set RunExternal=!RunExternal! -b:a !t_bitrate!
		)
	
		rem set RunExternal=!RunExternal! -c:a aac
		set RunExternal=!RunExternal! -ar !t_hz!
		set RunExternal=!RunExternal! -ac 2
		set RunExternal=!RunExternal! -aac_coder twoloop
	
		set RunExternal=!RunExternal! "!t_file_out!"
		CALL src\gen_func.cmd RUN_SUB_EXE
	

		echo [AUDIO] - [VOLF] - [SCAN] - ANALIZANDO VOLUMEN...
 		set RunExternal=%tPathaacgain% /q "!t_file_out!"
		@call src\gen_func.cmd RUN_SUB_EXE 1 !tfInfoFixVol!
		cscript /nologo src/AudioGetMaxVolAACGain.vbs !tfInfoFixVol! !tfInfoFixVolR!
		(set /p t_audio_fix_vol=<!tfInfoFixVolR!)
	
		if /i !t_audio_fix_vol! gtr 0 (
			echo [AUDIO] - [VOLF] - [FIX ] - APLICANDO AJUSTE RECOMENDADO [!t_audio_fix_vol!]...
			set RunExternal=%tPathaacgain% /r /c /q "!t_file_out!"
			CALL src\gen_func.cmd RUN_SUB_EXE
		) else (
			echo [AUDIO] - [VOLF] - [SKIP] - IGNORANDO AJUSTE RECOMENDADO [!t_audio_fix_vol!]
			(set t_return=SKIP)
		)

	ENDLOCAL & (
		set "%~8=%t_audio_fix_vol%"
		set "%~9=%t_return%"
	)
	goto:eof


:: **** ELIMINAR ARCHIVOS
:FILES_REMOVE
	if not "%_debug%" == "YES" (
		REM @call src\gen_func.cmd FUN_FILE_DELETE_FILE !tfProcesAudioConcat!
		REM @call src\gen_func.cmd FUN_FILE_DELETE_FILE !tfProcesAudioSilencio!
		@call src\gen_func.cmd FUN_FILE_DELETE_FILE !tfStreamA!
		@call src\gen_func.cmd FUN_FILE_DELETE_FILE !tfStreamCountA!
		REM CALL :FILES_REMOVE_FIX
		call :FILES_REMOVE_TEMP
	)
	goto:eof

:FILES_REMOVE_TEMP
	@call src\gen_func.cmd FUN_FILE_DELETE_FILE !tfStreamA_A!
	@call src\gen_func.cmd FUN_FILE_DELETE_FILE !tfStreamA_I!
	@call src\gen_func.cmd FUN_FILE_DELETE_FILE !tfInfoFixVol!
	@call src\gen_func.cmd FUN_FILE_DELETE_FILE !tfInfoFixVolR!
	@call src\gen_func.cmd FUN_FILE_DELETE_FILE !tfInfoFixInitTime!
	@call src\gen_func.cmd FUN_FILE_DELETE_FILE !tfInfoFixInitTimeR!
	CALL :FILES_REMOVE_FIX_SILENCIO
	goto:eof

:FILES_REMOVE_FIX
	CALL src\gen_func.cmd FUN_FILE_DELETE_FILE !tfProcesAudio!
	CALL :FILES_REMOVE_FIX_SILENCIO
	goto:eof

:FILES_REMOVE_FIX_SILENCIO
	@call src\gen_func.cmd FUN_FILE_DELETE_FILE !tfProcesAudioConcat!
	@call src\gen_func.cmd FUN_FILE_DELETE_FILE !tfProcesAudioSilencio!
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
		(set tfStreamA=)
		(set tfStreamCountA=)
		(set tfProcesAudio=)
	) else (
		set tfStreamA="%tPathProce%\%~n1_info_stream_audio.txt"
		set tfStreamCountA="%tPathProce%\%~n1_info_stream_count_a.txt"
		set tfProcesAudio="%tPathProce%\%~n1.m4a"
	)
	goto:eof

:FILES_NAME_TEMP_SET
	if "%~1" == "" (
		(set tfStreamA_A=)
		(set tfStreamA_I=)
		(set tfInfoFixVol=)
		(set tfInfoFixVolR=)
		(set tfInfoFixInitTime=)
		(set tfInfoFixInitTimeR=)
		(set tfProcesAudioConcat=)
		(set tfProcesAudioSilencio=)
	) else (
		set tfProcesAudioConcat="%tPathProce%\%~n1_concat.wav"
		set tfProcesAudioSilencio="%tPathProce%\%~n1_silencio.m4a"
		set tfStreamA_A="%tPathProce%\%~n1_info_stream_audio_A.txt"
		set tfStreamA_I="%tPathProce%\%~n1_info_stream_audio_ID.txt"
		set tfInfoFixInitTime="%tPathProce%\%~n1_info_fix_inittime.txt"
		set tfInfoFixInitTimeR="%tPathProce%\%~n1_info_fix_inittime_r.txt"
		set tfInfoFixVol="%tPathProce%\%~n1_info_fix_vol.txt"
		set tfInfoFixVolR="%tPathProce%\%~n1_info_fix_vol_r.txt"
	)
	goto:eof

:: **** FUNCIONES
:PRINT_DEBUG_INFO
	echo.
	echo [AUDIO] ********** DEBUG **********
	echo [AUDIO] - all_a_encoder:          %all_a_encoder%
	echo [AUDIO]
	echo [AUDIO] - tfStreamA:              %tfStreamA%
	echo [AUDIO] - tfStreamCountA:         %tfStreamCountA%
	echo [AUDIO]
  	echo [AUDIO] - tfStreamA_A:            %tfStreamA_A%
	echo [AUDIO] - tfStreamA_I:            %tfStreamA_I%
	echo [AUDIO] - tfProcesAudio:          %tfProcesAudio%
	echo [AUDIO] - tfProcesAudioConcat:    %tfProcesAudioConcat%
	echo [AUDIO] - tfProcesAudioSilencio:  %tfProcesAudioSilencio%
	echo [AUDIO] - tfInfoFixInitTime:      %tfInfoFixInitTime%
	echo [AUDIO] - tfInfoFixInitTimeR:     %tfInfoFixInitTimeR%
	echo [AUDIO] - tfInfoFixVol:           %tfInfoFixVol%
	echo [AUDIO] - tfInfoFixVolR:          %tfInfoFixVolR%
	echo [AUDIO] ********** DEBUG **********
	echo.
	goto:eof


:READ_STREAM
	SETLOCAL
		call :FILES_NAME_SET_ALL "%~1"
		findstr.exe /i /c:"Audio: " !tfStreamAll! > !tfStreamA!
		set error=%errorlevel%
		call :FILES_NAME_CLEAN_ALL
	ENDLOCAL & (
		set "%~2=%error%"
	)
	goto:eof