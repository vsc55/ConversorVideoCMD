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
	echo [VIDEO] - PROCESO INICIANDO...
	if "%~1" == "" (
		echo [VIDEO] - [SKIP] - NO SE HA ESPECIFICADO NINGUN ARCHIVO A PREOCESAR^^!^^!
	) else If not exist "%~1" (
		echo [VIDEO] - [SKIP] - EL ARCHIVO A PROCESAR YA NO EXISTE^^!^^!
	) else (
		SETLOCAL
			CALL :FILES_NAME_SET_ALL "%~1"

			REM ******** DEBUG!!!!!!!!!!!!!!!!
			if "%_debug%" == "YES" ( CALL :PRINT_DEBUG_INFO )
			REM ******** DEBUG!!!!!!!!!!!!!!!!

			CALL :START_PROCESS_CHECK _skip_process_run "%~1"
			if not defined _skip_process_run ( CALL :START_PROCESS_RUN %* )
			
			CALL :FILES_NAME_CLEAN_ALL
		ENDLOCAL
	)
	echo.
	goto:eof
	

:START_PROCESS_CHECK
	CALL :READ_STREAM "%~2" _read_stream
	if "!_read_stream!" == "1" (
		echo [VIDEO] - [SKIP] - NO SE HAN DETECTADO NINGUNA PISTA DE VIDEO^^!^^!
		set "%~1=SKIP"
		GOTO :eof
	)
	REM ** SI SE DEFINE COPY NO HAY QUE HACER NADA CON EL VIDEO, POR LO QUE SALTAMOS A LA EJECUCION DE FFMPEG **
	if "%all_v_encoder%" == "copy" ( 
		echo [VIDEO] - [SKIP] - SE COPIARA LA PISTA ORIGINAL^^!
		set "%~1=SKIP"
		GOTO :eof
	)
	if exist !tfProcesVideo! (
		@CHOICE /C:YN /d N /t 10 /M "[VIDEO] - LA PISTA DE VIDEO YA SE HA PROCESADO ¨QUIERES VOLVER A PROCESARLA [AUDO **NO** EN 10 SEG]"
		IF Errorlevel 2 (
			echo [VIDEO] - [SKIP] - PISTA DE VIDEO YA PROCESADA^^!^^!
			set "%~1=SKIP"
			GOTO :eof
		)
		CALL :FILES_REMOVE_FIX
	)

	REM TODO: PENDIENTE VALIDAR SI TODOS LOS PARAMETROS GLOBALES SE HAN DEFINIDO Y SON CORRECTOS.
	goto:eof


:START_PROCESS_RUN
	SETLOCAL
		set t_file=%~1
		call :FILES_REMOVE_TEMP
	

		set tSizeReal_crop=
		set tSizeReal_size=
		REM set tSizeOrig_size=
		REM set tWidthOrig=
	
	
	
		REM ******************************
		REM *** GET INFO FILE ORIGINAL ***
		REM ******************************
		
		REM **** Resolucion orginal
		CALL src\fun_ffprobe.cmd GET_RESOLUCION "!t_file!" !tfInfoSizeOrig! tSizeOrig_size
		CALL src\gen_func.cmd GetWidthByResolution x %tSizeOrig_size% tWidthOrig
		
		REM **** Duracion del video
		CALL src\fun_ffprobe.cmd GET_DURACION "!t_file!" !tfInfoDuration! tDurationFile
		CALL src\fun_ffprobe.cmd DURACION_FORMAT !tDurationFile! tDurationFileFormat

		REM ******************************
		REM ******************************
	
	


		REM ********************************************************
		REM *** DETECCION DEL TAMA¥O DEL VIDEO SIN BORDES NEGROS ***
		REM ********************************************************
	
		if "%all_detect_borde%" == "NO" (
			echo [VIDEO] - [SKIP] - NO SE EFECTUA DETECCION DE BORDES NEGROS [GLOBAL]
			GOTO VIDEO_CHOICE_DETECTAR_BORDE_END
		)

		@CHOICE /C:YN /d Y /t 10 /M "[VIDEO] - [BORDE] - ¨DESEAS DETECTAR BORDE NEGRO SUPERIOR HE INFERIOR [AUTO **SI** EN 10 SEG]"
		IF Errorlevel 2 GOTO VIDEO_CHOICE_DETECTAR_BORDE_NO
		IF Errorlevel 1 GOTO VIDEO_CHOICE_DETECTAR_BORDE_SI
		GOTO :eof

		:VIDEO_CHOICE_DETECTAR_BORDE_SI
		echo [VIDEO] - [BORDE] - DETECTANDO TAMA¥O REAL SIN BORDES...
		echo [VIDEO] - [BORDE]
		CALL :FIX_CROPDETECT "!t_file!" "%ffmpeg_border_detect_star%" "%ffmpeg_border_detect_dura%" tSizeReal_crop tStatus_Scan_Borde
		echo [VIDEO]		

		if not "!tSizeReal_crop" == "" (
			if not "!all_change_size!"	== "NO" (
				(set all_change_size=NO)
				echo [VIDEO] - [RESIZE] - SE HA DESACTIVADO LA OPTION DE RESIZE YA QUE NO SE PUEDE EJECUTAR A LA VEZ QUE DETECTAR BODRES^^!^^!
			)
		)
		GOTO VIDEO_CHOICE_DETECTAR_BORDE_END
			
		:VIDEO_CHOICE_DETECTAR_BORDE_NO
		echo [VIDEO] - [BORDE] - MANUAL SKIP
		GOTO VIDEO_CHOICE_DETECTAR_BORDE_END

		:VIDEO_CHOICE_DETECTAR_BORDE_END


		REM *********************************************************
		REM *** DEFINIMOS SI DESEAMOS CAMBIAR EL TAMA¥O DEL VIDEO ***
		REM *********************************************************
		
		if "!tSizeReal_crop!" == "" (
			@call src\gen_func.cmd GetWidthByResolution x %tSizeOrig_size% tWidthOrig
			set tSizeReal_size=%tSizeOrig_size%
		) else (
			@call src\gen_func.cmd GetWidthByResolution : %tSizeReal_crop% tWidthOrig
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
		
		if "%all_v_encoder%" == "h264_nvenc" (
		
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
			
			set video_e=-c:v %all_v_encoder%
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
			
			rem 	set video_e=-c:v %all_v_encoder% -preset llhq
			rem		if not "!opt_v_profile!" == "" (set video_e=!video_e! -profile:v !opt_v_profile!)
			rem		if not "!opt_v_level!" == ""   (set video_e=!video_e! -level:v !opt_v_level!)
			
			
			rem set video_e=-c:v %all_v_encoder% -preset llhq -profile:v !opt_v_profile! -level !opt_v_level! -rc-lookahead:v 32 -refs %ffmpeg_refs% -movflags +faststart -qmin !opt_v_qmin! -qmax !opt_v_qmax!
			rem set video_e=-c:v %all_v_encoder% -preset llhq -rc-lookahead:v 32 -refs %ffmpeg_refs% -movflags +faststart -qmin !opt_v_qmin! -qmax !opt_v_qmax!
			
		) else if "%all_v_encoder%" == "hevc_nvenc" (
		
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
			
			set video_e=-c:v %all_v_encoder%
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
			
			rem		set video_e=-c:v %all_v_encoder% -preset llhq
			
			
			
			REM !!!!!!!!!!!!!! PENDIENTE AFINAR QMAX PARA QUE NO OCUPEN TANTO LOS VIDEOS!!!!!!!!!!!!! qmin 16 - qmax 23
			REM set opt_v_profile=main
			REM set opt_v_level=4.1
			REM set video_e=-c:v %all_v_encoder% -preset llhq -profile:v !opt_v_profile! -level !opt_v_level! -rc-lookahead:v 32 -refs %ffmpeg_refs% -movflags +faststart -qmin !opt_v_qmin! -qmax !opt_v_qmax!
			
		) else if "%all_v_encoder%" == "libx264" (
		
			REM **** CPU - H264
			REM ****** VERSION POR COMPRESION CONSTANT RATE FACTOR (CRF)
			REM ******
			REM ****** INFO -> ffmpeg -hide_banner -h encoder=libx264
			set OutputVideoFormat="avc"
			set opt_v_CRF=%all_crf%
			set video_e=-c:v %all_v_encoder% -pix_fmt yuv420p -crf !opt_v_CRF! -preset slow -refs %ffmpeg_refs% -r %ffmpeg_fps% -movflags +faststart
			
		) else if "%all_v_encoder%" == "libx265" (
		
			REM **** CPU - H265
			REM ****** VERSION POR COMPRESION CONSTANT RATE FACTOR (CRF)
			REM ******
			REM ****** INFO -> ffmpeg -hide_banner -h encoder=libx265
			set OutputVideoFormat="hevc"
			rem		set opt_v_CRF=%default_crf%
			set opt_v_CRF=%all_crf%

			set video_e=-c:v %all_v_encoder% -pix_fmt yuv420p
			
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
		CALL :PRINT_INFO_PROCESS	
		echo.
		echo [VIDEO] - PROCESANDO....
		set RunFunction=!RunFunction! !metadata_v! !video_f! !video_e! !map_ord! -f %OutputVideoFormat% !tfProcesVideo!
		@call src\gen_func.cmd RUN_EXE
		set RunFunction=
		
		
		:END_VIDEO_FIX
		
		
	ENDLOCAL
	echo.
	echo [VIDEO] - [FINALIZADO]
	goto:eof





:: FUNCIONES FIX




:FIX_CROPDETECT
	:: call :FIX_CROPDETECT "path file" "%ffmpeg_border_detect_star%" "%ffmpeg_border_detect_dura%" _valur_crop _status_return
	SETLOCAL
		set t_file=%~1
		set t_t_ss=%~2
		set t_t_sd=%~3
		

		REM t_return:
		REM -- NODETECT
		REM -- ABORTSCAN
		REM -- NEWSCAN
		REM -- STARTSACN
		REM -- OKSCAN
		REM -- FILENULL
		REM -- FILEOK
		REM -- FILENOEXIST
		REM -- OK

		if "!t_file!" == "" (
			echo [VIDEO] - [BORDE] - [SKIP] - NO SE HA ESPECIFICADO NINGUN ARCHIVO^^!^^!^^!^^!
			(set t_return=FILENULL)
		) else (
			if exist "!t_file!" (
				(set t_return=FILEOK)
			) else (
				echo [VIDEO] - [BORDE] - [SKIP] - EL ARCHIVO ESPECIFICADO NO EXISTE^^!^^!^^!^^!
				(set t_return=FILENOEXIST)
			)
		)
		
		if "!t_return!" == "FILEOK" (
			CALL src\fun_ffprobe.cmd GET_RESOLUCION "!t_file!" !tfInfoSizeOrig! tSizeOrig
			

			:FIX_CROPDETECT_INIT_SCAN
			if defined t_count_intentos ( set /a t_count_intentos+=1 ) else ( set /a t_count_intentos=0 )

			if "!t_t_sd!" == "" (
				(set t_t_ss=)
			) else (
				if "!t_t_ss!" == "" ( set t_t_ss=0 )
				set /a t_t_stop=!t_t_ss! + !t_t_sd!
			)
			if not defined t_t_all ( if "!t_t_ss!" == "" ( (set t_t_all=YES) ) else ( (set t_t_all=NO) ) )


			(set t_return=STARTSACN)
			if "!t_t_all!" == "YES" (
				echo [VIDEO] - [BORDE] - [SCAN] - INICIANDO SCAN DE BORDES DURANTE TODO EL VIDEO...
				set RunExternal=%tPathffmpeg% -i "!t_file!" -vf cropdetect -f null -
			) else (
				echo [VIDEO] - [BORDE] - [SCAN] - INICIANDO SCAN DE BORDES DE !t_t_sd! SEGUNDOS EMPEZANDO DESDE EL SEGUNDO !t_t_ss!...
				set RunExternal=%tPathffmpeg% -ss !t_t_ss! -to !t_t_stop! -i "!t_file!" -vf cropdetect -f null -
			)
			CALL src\gen_func.cmd RUN_SUB_EXE 2 !tfInfoBordeA!
			
			
			echo [VIDEO] - [BORDE] - [SCAN] - ANALIZANDO RESULTADOS...
			findstr.exe  /i /c:"Parsed_cropdetect_" !tfInfoBordeA! > !tfInfoBordeE!
			cscript /nologo src/VideoSizeReal_Crop_ClearLog.vbs !tfInfoBordeE! !tfInfoBordeC!
			IF errorlevel 3 echo "ERROR 3"
			IF errorlevel 2 echo "ERROR 2"
			IF errorlevel 1 echo "ERROR 1"
					
			if "%_debug%" == "YES" (
				echo [VIDEO] - [BORDE] - [SCAN] - [DEBUG] - STOP DEPUES DE ANALIZAR RESULTADOS ^^!^^!^^!^^!
				PAUSE
			)

			(set t_SizeReal_crop=)
			for /F "usebackq tokens=*" %%i in (!tfInfoBordeC!) do (
				FOR /f "tokens=1,2 delims=-" %%a IN ("%%i") do (
					rem RES: %%a
					rem count: %%b
					for /f "delims=:" %%A in ("%%a") do (
						if %%b GTR 5 (
							if %%~A == !tWidthOrig! (
								echo [VIDEO] - [BORDE] - [SCAN] - MUESTRA: %%a  -- REPETIDA: %%b
								set t_SizeReal_crop=%%a
							) else if %%~A LEQ !tWidthOrig! (
								echo [VIDEO] - [BORDE] - [SCAN] - ORIG ^(!tWidthOrig!^) - MUESTRA: %%a  -- REPETIDA: %%b  -- [BORDE VERTICAL]
								set t_SizeReal_crop=%%a
							) else (
								if "%_debug%" == "YES" (
									echo [VIDEO] - [BORDE] - [SCAN] - [DEBUG] - ORIG ^(!tWidthOrig!^) - MUESTRA ^(%%A^) - COUNT ^(%%b^) - MUESTRA_ALL ^(%%i^)   - NO VALIDA^^!^^!^^!^^!
								)
							)
						) else (
							if "%_debug%" == "YES" (
								echo [VIDEO] - [BORDE] - [SCAN] - [DEBUG] - ORIG ^(!tWidthOrig!^) - MUESTRA ^(%%A^) - COUNT ^(%%b^) - MUESTRA_ALL ^(%%i^)   - NO VALIDA^^!^^!^^!^^!
							)
						)
					)
				)
			)
			echo [VIDEO] - [BORDE]
					
		
			if "!t_t_all!" == "YES" (
				if "!t_SizeReal_crop!" == "" (
					echo [VIDEO] - [BORDE] - [SKIP] - NO SE DETECTO NINGUN BORDE NEGRO EN TODO EL VIDEO^^!^^!^^!^^!
					(set t_return=NODETECT)
				)
			) else (
				if "!t_SizeReal_crop!" == "" (
					if /i !t_count_intentos! GTR 3 (
						@CHOICE /C:YN /M "[VIDEO] - [BORDE] - SE HAN DETECTADO VARIOS INTENTOS DE DETECCION DE BORDES. ¨QUIERES INTENTARLO OTRA VEZ?"
						IF Errorlevel 2 (
							(set t_return=ABORTSCAN)
						)
					)
					if not "!t_return!" == "ABORTSCAN" (
						echo [VIDEO] - [BORDE] - NO SE ENCONTRO NINGUNA MUESTRA VALIDA, A¥ADA NUEVOS DATOS DE MUESTREO:
						(set t_return=NEWSCAN)
					)
				) else (	
					@CHOICE /C:YN /M "[VIDEO] - [BORDE] - ¨DESEAS HACER OTRO MUESTREO CON OTROS VALORES?"
					IF Errorlevel 2 (set t_return=OKSCAN)
					IF Errorlevel 1 (set t_return=NEWSCAN)
				)
			)
			
			if "!t_return!" == "OKSCAN" (
				:FIX_CROPDETECT_SELECT_CROP
				echo [VIDEO] - [BORDE]
				REM TODO: PENDIENTE DETECTAR QUE RESULTADO TIENE UN COUNT MAYOUR PARA USAR ESE COMO SELECCION POR DEFECTO.
				set /p InputNewSize="[VIDEO] - [BORDE] - CONFIRMA QUE EL NUEVO TAMA¥O ES [!t_SizeReal_crop!]:"
				if /i "!InputNewSize!" neq "" (
					set t_SizeReal_crop=!InputNewSize!
					echo [VIDEO] - [BORDE] - [MODIFICADO] - EL NUEVO TAMA¥O SE HA DEFINIDO EN: !t_SizeReal_crop!
				)
				
				for /f %%i in ('cscript /nologo src/VideoSizeReal_Size.vbs "!t_SizeReal_crop!"') do (
					set t_SizeReal=%%i
				)
				echo [VIDEO] - [BORDE]
				
				if "!t_SizeReal!" == "!tSizeOrig!" (
					@CHOICE /C:YN /M "[VIDEO] - [BORDE] - EL TAMA¥O ORIGNAL Y EL CROP ESPECIFICADO ES EL MISMO ¨DESEAS ESPECIFICAR OTRO?"
					IF Errorlevel 2 (
						GOTO FIX_CROPDETECT_SELECT_CROP
					)
					IF Errorlevel 1 (
						echo [VIDEO] - [BORDE] - [SKIP] EL TAMA¥O ORIGNAL ES EL MISMO QUE EL CROP ESPECIFICADO^^!^^!^^!^^!
						(set t_return=NODETECT)
					)
				)
			)

			if "!t_return!" == "OKSCAN" (
				CALL :PLAY_TEST "!t_file!" "!t_SizeReal_crop!"
				
				echo [VIDEO] - [BORDE]
				@CHOICE /C:YN /M "[VIDEO] - [BORDE] - ¨SE VE BIEN EL VIDEO? [SI] PARA USAR ESTE VALOR / [NO] PARA BUSCAR BORDE OTRA VEZ"
				IF Errorlevel 2 (
					(set t_return=NEWSCAN)
				)
				IF Errorlevel 1 (
					(set t_return=OK)
				)
			)

			if "!t_return!" == "NEWSCAN" (
				
				if "!t_t_ss!" == "" ( set t_t_ss=20 )
				if "!t_t_sd!" == "" ( set t_t_sd=120 )

				echo [VIDEO] - [BORDE]
				set /p InputNewtDetectStar="[VIDEO] - [BORDE] - INICIAR SCAN A LOS [!t_t_ss! SEGUDNOS, ALL PARA TODO EL VIDEO]:"
				if "!InputNewtDetectStar!" == "ALL" (
					(set t_t_all=YES)
					echo [VIDEO] - [BORDE] - [MODIFICADO] - HACER SCAN DE TODO EL VIDEO
				) else (
					(set t_t_all=NO)
					if not "!InputNewtDetectStar!" == "" (
						set t_t_ss=!InputNewtDetectStar!
						echo [VIDEO] - [BORDE] - [MODIFICADO] - INICIARA EL SCAN DESDE EL SEGUNDO: !t_t_ss!
						echo [VIDEO] - [BORDE]
					)
				)
				(set InputNewtDetectStar=)

				if "!t_t_all!" == "NO" (
					set /p InputNewtDetectDura="[VIDEO] - [BORDE] - DURACION DEL SCAN [!t_t_sd! SEGUNDOS]:"
					if /i "!InputNewtDetectDura!" neq "" (
						set t_t_sd=!InputNewtDetectDura!
						echo [VIDEO] - [BORDE] - [MODIFICADO] - LA DURACION DEL SCAN ES AHORA DE: !tDetectDura! SEGUNDOS
					)
					(set InputNewtDetectDura=)
				)
				echo [VIDEO] - [BORDE]
				goto :FIX_CROPDETECT_INIT_SCAN
			)
		)
	ENDLOCAL & (
		set "%~4=%t_SizeReal_crop%"
		set "%~5=%t_return%"
	)
	goto:eof


:PLAY_TEST
	SETLOCAL
		set t_file=%~1
		set t_crop=%~2

		if "!t_crop!" == "" (
			echo [VIDEO] - [TEST] - [SKIP] - NO SE DETECTO CROP^^!^^!
		) else (
			echo [VIDEO] - [TEST] - PLAY VERSION ORIGNAL....
			set RunExternal=%tPathffplay% "!t_file!"
			call src\gen_func.cmd RUN_SUB_EXE 3 !tfInfoTestPlay!

			echo [VIDEO] - [TEST] - PLAY VERSION RECORTADA....
			set RunExternal=%tPathffplay% -vf crop=!t_crop! "!t_file!"
			if "%_debug%" == "YES" (
				@call src\gen_func.cmd RUN_SUB_EXE
			) else (
				@call src\gen_func.cmd RUN_SUB_EXE 3 !tfInfoTestPlay!
			)
		)
	ENDLOCAL
	goto:eof


:: **** ELIMINAR ARCHIVOS
:FILES_REMOVE
	if not "%_debug%" == "YES" (
		@call src\gen_func.cmd FUN_FILE_DELETE_FILE !tfStreamV!
		CALL :FILES_REMOVE_TEMP
		CALL :FILES_REMOVE_FIX
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

:FILES_REMOVE_FIX
	CALL src\gen_func.cmd FUN_FILE_DELETE_FILE !tfProcesVideo!
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
		(set tfStreamCountV=)
	) else (
		set tfStreamV="%tPathProce%\%~n1_info_stream_video.txt"
		set tfStreamCountV="%tPathProce%\%~n1_info_stream_count_v.txt"
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
	echo.
	echo [VIDEO] ********** DEBUG **********
	echo [VIDEO] - all_v_encoder:     %all_v_encoder%
	echo [VIDEO]
	echo [VIDEO] - tfStreamV:         %tfStreamV%
	echo [VIDEO] - tfStreamCountV:    %tfStreamCountV%
	echo [VIDEO]
	echo [VIDEO] - tfProcesVideo:     %tfProcesVideo%
	echo [VIDEO] - tfInfoBordeA:      %tfInfoBordeA%
	echo [VIDEO] - tfInfoBordeE:      %tfInfoBordeE%
	echo [VIDEO] - tfInfoBordeC:      %tfInfoBordeC%
	echo [VIDEO] - tfInfoSizeOrig:    %tfInfoSizeOrig%
	echo [VIDEO] - tfInfoTestPlay:    %tfInfoTestPlay%
	echo [VIDEO] ********** DEBUG **********
	echo.
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

:PRINT_INFO_PROCESS
	echo.
		echo [VIDEO]
		echo [VIDEO] - [INFO] - [IN] - TAMA¥O INICIAL: %tSizeOrig_size%
		echo [VIDEO] - [INFO] - [IN] - DURACION: %tDurationFileFormat%
		echo [VIDEO] - [INFO]
		echo [VIDEO] - [INFO] - [OUT] - ENCODING: %all_v_encoder%
		echo [VIDEO] - [INFO] - [OUT] - FORMATO SALIDA: %OutputVideoFormat% [%OutputVideoType%]
		if not "!tSizeReal_crop!" == "" (
			echo [VIDEO] - [INFO] - [OUT] - RECORTAR A: !tSizeReal_crop!
		)
		if not "!OutNewSize!" ==  "" (
			echo [VIDEO] - [INFO] - [OUT] - REDIMENSAION A: !OutNewSize!
		)
		if not "!opt_v_profile!" == "" (
			echo [VIDEO] - [INFO] - [OUT] - ENCODING PROFILE: !opt_v_profile!
		)
		if not "!opt_v_level!" == "" (
			echo [VIDEO] - [INFO] - [OUT] - ENCODING LEVEL: !opt_v_level!
		)
		if not "!opt_v_CRF!" == "" (
			echo [VIDEO] - [INFO] - [OUT] - CFR FIJO A: !opt_v_CRF!
		) else (
			if not "!opt_v_q!" == "" (
				echo [VIDEO] - [INFO] - [OUT] - CFR FIJO A: !opt_v_q!
			) else (
				if not "!opt_v_qmin!!opt_v_qmax!" == "" (
					echo [VIDEO] - [INFO] - [OUT] - CFR DINAMICO:
					if not "!opt_v_qmin!" == "" (
						echo [VIDEO] - [INFO] - [OUT] - [CFR] - QMIN: !opt_v_qmin!
					)
					if not "!opt_v_qmax!" == "" (
						echo [VIDEO] - [INFO] - [OUT] - [CFR] - QMAX: !opt_v_qmax!
					)
				)
			)
		)
		echo [VIDEO]
	goto:eof

:: RECODIFICACION
