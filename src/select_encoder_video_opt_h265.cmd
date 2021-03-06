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


:SELECT_PROFILE
	:: @call src\select_encoder_video_opt_h265.cmd SELECT_PROFILE opt_v_profile
	
	set txt_msg=
	if "%_stage%" == "G" (
		set txt_msg="[GLOBAL] - [VIDEO] - ENCODING PROFILE:"
	) else (
		set txt_msg="[VIDEO] - ENCODING PROFILE:"
	)
	
	echo 浜様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様融
	echo � �ENCODING PROFILE?                                             �
	echo 麺様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様郵
	echo �                                                                �
	echo �    1. main                                                     �
	echo �    2. main 10                                                  �
	echo �                                                                �
	echo �    0. NINGUNO - NO SELECT PROFILE                              �
	echo �                                                                �
	echo 藩様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様夕
	if not "!tfStreamV!" == "" (
		echo [VIDEO] - [INFO] - INFORMACION PISTA DE VIDEO:
		type !tfStreamV!
		echo.
	)
	@CHOICE /C:012 /N /M !txt_msg!
	IF Errorlevel 3 SET "%~1=main10"
	IF Errorlevel 2 SET "%~1=main"
	IF Errorlevel 1 SET "%~1="
	goto:eof




:SELECT_LEVEL
	:: @call src\select_encoder_video_opt_h265.cmd SELECT_LEVEL 0 opt_v_level
	:: TODO: PENDIENTE CONTROLAR SI EL VALOR INTRODUCIDO ESTA ENTRE -1 Y 5.
	
	set tmp_opt_v_level=%~1
	
	set txt_msg=
	if "%_stage%" == "G" (
		set txt_msg="[GLOBAL] - [VIDEO] - SELECCION ACTUAL DE LEVEL [!tmp_opt_v_level!]:"
	) else (
		set txt_msg="[VIDEO] - SELECCION ACTUAL DE LEVEL [!tmp_opt_v_level!]:"
	)
	
	echo 浜様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様融
	echo � �ENCODING LEVEL RESTRICTION [DESE 0 A 62]?                     �
	echo 麺様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様郵
	echo �                                                                �
	echo �    0 = auto                                                    �
	echo �    1, 1.0                                                      �
	echo �    2, 2.0, 2.1                                                 �
	echo �    3, 3.0, 3.1                                                 �
	echo �    4, 4.0, 4.1                                                 �
	echo �    5, 5.0, 5.1, 5.2                                            �
	echo �    6, 6.0, 6.1, 6.2                                            �
	echo �                                                                �
	echo �   -1 = NINGUNO                                                 �
	echo �                                                                �
	echo 藩様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様夕
	if not "!tfStreamV!" == "" (
		echo [VIDEO] - [INFO] - INFORMACION PISTA DE VIDEO:
		type !tfStreamV!
		echo.
	)
	set /p InputNewOpt_v_level=!txt_msg!
	if /i "!InputNewOpt_v_level!" neq "" (
		if /i "!InputNewOpt_v_level!" equ "-1" (
			set tmp_opt_v_level=
			if "%_stage%" == "G" (
				echo [GLOBAL] - [VIDEO] - [MODIFICADO] NUEVO LEVEL: DESACTIVADO^!^!^!^!
			) else (
				echo [VIDEO] - [MODIFICADO] NUEVO LEVEL: DESACTIVADO^!^!^!^!
			)
		) else (
			set tmp_opt_v_level=!InputNewOpt_v_level!
			if "%_stage%" == "G" (
				echo [GLOBAL] - [VIDEO] - [MODIFICADO] NUEVO LEVEL: !tmp_opt_v_level!
			) else (
				echo [VIDEO] - [MODIFICADO] NUEVO LEVEL: !tmp_opt_v_level!
			)
		)
	)
	echo.
	set "%~2=!tmp_opt_v_level!"
	goto:eof
	

:SELECT_QMIN_QMAX
	:: @call src\select_encoder_video_opt_h265.cmd SELECT_QMIN_QMAX 18 23 opt_v_qmin opt_v_qmax
	
	if not "!tfStreamV!" == "" (
		echo [VIDEO] - [INFO] - INFORMACION PISTA DE VIDEO:
		type !tfStreamV!
		echo.
	)
	
	set tmp_opt_v_qmin=%~1
	set tmp_opt_v_qmax=%~2
	
	
	set txt_msg=CONTROL BITRATE CUANTIZADOR MINIMO [RANGO -1 a 51] - ACTUAL QMIN [!tmp_opt_v_qmin!]  - DESACTIVAR CON -2:
	if "%_stage%" == "G" (
		set txt_msg="[GLOBAL] - [VIDEO] - !txt_msg!"
	) else (
		set txt_msg="[VIDEO] - !txt_msg!"
	)
	set /p InputNewOpt_v_qmin=!txt_msg!
	if not "!InputNewOpt_v_qmin!" == "" (
		If "!InputNewOpt_v_qmin!" == "-2" (
			set tmp_opt_v_qmin=
		) else (
			set tmp_opt_v_qmin=!InputNewOpt_v_qmin!
		)
		REM TODO: PENDIENTE CONTROLAR SI NO ES NUMERICO Y SI EL VALOR ES MENOR QUE -2 O MAYOR QUE 51
	)
	
	
	if "!tmp_opt_v_qmin!" == "" (
		set txt_msg=CONTROL BITRATE CUANTIZADOR MAXIMO [RANGO -1 a 51] - ACTUAL QMAX [!tmp_opt_v_qmax!]  - DESACTIVAR CON -2:
	) else (
		set txt_msg=CONTROL BITRATE CUANTIZADOR MAXIMO [RANGO !tmp_opt_v_qmin! - 51] - ACTUAL QMAX [!tmp_opt_v_qmax!]  - DESACTIVAR CON -2:
	)
	if "%_stage%" == "G" (
		set txt_msg="[GLOBAL] - [VIDEO] - !txt_msg!"
	) else (
		set txt_msg="[VIDEO] - !txt_msg!"
	)
	set /p InputNewOpt_v_qmax=!txt_msg!
	if not "!InputNewOpt_v_qmax!" == "" (
		If "!InputNewOpt_v_qmax!" == "-2" (
			set tmp_opt_v_qmax=
		) else (
			set tmp_opt_v_qmax=!InputNewOpt_v_qmax!
		)
		REM TODO: PENDIENTE CONTROLAR SI NO ES NUMERICO Y SI EL VALOR ES MENOR QUE -2 O MAYOR QUE 51
	)
	
	
	if "%_stage%" == "G" (echo|set /p="[GLOBAL] - ")
	echo|set /p="[VIDEO] - [CONFIG] - QMIN: "
	If "!tmp_opt_v_qmin!" == "" (
		echo|set /p="DESACTIVADO^!^!^!^!"
	) else (
		echo|set /p="!tmp_opt_v_qmin!"
	)
	echo.
	
	
	if "%_stage%" == "G" (echo|set /p="[GLOBAL] - ")
	echo|set /p="[VIDEO] - [CONFIG] - QMAX: "
	If "!tmp_opt_v_qmax!" == "" (
		echo|set /p="DESACTIVADO^!^!^!^!"
	) else (
		echo|set /p="!tmp_opt_v_qmax!"
	)
	echo.
	
	set %3=!tmp_opt_v_qmin!
	set %4=!tmp_opt_v_qmax!
	
	goto:eof

:SELECT_CRF
	:: @call src\select_encoder_video_opt_h265.cmd SELECT_CRF 23 opt_v_crf
	
	if not "!tfStreamV!" == "" (
		echo [VIDEO] - [INFO] - INFORMACION PISTA DE VIDEO:
		type !tfStreamV!
		echo.
	)
	
	set tmp_opt_v_crf=%~1
	
	set txt_msg=CONTROL BITRATE - CRF [RANGO 0 a 51] - ACTUAL CRF [!tmp_opt_v_crf!]  - DESACTIVAR CON -1:
	if "%_stage%" == "G" (
		set txt_msg="[GLOBAL] - [VIDEO] - !txt_msg!"
	) else (
		set txt_msg="[VIDEO] - !txt_msg!"
	)
	set /p InputNewOpt_v_crf=!txt_msg!
	if not "!InputNewOpt_v_crf!" == "" (
		If "!InputNewOpt_v_crf!" == "-1" (
			set tmp_opt_v_crf=
		) else (
			set tmp_opt_v_crf=!InputNewOpt_v_crf!
		)
		REM TODO: PENDIENTE CONTROLAR SI NO ES NUMERICO Y SI EL VALOR ES MENOR DE -1 O MAYOR QUE 51
	)
	
	if "%_stage%" == "G" (echo|set /p="[GLOBAL] - ")
	echo|set /p="[VIDEO] - [CONFIG] - CRF: "
	If "!tmp_opt_v_crf!" == "" (
		echo|set /p="DESACTIVADO^!^!^!^!"
	) else (
		echo|set /p="!tmp_opt_v_crf!"
	)
	echo.
	
	set %2=!tmp_opt_v_crf!
	
	goto:eof
