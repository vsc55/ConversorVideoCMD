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
	:: @call src\opt_h264.cmd SELECT_PROFILE opt_v_profile
	
	set txt_msg=
	if "%_stage%" == "G" (
		set txt_msg="[GLOBAL] - [VIDEO] - ENCODING PROFILE:"
	) else (
		set txt_msg="[VIDEO] - ENCODING PROFILE:"
	)
	
	echo ษออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออป
	echo บ จENCODING PROFILE?                                             บ
	echo ฬออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออน
	echo บ                                                                บ
	echo บ    1. baseline                                                 บ
	echo บ    2. main                                                     บ
	echo บ    3. high                                                     บ
	echo บ    4. high444p                                                 บ
	echo บ                                                                บ
	echo บ    0. NINGUNO - NO SELECT PROFILE                              บ
	echo บ                                                                บ
	echo ศออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออผ
	if not "!tfStreamV!" == "" (
		echo [VIDEO] - [INFO] - INFORMACION PISTA DE VIDEO:
		type !tfStreamV!
		echo.
	)
	@CHOICE /C:01234 /N /M !txt_msg!
	IF Errorlevel 5 SET "%~1=high444p"
	IF Errorlevel 4 SET "%~1=high"
	IF Errorlevel 3 SET "%~1=main"
	IF Errorlevel 2 SET "%~1=baseline"
	IF Errorlevel 1 SET "%~1="
	goto:eof




:SELECT_LEVEL
	:: @call src\opt_h264.cmd SELECT_LEVEL 0 opt_v_level
	:: TODO: PENDIENTE CONTROLAR SI EL VALOR INTRODUCIDO ESTA ENTRE -1 Y 5.
	
	set tmp_opt_v_level=%~1
	
	set txt_msg=
	if "%_stage%" == "G" (
		set txt_msg="[GLOBAL] - [VIDEO] - SELECCION ACTUAL DE LEVEL [!tmp_opt_v_level!]:"
	) else (
		set txt_msg="[VIDEO] - SELECCION ACTUAL DE LEVEL [!tmp_opt_v_level!]:"
	)
	
	echo ษออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออป
	echo บ จENCODING LEVEL RESTRICTION [DESE 0 A 51]?                     บ
	echo ฬออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออน
	echo บ                                                                บ
	echo บ    0 = auto                                                    บ
	echo บ    1, 1.0, 1.1, 1.2, 1.3                                       บ
	echo บ    2, 2.0, 2.1, 2.2                                            บ
	echo บ    3, 3.0, 3.1, 3.2                                            บ
	echo บ    4, 4.0, 4.1, 4.2                                            บ
	echo บ    5, 5.0, 5.1                                                 บ
	echo บ                                                                บ
	echo บ   -1 = NINGUNO                                                 บ
	echo บ                                                                บ
	echo ศออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออผ
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
	:: @call src\opt_h264.cmd SELECT_QMIN_QMAX 18 23 opt_v_qmin opt_v_qmax
	
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
