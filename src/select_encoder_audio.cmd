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



:SELECT_BITRATE

	set tmp_audio_bitrate=%~1

	set bt_custom=OFF
	if "%_stage%" == "G" (
		set txt_msg="[GLOBAL] - [AUDIO] - SELECCIONAR NUEVO BITRATE:"
	) else (
		set txt_msg="[AUDIO] - SELECCIONAR NUEVO BITRATE:"
	)
	echo ษออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออป
	echo บ AUDIO: จQUE BITRATE DESEAS USAR?                               บ
	echo ฬออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออน
	echo บ                                                                บ
	echo บ  BITRATE AUDIO:                                                บ
	echo บ                                                                บ
	echo บ    0. AUDIO Copy                                               บ
	echo บ    1. AUDIO 128 kbps                                           บ
	echo บ    2. AUDIO 160 kbps                                           บ
	echo บ    3. AUDIO 192 kbps                                           บ
	echo บ    4. AUDIO 256 kbps                                           บ
	echo บ    5. AUDIO 320 kbps                                           บ
	echo บ    6. CUSTOM [*]                                               บ
	echo บ                                                                บ
	echo บ    * NOTE:                                                     บ
	echo บ        - EN LA OPCION CUSTOM AฅADE EL BITRATE DESEADO POR      บ
	echo บ          EJEMPLO 96K o 96000 ambas funcionarian igual.         บ
	echo บ        - SI SE ESPECIFICA -1 SE ANULARA EL LA RECODIFICACION   บ
	echo บ          DEL AUDIO.                                            บ
	echo ศออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออผ
	if not "!tfStreamA_A!" == "" (
		echo [AUDIO] - [INFO] - INFORMACION PISTA DE AUDIO:
		type !tfStreamA_A!
		echo.
	)
	@CHOICE /C:0123456 /N /M !txt_msg!
	IF Errorlevel 7 SET bt_custom=ON
	IF Errorlevel 6 SET tmp_audio_bitrate=320k
	IF Errorlevel 5 SET tmp_audio_bitrate=256k
	IF Errorlevel 4 SET tmp_audio_bitrate=192k
	IF Errorlevel 3 SET tmp_audio_bitrate=160k
	IF Errorlevel 2 SET tmp_audio_bitrate=128k
	IF Errorlevel 1 SET bt_custom=COPY
	if "!bt_custom!" == "ON" ( 
		if "%_stage%" == "G" (
			set txt_msg="[GLOBAL] - [AUDIO] - SELECCIONAR CUSTOM BITRATE [DEFAULT !tmp_audio_bitrate!]:"
		) else (
			set txt_msg="[AUDIO] - SELECCIONAR CUSTOM BITRATE [DEFAULT !tmp_audio_bitrate!]:"
		)
		set /p InputNewAudioBitrate=!txt_msg!
		if /i "!InputNewAudioBitrate!" neq "" (
			if /i "!InputNewAudioBitrate!" equ "-1" (
				set tmp_audio_bitrate=
				if "%_stage%" == "G" (
					echo [GLOBAL] - [AUDIO] - [MODIFICADO] NUEVO BITRATE: DESACTIVADO^!^!^!^!
				) else (
					echo [AUDIO] - [MODIFICADO] NUEVO BITRATE: DESACTIVADO^!^!^!^!
				)
			) else (
				set tmp_audio_bitrate=!InputNewAudioBitrate!
				if "%_stage%" == "G" (
					echo [GLOBAL] - [AUDIO] - [MODIFICADO] NUEVO BITRATE: !tmp_audio_bitrate!
				) else (
					echo [AUDIO] - [MODIFICADO] NUEVO BITRATE: !tmp_audio_bitrate!
				)
			)
		)
	)
	if "!bt_custom!" == "COPY" (
		set tmp_audio_bitrate=0
		echo [GLOBAL] - [AUDIO] - COPY
	)
	
	set "%~2=!tmp_audio_bitrate!"
	goto:eof
