@echo off

:: *********************************** CONVERSION DE FORMATOS MULTIMEDIA ***********************************
:: **                                                                                                     **
:: **                                                                                                     **
:: *********************************************************************************************************

If /i "%_HACK_CHEKC_%" neq "1987" (
	echo Process Abort 500
	pause
	exit
)

if "%1" == "" (
	echo The file was either run regardless or from cmd without arguments. 
	pause
	exit /b 2
)

:: This portion will use the paramter sent from cmd window.
call :%*
goto :END



:SELECT_BITRATE

	set tmp_audio_bitrate=%~1

	set bt_custom=OFF
	if "%_stage%" == "G" (
		set txt_msg="[GLOBAL] - [AUDIO] - SELECCIONAR NUEVO BITRATE:"
	) else (
		set txt_msg="[AUDIO] - SELECCIONAR NUEVO BITRATE:"
	)
	echo ����������������������������������������������������������������ͻ
	echo � AUDIO: �QUE BITRATE DESEAS USAR?                               �
	echo ����������������������������������������������������������������͹
	echo �                                                                �
	echo �  BITRATE AUDIO:                                                �
	echo �                                                                �
	echo �    1. AUDIO 128 kbps                                           �
	echo �    2. AUDIO 160 kbps                                           �
	echo �    3. AUDIO 192 kbps                                           �
	echo �    4. AUDIO 256 kbps                                           �
	echo �    5. AUDIO 320 kbps                                           �
	echo �    6. CUSTOM [*]                                               �
	echo �                                                                �
	echo �    * NOTE:                                                     �
	echo �        - EN LA OPCION CUSTOM A�ADE EL BITRATE DESEADO POR      �
	echo �          EJEMPLO 96K o 96000 ambas funcionarian igual.         �
	echo �        - SI SE ESPECIFICA -1 SE ANULARA EL LA RECODIFICACION   �
	echo �          DEL AUDIO.                                            �
	echo ����������������������������������������������������������������ͼ
	if not "!tfStreamA_A!" == "" (
		echo [AUDIO] - [INFO] - INFORMACION PISTA DE AUDIO:
		type !tfStreamA_A!
		echo.
	)
	@CHOICE /C:123456 /N /M !txt_msg!
	IF Errorlevel 6 SET bt_custom=ON
	IF Errorlevel 5 SET tmp_audio_bitrate=320k
	IF Errorlevel 4 SET tmp_audio_bitrate=256k
	IF Errorlevel 3 SET tmp_audio_bitrate=192k
	IF Errorlevel 2 SET tmp_audio_bitrate=160k
	IF Errorlevel 1 SET tmp_audio_bitrate=128k
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
	
	set "%~2=!tmp_audio_bitrate!"
	goto:eof



:END
exit /b 0
