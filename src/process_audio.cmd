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
		echo [AUDIO] - [SKIP] - NO SE HA ESPECIFICADO NINGUN ARCHIVO A PREOCESAR^^!^^!
		echo.
		goto:eof
	)
	If not exist "%~1" (
		echo [AUDIO] - [SKIP] - EL ARCHIVO A PROCESAR YA NO EXISTE^^!^^!
		echo.
		goto:eof
	)

	echo [AUDIO] - PROCESO INICIANDO...
	SETLOCAL
		CALL :FILES_NAME_SET_ALL "%~1"

		REM ******** DEBUG!!!!!!!!!!!!!!!!
		if "!_debug_sa!" == "YES" (
			CALL :PRINT_DEBUG_INFO
			goto:eof
		)
		REM ******** DEBUG!!!!!!!!!!!!!!!!

		call :READ_STREAM "%~1" _read_stream
		if "!_read_stream!" == "1" (
			echo [AUDIO] - [SKIP] - NO SE HAN DETECTADO NINGUNA PISTA DE AUDIO^^!^^!
			set _skip_process_run=SKIP
		) else ( CALL :START_PROCESS_CHECK _skip_process_run )

		if not defined _skip_process_run ( call :START_PROCESS_RUN %* )
		
		CALL :FILES_REMOVE_FIX_SILENCIO
		call :FILES_NAME_CLEAN_ALL
	ENDLOCAL
	echo.
	goto:eof


:START_PROCESS_CHECK
	if exist !tfProcesAudio! (
		@CHOICE /C:YN /d N /t 10 /M "[AUDIO] - LA PISTA DE AUDIO YA SE HA PROCESADO ¨QUIERES VOLVER A PROCESARLA [AUTO **NO** EN 10 SEG]"
		IF Errorlevel 2 (
			echo [AUDIO] - [SKIP] - PISTA DE AUDIO YA PROCESADA^^!^^!
			set "%~1=SKIP"
			GOTO :eof
		)
		CALL src\gen_func.cmd FUN_FILE_DELETE_FILE !tfProcesAudio!
	)
	if not "%all_a_encoder%" == "copy" (
		if "%all_a_bitrate%" == "0" ( 
			echo [AUDIO] - [SKIP] - SE COPIAR LA PISTA ORIGINAL^^!^^!
			set "%~1=SKIP"
			GOTO :eof
		)

		if "!all_a_bitrate!" == "" (
			echo [AUDIO] - [RECODIFICAR] - [SKIP] - NO SE HA DEFINIDO BITRATE^^!^^!
			set "%~1=SKIP"
			GOTO :eof
		)
	)
	REM TODO: PENDIENTE VALIDAR SI TODOS LOS PARAMETROS GLOBALES SE HAN DEFINIDO Y SON CORRECTOS.
	goto:eof


:START_PROCESS_RUN
	SETLOCAL
		set t_file=%~1
		CALL :FILES_REMOVE_TEMP

		REM ***************************
		REM *** BUSCAMOS PISTA DE AUDIO
		REM ***************************
		set t_audio_id_pista=
		cscript /nologo src/AudioGetID.vbs !tfStreamA! !tfStreamA_A! !tfStreamA_I!
		set /p t_audio_id_pista=<!tfStreamA_I!

		if "!t_audio_id_pista!" == "" (
			echo [AUDIO] - [ID] - [ERR] - NO SE DETECTO LA PISTA DE AUDIO CORRECTA^^!^^!
			GOTO :eof
		)


		REM *********************************************
		REM *** COMPROBAMOS SI EL AUDIO ESTA SINCRONIZADO
		REM *********************************************
		echo|set /p="[AUDIO] - [SYNC] - [SCAN] - COMPROBANDO SI EL AUDIO Y EL VIDEO INICIAN A LA VEZ... "

		set t_sync_v_a=
		set t_sync_v_a_status=
		CALL :CHECK_SYNC_AUDIO_VIDEO "!t_Audio_Id_Pista!" "%t_file%" t_sync_v_a t_sync_v_a_status

		if "!t_sync_v_a_status!" == "OK" (
			echo|set /p="  [OK]"
		) else (
			if "!t_sync_v_a_status!" == "NO" (
				echo|set /p="  [NO^!]"
			) else (
				if "!t_sync_v_a_status!" == "ERROR1" ( 
					echo|set /p=" [ERR^!^!] - NO SE HA LOCALIZADO pts_time^!^!^!^!
				) else (
					echo|set /p=" [!t_sync_v_a_status!]^!^!^!^!"
				)
				echo.
				GOTO :eof
			)
		)
		echo.

		if "%all_a_encoder%" == "copy" (
			REM TODO: PENDIENTE IMPLEMENTAR COPY ******************************************
			echo [AUDIO] - [COPY] - PENDIENTE DE IMPLEMENTAR...
		) else (
			if "!t_sync_v_a_status!" == "NO" (
				call :SELECT_SYNC_SEG !t_sync_v_a! t_sync_v_a
				if /i "!t_sync_v_a!" == "0" (
					set t_sync_v_a_status=OK
				) else (
					echo [AUDIO] - [SYNC] - [FIX] - SE A¥ADIRA AL INICIO UN SILENCIO DE: !t_sync_v_a! SEG

					REM ***** INI - CODIGO DE PRUEBAS - NO ES NECESARIO YA QUE EL SILENCIO SE GENERA DIRECTAMENTE AL EXTRAER LA PISTA DE AUDIO *****
					echo|set /p="[AUDIO] - [SYNC] - [FIX] - GENERANDO SILENCIO..."
					set RunFunction=%tPathffmpeg% -hide_banner -y -threads %ffmpeg_threads% -y
					set RunFunction=!RunFunction! -filter_complex "aevalsrc=0:d=!t_sync_v_a!:sample_rate=!all_a_hz!:channel_layout=stereo"
					set RunFunction=!RunFunction! !tfProcesAudioSilencio!
					@call src\gen_func.cmd RUN_EXE
					(set RunFunction=)

					echo|set /p="  [OK]"
					echo.
					REM ***** END - CODIGO DE PRUEBAS - NO ES NECESARIO YA QUE EL SILENCIO SE GENERA DIRECTAMENTE AL EXTRAER LA PISTA DE AUDIO *****



					REM ***** AVISO!!!! ****** TENEMOS QUE GENERAR PRIMERO EL WAV YA QUE SI LO GENERAMOS DIRECTAMENTE EN AAC EN LA UNION DEL SILENCION CON 
					REM                        LA PISTA DE AUDIO A¥ADE UNOS SEGUNDOS MAS DE TIEMPO Y SE DESINCRONIZA.

					echo|set /p="[AUDIO] - [SYNC] - [FIX] - A¥ADIENDO SILENCIO A LA PISTA DE AUDIO..."
					
					set RunFunction=%tPathffmpeg% -hide_banner -y -threads %ffmpeg_threads% -y
					set RunFunction=!RunFunction! -i !tPathFileOrig! -vn -sn -map_chapters -1
					set RunFunction=!RunFunction! -filter_complex "aevalsrc=0|:d=!t_sync_v_a!:sample_rate=!all_a_hz!:channel_layout=stereo[silence];[silence][0:a]concat=n=2:v=0:a=!t_audio_id_pista![out]" -map [out]
					set RunFunction=!RunFunction! !tfProcesAudioConcat!
					@call src\gen_func.cmd RUN_EXE
					(set RunFunction=)

					If exist !tfProcesAudioConcat! (
						echo|set /p="  [OK]"
						echo.
					) else (
						echo|set /p="  [ERR^!^!]"
						echo.
						CALL :FILES_REMOVE
						GOTO :eof
					)
					REM *****************************
				)

			)


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

			set t_audio_fix_vol=
			set t_audio_fix_vol_status=
			IF "%default_a_process%" == "ACCGAIN" ( 
				call :FIX_VOLUMEN_AACGAIN "!t_audio_id_pista!" "!all_a_bitrate!" "!all_a_hz!" "!t_audio_ccanales!" t_audio_fix_vol t_audio_fix_vol_status
			) else (
				call :FIX_VOLUMEN_FFMPEG "!t_audio_id_pista!" "!all_a_bitrate!" "!all_a_hz!" "!t_audio_ccanales!" t_audio_fix_vol t_audio_fix_vol_status
			)
		)
	ENDLOCAL
	echo [AUDIO] - [FINALIZADO]
	goto:eof


:SELECT_SYNC_SEG
	SETLOCAL
		set t_sync_v_a=%~1
		@CHOICE /C:YN /d Y /t 10 /M "[AUDIO] - [SYNC] - [FIX] - ¨DESEAS USAR EL VALOR DETECTADO DE [%t_sync_v_a% SEG] - [AUTO **SI** EN 10 SEG]"
		IF Errorlevel 2 (
			set /p NewVal="[AUDIO] - [SYNC] - [FIX] - CUANTO SILENCIO HAY QUE A¥ADIR AL INCIO [%t_sync_v_a% SEG]:"
			if DEFINED NewVal (
				if not "%t_sync_v_a%" == "!NewVal!" (
					set t_sync_v_a=!NewVal!
				)
			)
		)
	ENDLOCAL&(
		set _t_sync_v_a=%t_sync_v_a%
	)
	set "%~2=!_t_sync_v_a!"
	goto:eof


:CHECK_SYNC_AUDIO_VIDEO
	SETLOCAL
		set t_id_pista=%~1
		set t_file=%~2
		set t_sync_va=
		set t_return=

		set RunFunction=%tPathffmpeg% -hide_banner -y -threads %ffmpeg_threads% -i "!t_file!" -af "ashowinfo" -map 0:!t_id_pista! -y -f alaw -frames:a !t_id_pista! nul
		@call src\gen_func.cmd RUN_EXE 2 !tfInfoFixInitTime!
		(set RunFunction=)

		cscript /nologo src/AudioGetInitTime.vbs !tfInfoFixInitTime! !tfInfoFixInitTimeR!
		set /p t_sync_va=<!tfInfoFixInitTimeR!

		if "!t_sync_va!" == "" (
			set t_return=ERROR1
		)
		if /i !t_sync_va! neq 0 (
			set t_return=NO
		) else (
			set t_return=OK
		)
	ENDLOCAL&(
		set _t_sync_va=%t_sync_va%
		set _t_return=%t_return%
	)
	set "%~3=!_t_sync_va!"
	set "%~4=!_t_return!"
	goto:eof


:FIX_VOLUMEN_FFMPEG
	:: TODO: Pendiente probar despues de la adaptacion!!
	SETLOCAL
		set t_id_pista=%~1
		set t_bitrate=%~2
		set t_hz=%~3
		set t_ccanales=%~4
		set t_audio_fix_vol=
		set t_return=OK

		echo [AUDIO] - [VOLF] - [SCAN] - ANALIZANDO VOLUMEN...

		set RunFunction=%tPathffmpeg% -hide_banner -y -threads %ffmpeg_threads%
		if exist !tfProcesAudioConcat! (
			set RunFunction=!RunFunction! -i !tfProcesAudioConcat!
			set RunFunction=!RunFunction! -map 0:a
		) else (
			set RunFunction=!RunFunction! -i !tPathFileOrig!
			set RunFunction=!RunFunction! -map 0:!t_id_pista!
			set RunFunction=!RunFunction! -vn -sn -map_chapters -1
		)
		set RunFunction=!RunFunction! -af volumedetect -f null -
		@call src\gen_func.cmd RUN_EXE 2 !tfInfoFixVol!
		(set RunFunction=)

		cscript /nologo src/AudioGetMaxVol.vbs !tfInfoFixVol! !tfInfoFixVolR!
		set /p t_audio_fix_vol=<!tfInfoFixVolR!
	
		if "!t_audio_fix_vol!" == "" (
			echo [AUDIO] - [VOLF] - [ERR^^!^^!] - NO SE HA LOCALIZADO max_volume^^!^^!^^!
			set t_return=ERROR_1
		) else (
			if /i !t_audio_fix_vol! gtr 0 (
				echo [AUDIO] - [VOLF] - [FIX] - APLICANDO AJUSTE RECOMENDADO [!t_audio_fix_vol!]...
			) else (
				echo [AUDIO] - [VOLF] - [SKIP] - IGNORANDO AJUSTE RECOMENDADO [!t_audio_fix_vol!]^!
				set t_audio_fix_vol=0
				set t_return=SKIP
			)
		)

		if "!t_return!" == "OK" (
			echo [AUDIO] - [RECODIFICAR] - RECODIFICANDO AUDIO !t_ccanales! CON UN BITRATE [!t_bitrate!]...
			set RunFunction=%tPathffmpeg% -hide_banner -threads %ffmpeg_threads% -y
			if exist !tfProcesAudioConcat! (
				set RunFunction=!RunFunction! -i !tfProcesAudioConcat!
				if not "!t_audio_fix_vol!" == "0" (
					set RunFunction=!RunFunction! -filter_complex "[0:a]volume=!t_audio_fix_vol!dB:precision=fixed[out]" -map [out]
				) else (
					set RunFunction=!RunFunction! -map 0:a
				)
			) else (
				set RunFunction=!RunFunction! -i !tPathFileOrig!
				set RunFunction=!RunFunction! -vn -sn -map_chapters -1
				if not "!t_audio_fix_vol!" == "0" (
					set RunFunction=!RunFunction! -filter_complex "[0:!t_id_pista!]volume=!t_audio_fix_vol!dB:precision=fixed[out]" -map [out]
				) else (
					set RunFunction=!RunFunction! -map 0:!t_id_pista!
				)
			)
			if not "!t_bitrate!" == "" (
				set RunFunction=!RunFunction! -b:a !t_bitrate!
			)
		
			:: set RunFunction=!RunFunction! -c:a aac -strict experimental
		
			set RunFunction=!RunFunction! -ar !t_hz!
			set RunFunction=!RunFunction! -ac 2
			set RunFunction=!RunFunction! -aac_coder twoloop
		
			set RunFunction=!RunFunction! !tfProcesAudio!
			@call src\gen_func.cmd RUN_EXE
			(set RunFunction=)
		)
	
	ENDLOCAL&(
		set _t_audio_fix_vol=%t_audio_fix_vol%
		set _t_return=%t_return%
	)
	set "%~5=!_t_audio_fix_vol!"
	set "%~6=!_t_return!"
	goto:eof



:FIX_VOLUMEN_AACGAIN
	SETLOCAL
		set t_id_pista=%~1
		set t_bitrate=%~2
		set t_hz=%~3
		set t_ccanales=%~4
		set t_audio_fix_vol=
		set t_return=OK
	
		echo [AUDIO] - [VOLF] - [    ] - RECODIFICANDO AUDIO [PISTA !t_id_pista!] !t_ccanales! CON UN BITRATE [!t_bitrate!]...

		set RunFunction=%tPathffmpeg% -hide_banner -y -threads %ffmpeg_threads% -y
	
		if exist !tfProcesAudioConcat! (
			set RunFunction=!RunFunction! -i !tfProcesAudioConcat!
			set RunFunction=!RunFunction! -map 0:a
		) else (
			set RunFunction=!RunFunction! -i !tPathFileOrig!
			set RunFunction=!RunFunction! -vn -sn -map_chapters -1
			set RunFunction=!RunFunction! -map 0:!t_id_pista!
		)
	
		if not "!t_bitrate!" == "" (
			set RunFunction=!RunFunction! -b:a !t_bitrate!
		)
	
		rem set RunFunction=!RunFunction! -c:a aac
		set RunFunction=!RunFunction! -ar !t_hz!
		set RunFunction=!RunFunction! -ac 2
		set RunFunction=!RunFunction! -aac_coder twoloop
	
		set RunFunction=!RunFunction! !tfProcesAudio!
		@call src\gen_func.cmd RUN_EXE
		(set RunFunction=)
	
		echo [AUDIO] - [VOLF] - [SCAN] - ANALIZANDO VOLUMEN...
	
 		set RunFunction=%tPathaacgain% /q !tfProcesAudio!
		@call src\gen_func.cmd RUN_EXE 1 !tfInfoFixVol!
		(set RunFunction=)
	
		cscript /nologo src/AudioGetMaxVolAACGain.vbs !tfInfoFixVol! !tfInfoFixVolR!
		set /p t_audio_fix_vol=<!tfInfoFixVolR!
	
		if /i !t_audio_fix_vol! gtr 0 (
			echo [AUDIO] - [VOLF] - [FIX ] - APLICANDO AJUSTE RECOMENDADO [!t_audio_fix_vol!]...

			set RunFunction=%tPathaacgain% /r /c /q !tfProcesAudio!
			@call src\gen_func.cmd RUN_EXE
			(set RunFunction=)
		) else (
			echo [AUDIO] - [VOLF] - [SKIP] - IGNORANDO AJUSTE RECOMENDADO [!t_audio_fix_vol!]
			set t_return=SKIP
		)

	ENDLOCAL&(
		set _t_audio_fix_vol=%t_audio_fix_vol%
		set _t_return=%t_return%
	)
	set "%~5=!_t_audio_fix_vol!"
	set "%~6=!_t_return!"
	goto:eof


:: **** ELIMINAR ARCHIVOS
:FILES_REMOVE
	if not "%_debug%" == "YES" (
		REM @call src\gen_func.cmd FUN_FILE_DELETE_FILE !tfProcesAudioConcat!
		REM @call src\gen_func.cmd FUN_FILE_DELETE_FILE !tfProcesAudioSilencio!
		@call src\gen_func.cmd FUN_FILE_DELETE_FILE !tfStreamA!
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
		(set tfProcesAudio=)
	) else (
		set tfStreamA="%tPathProce%\%~n1_info_stream_audio.txt"
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
	echo [AUDIO] - tPathFileOrig:          %tPathFileOrig%
	echo [AUDIO] - tPathFileConvrt:        %tPathFileConvrt%
	echo [AUDIO] - tfInfoffmpeg:           %tfInfoffmpeg%

	echo [AUDIO] - all_a_encoder:          %all_a_encoder%

	echo [AUDIO] - tfStreamA:              %tfStreamA%
  	echo [AUDIO] - tfStreamA_A:            %tfStreamA_A%
	echo [AUDIO] - tfStreamA_I:            %tfStreamA_I%
	echo [AUDIO] - tfProcesAudio:          %tfProcesAudio%
	echo [AUDIO] - tfProcesAudioConcat:    %tfProcesAudioConcat%
	echo [AUDIO] - tfProcesAudioSilencio:  %tfProcesAudioSilencio%
	echo [AUDIO] - tfInfoFixInitTime:      %tfInfoFixInitTime%
	echo [AUDIO] - tfInfoFixInitTimeR:     %tfInfoFixInitTimeR%
	echo [AUDIO] - tfInfoFixVol:           %tfInfoFixVol%
	echo [AUDIO] - tfInfoFixVolR:          %tfInfoFixVolR%
	echo.
	pause
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