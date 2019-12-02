@echo off

:: *********************************** CONVERSION DE FORMATOS MULTIMEDIA ***********************************
:: **                                                                                                     **
:: **                                                                                                     **
:: *********************************************************************************************************

If /i "%_HACK_CHEKC_%" neq "1987" (
	echo Process Abort 500
	pause
	exit /b 500
)
if "%1" == "" (
	echo El archivo se ejecuto independientemente o desde cmd sin argumentos.
	pause
	exit /b 200
)


:: This portion will use the paramter sent from cmd window.
call :%*
exit /b 0


:SELECT_PROFILE
	:: @call src\select_profile.cmd SELECT_PROFILE
	
	CALL :SELECT_PROFILE_CLEAN
	echo ษออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออป
	echo บ                                                              บ
	echo บ   USAR PERFIL:                                               บ
	echo บ                                                              บ
	echo บ       1. A: 192K, V: COPY                                    บ
	echo บ                                                              บ
	echo บ       2. A: 192K, V: h265[NV]/M10/L5/Q(1-23)                 บ
	echo บ       3. A: 192K, V: h265[NV]/M10/L5/Q(1-23)/DETECT BORDE    บ
	echo บ                                                              บ
	echo บ       4. A: 192K, V: h265[NV]/M10/L5/Q(AUTO)                 บ
	echo บ       5. A: 192K, V: h265[NV]/M10/L5/Q(AUTO)/DETECT BORDE    บ
	echo บ                                                              บ
	echo บ       6. A: 192K, V: h265[NV]/M10/L5/Q(1-23)/RESIZE 1080P    บ
	echo บ       7. A: 192K, V: h264[NV]/L5/Q(1-23)                     บ
	echo บ                                                              บ
	echo บ       0. Custom                                              บ
	echo บ                                                              บ
	echo ศออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออผ
	@CHOICE /C:01234567 /N /M "[GLOBAL] - [PROFILE] - OPCION NUMERO:"
	IF Errorlevel 8 GOTO SELECT_PROFILE_07
	IF Errorlevel 7 GOTO SELECT_PROFILE_06
	IF Errorlevel 6 GOTO SELECT_PROFILE_05
	IF Errorlevel 5 GOTO SELECT_PROFILE_04
	IF Errorlevel 4 GOTO SELECT_PROFILE_03
	IF Errorlevel 3 GOTO SELECT_PROFILE_02
	IF Errorlevel 2 GOTO SELECT_PROFILE_01
	IF Errorlevel 1 GOTO SELECT_PROFILE_00
	GOTO SELECT_PROFILE


:: ffmpeg_cv = [copy|hevc_nvenc|libx265|h264_nvenc|libx264]
:: all_v_profile = [baseline|main|main10|etc...]
:: all_v_level = [4|5|5.2|etc...]
:: all_qmin = 0    q minimo -> nvenc
:: all_qmax = 23   q maximo -> nvenc
:: all_crv= 23      -> libx265 y libx264
:: all_detect_borde = [NO|YES]
:: all_change_size = [NO|1920:-1|1280:-1]
:: all_a_bitrate = [96K|192K|lo que quieras]


:SELECT_PROFILE_CLEAN
	if "!all_profile!" NEQ "" (
		SET _show_msg=YES
		echo|set /p="[GLOBAL] - BORRANDO AJUSTES DE CODIFICACION..."
	)
	
	set all_profile=
	set ffmpeg_cv=
	set all_v_profile=
	set all_v_level=
	set all_qmin=
	set all_qmax=
	set all_crv=
	set all_detect_borde=
	set all_change_size=
	set all_a_bitrate=
	
	if DEFINED _show_msg (
		echo|set /p="  [OK]"
		echo.
		(SET _show_msg=)
	)
	goto:eof

:SELECT_PROFILE_00
	:: CUSTOM
	set all_profile=custom
	echo.
	@call src\select_profile_custom.cmd INIT_SELECT_ENCODER
	GOTO SELECT_PROFILE_END

:SELECT_PROFILE_01
	:: A: 192K, V: COPY
	set all_profile=1
	set ffmpeg_cv=copy
	set all_a_bitrate=192k
	GOTO SELECT_PROFILE_END

:SELECT_PROFILE_02
	:: A: 192K, V: h265[NV]/M10/L5/Q(1-23)
	set all_profile=2
	set ffmpeg_cv=hevc_nvenc
	set all_v_profile=main10
	set all_v_level=5
	set all_qmin=1
	set all_qmax=23
	set all_detect_borde=NO
	set all_change_size=
	set all_a_bitrate=192k
	GOTO SELECT_PROFILE_END
	
:SELECT_PROFILE_03
	:: A: 192K, V: h265[NV]/M10/L5/Q(1-23)/DETECT BORDE
	set all_profile=3
	set ffmpeg_cv=hevc_nvenc
	set all_v_profile=main10
	set all_v_level=5
	set all_qmin=1
	set all_qmax=23
	set all_detect_borde=YES
	set all_change_size=
	set all_a_bitrate=192k
	GOTO SELECT_PROFILE_END
	
:SELECT_PROFILE_04
	:: A: 192K, V: h265[NV]/M10/L5/Q(AUTO)
	set all_profile=4
	set ffmpeg_cv=hevc_nvenc
	set all_v_profile=main10
	set all_v_level=5
	set all_qmin=
	set all_qmax=
	set all_detect_borde=NO
	set all_change_size=
	set all_a_bitrate=192k
	GOTO SELECT_PROFILE_END
	
:SELECT_PROFILE_05
	:: A: 192K, V: h265[NV]/M10/L5/Q(AUTO)/DETECT BORDE
	set all_profile=5
	set ffmpeg_cv=hevc_nvenc
	set all_v_profile=main10
	set all_v_level=5
	set all_qmin=
	set all_qmax=
	set all_detect_borde=YES
	set all_change_size=
	set all_a_bitrate=192k
	GOTO SELECT_PROFILE_END

:SELECT_PROFILE_06
	:: A: 192K, V: h265[NV]/M10/L5/Q(1-23)/RESIZE 1080P
	set all_profile=6
	set ffmpeg_cv=hevc_nvenc
	set all_v_profile=main10
	set all_v_level=5
	set all_qmin=1
	set all_qmax=23
	set all_detect_borde=NO
	set all_change_size=1920:-1
	set all_a_bitrate=192k
	GOTO SELECT_PROFILE_END
	
:SELECT_PROFILE_07
	:: A: 192K, V: h264[NV]/L5/Q(1-23)
	set all_profile=7
	set ffmpeg_cv=h264_nvenc
	set all_v_profile=
	set all_v_level=5
	set all_qmin=1
	set all_qmax=23
	set all_detect_borde=NO
	set all_change_size=
	set all_a_bitrate=192k
	GOTO SELECT_PROFILE_END


:SELECT_PROFILE_END
	if "!all_profile!" == "" (
		call :SELECT_PROFILE_CLEAN
	) else (
		REM if "!all_qmin!" == "" 	   ( set all_qmin=0 )
		REM if "!all_qmax!" == ""      ( set all_qmax=0 )
		if "!all_v_profile!" == "" (set all_v_profile=SKIPSELECT)
		if "!all_v_level!" == ""   (set all_v_level=SKIPSELECT)
		if "!all_change_size!" == ""   (set all_change_size=NO)
		
		:: TODO: Pendiente crear menu para poder configurar este valor
		if "!all_a_hz!" == ""   (set all_a_hz=!default_a_hz!)
	)
	goto:eof
	
	
:PRINT_CONFIG_GLOBAL
	:: @call src\select_profile.cmd PRINT_CONFIG_GLOBAL
	
	if "!ffmpeg_cv!" == "copy" (
		echo [GLOBAL] - [INFO] - [VIDEO] - ENCODER: COPY
	) else (
		echo [GLOBAL] - [INFO] - [VIDEO] - ENCODER: !ffmpeg_cv!
		if "!all_v_profile!" NEQ "SKIPSELECT" (
			echo [GLOBAL] - [INFO] - [VIDEO] - PROFILE: !all_v_profile!
		)
		if "!all_v_level!" NEQ "SKIPSELECT" (
			echo [GLOBAL] - [INFO] - [VIDEO] - LEVEL: !all_v_level!
		)
		if "!all_qmin!" NEQ "" (
			echo [GLOBAL] - [INFO] - [VIDEO] - Q MIN: !all_qmin!
		)
		if "!all_qmax!" NEQ "" (
			echo [GLOBAL] - [INFO] - [VIDEO] - Q MAX: !all_qmax!
		)
		if "!all_crv!" NEQ "" (
			echo [GLOBAL] - [INFO] - [VIDEO] - CRV: !all_crv!
		)
		echo [GLOBAL] - [INFO] - [VIDEO] - DETECTAR BORDE: !all_detect_borde!
		echo [GLOBAL] - [INFO] - [VIDEO] - NUEVO SIZE: !all_change_size!
	)
	echo [GLOBAL] - [INFO] - [AUDIO] - BITRATE: !all_a_bitrate!
	echo [GLOBAL] - [INFO] - [AUDIO] - HZ: !all_a_hz!
	goto:eof
