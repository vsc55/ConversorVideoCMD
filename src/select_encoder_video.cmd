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


:SELECT_ENCODER
	:: @call src\opt_encoder.cmd SELECT_ENCODER opt_v_encoder
	
	echo.
	echo ษออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออป
	echo บ                                                              บ
	echo บ   QUE ENCODER DESEAS USAR PARA RECODIFICAR EL VIDEO:         บ
	echo บ                                                              บ
	echo บ       1. libx264     [h264 - CPU]                            บ
	echo บ       2. h264_nvenc  [h264 - GPU]                            บ
	echo บ       3. libx265     [h265 - CPU]                            บ
	echo บ       4. hevc_nvenc  [h265 - GPU]                            บ
	echo บ       5. copy                                                บ
	echo บ                                                              บ
	echo ศออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออผ
	@CHOICE /C:12345 /N /M "[GLOBAL] - [VIDEO] - OPCION NUMERO:"
	IF Errorlevel 5 SET tmp_encoder=copy
	IF Errorlevel 4 SET tmp_encoder=hevc_nvenc
	IF Errorlevel 3 SET tmp_encoder=libx265
	IF Errorlevel 2 SET tmp_encoder=h264_nvenc
	IF Errorlevel 1 SET tmp_encoder=libx264
	
	echo [GLOBAL] - [VIDEO] - SE HA SELECCIONADO EL ENCODER [!tmp_encoder!]
	echo.
	SET "%~1=!tmp_encoder!"
	goto:eof
	
	
:DETECTAR_BORDES
	:: @call src\opt_encoder.cmd DETECTAR_BORDES var_return

	@CHOICE /C:YN /M "[GLOBAL] - [VIDEO] - จDESEAS DETECTAR BORDE EN CADA ARCHIVO?"
	IF Errorlevel 2 SET tmp_detect_border=NO
	IF Errorlevel 1 SET tmp_detect_border=YES
	echo [GLOBAL] - [VIDEO] - DETECTAR BORDE DEL VIDEO: !tmp_detect_border!
	echo.
	SET "%~1=!tmp_detect_border!"
	GOTO :eof


:CAMBIAR_SIZE
	:: @call src\opt_encoder.cmd CAMBIAR_SIZE var_return
	
	@CHOICE /C:YN /M "[GLOBAL] - [VIDEO] - จCAMBIAR EL TAMAฅO A TODOS LOS ARCHIVOS?"
	IF Errorlevel 2 SET tmp_change_size=NO
	IF Errorlevel 1 SET tmp_change_size=YES
	
	if "!tmp_change_size!" == "YES" (
		call:SELECT_NEW_SIZE -1 tmp_change_size
		echo.
	)
	
	echo [GLOBAL] - [VIDEO] - CAMBIAR TAMAฅO DEL VIDEO: !tmp_change_size!
	echo.
	SET "%~1=!tmp_change_size!"
	GOTO :eof

	
	
	
:SELECT_NEW_SIZE
	:: @call src\opt_encoder.cmd SELECT_NEW_SIZE !tWidthOrig! OutNewSize
	
	set tmp_tWidthOrig=%~1

	set txt_msg=
	if "%_stage%" == "G" (
		set tmp_msg="[GLOBAL] - [VIDEO] - NUEVO TAMAฅO PARA TODOS LOS ARCHIVOS, EN BLANCO PREGUNTARA EN CADA ARCHIVO:"
	) else (
		set tmp_msg="[VIDEO] - NUEVO TAMAฅO, EL ACTUAL ES [!tmp_tWidthOrig!]:"
	)

	set tmp_OutNewSize=
	echo ษออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออป
	echo บ จQUIERES CAMBIAR EL TAMAฅDO DEL VIDEO?                         บ
	echo ฬออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออน
	echo บ                                                                บ
	echo บ    360p  [Mobile]          - 640:360                           บ
	echo บ    576p  [PAL WIDESCREEN]  - 1024:576                          บ
	echo บ    720p  [HD]              - 1280:720                          บ
	echo บ    1080p [Full HD]         - 1920:1080                         บ
	echo บ    4K    [UHDTV]           - 3840:2160                         บ
	echo บ                                                                บ
	echo ฬออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออน
	echo บ    NOTA: SE PUEDE DEFINIR ALTURA CON -1 PARA QUE EL CALCULE    บ
	echo บ          SEA AUTOMATICO Y MANTENGA LA RELACION DE ASPECTO.     บ
	echo บ                                                                บ
	echo บ          ALTURA AUTO PARA 1080p = 1920:-1                      บ
	echo บ                                                                บ
	echo บ    NOTA: SI SE HA EFECTUA DETECCION DE BORDE NO FUNCIONA EL    บ
	echo บ          PARAMETRO -1 HAY QUE PONER LA RESOLUCION NUEVA        บ
	echo บ          ENTERA.                                               บ
	echo บ              EJEMPLO: 1280:720 (OK), 1280:-1 (ERROR)           บ
	echo บ                                                                บ
	echo ศออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออผ
	if not "!tfStreamV!" == "" (
		echo [VIDEO] - [INFO] - INFORMACION PISTA DE VIDEO:
		type !tfStreamV!
		echo.
	)
	REM LIMPIAMOS LA VARIABLE: SI SE PULSA ENTER, set /p NO LA MODIFICA Y SE REUTILIZARIA LA RESPUESTA DEL ARCHIVO ANTERIOR.
	(set InputNewOutNewSize=)
	set /p InputNewOutNewSize=!tmp_msg!
	if /i "!InputNewOutNewSize!" neq "" (
		set tmp_OutNewSize=!InputNewOutNewSize!
		
		set InputNewOutNewSizeOK=YES
		echo !tmp_OutNewSize! | find ":"  > NUL
		if errorlevel 1 set InputNewOutNewSizeOK=NO
		if !InputNewOutNewSizeOK! == NO (
			set tmp_OutNewSize=!tmp_OutNewSize!:-1
		)
		
		if "%_stage%" == "G" (
			echo [GLOBAL] - [VIDEO] - [MODIFICADO] - NUEVO TAMAฅO: !InputNewOutNewSize!
		) else (
			echo [VIDEO] - [MODIFICADO] - NUEVO TAMAฅO: !InputNewOutNewSize!
		)
		
	)
	set "%~2=!tmp_OutNewSize!"
	goto:eof
