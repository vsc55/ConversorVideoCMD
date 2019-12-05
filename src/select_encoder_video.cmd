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
	echo ��������������������������������������������������������������ͻ
	echo �                                                              �
	echo �   QUE ENCODER DESEAS USAR PARA RECODIFICAR EL VIDEO:         �
	echo �                                                              �
	echo �       1. libx264     [h264 - CPU]                            �
	echo �       2. h264_nvenc  [h264 - GPU]                            �
	echo �       3. libx265     [h265 - CPU]                            �
	echo �       4. hevc_nvenc  [h265 - GPU]                            �
	echo �       5. copy                                                �
	echo �                                                              �
	echo ��������������������������������������������������������������ͼ
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

	@CHOICE /C:YN /M "[GLOBAL] - [VIDEO] - �DESEAS DETECTAR BORDE EN CADA ARCHIVO?"
	IF Errorlevel 2 SET tmp_detect_border=NO
	IF Errorlevel 1 SET tmp_detect_border=YES
	echo [GLOBAL] - [VIDEO] - DETECTAR BORDE DEL VIDEO: !tmp_detect_border!
	echo.
	SET "%~1=!tmp_detect_border!"
	GOTO :eof


:CAMBIAR_SIZE
	:: @call src\opt_encoder.cmd CAMBIAR_SIZE var_return
	
	@CHOICE /C:YN /M "[GLOBAL] - [VIDEO] - �CAMBIAR EL TAMA�O A TODOS LOS ARCHIVOS?"
	IF Errorlevel 2 SET tmp_change_size=NO
	IF Errorlevel 1 SET tmp_change_size=YES
	
	if "!tmp_change_size!" == "YES" (
		call:SELECT_NEW_SIZE -1 tmp_change_size
		echo.
	)
	
	echo [GLOBAL] - [VIDEO] - CAMBIAR TAMA�O DEL VIDEO: !tmp_change_size!
	echo.
	SET "%~1=!tmp_change_size!"
	GOTO :eof

	
	
	
:SELECT_NEW_SIZE
	:: @call src\opt_encoder.cmd SELECT_NEW_SIZE !tWidthOrig! OutNewSize
	
	set tmp_tWidthOrig=%~1

	set txt_msg=
	if "%_stage%" == "G" (
		set tmp_msg="[GLOBAL] - [VIDEO] - NUEVO TAMA�O PARA TODOS LOS ARCHIVOS, EN BLANCO PREGUNTARA EN CADA ARCHIVO:"
	) else (
		set tmp_msg="[VIDEO] - NUEVO TAMA�O, EL ACTUAL ES [!tmp_tWidthOrig!]:"
	)

	set tmp_OutNewSize=
	echo ����������������������������������������������������������������ͻ
	echo � �QUIERES CAMBIAR EL TAMA�DO DEL VIDEO?                         �
	echo ����������������������������������������������������������������͹
	echo �                                                                �
	echo �    360p  [Mobile]          - 640:360                           �
	echo �    576p  [PAL WIDESCREEN]  - 1024:576                          �
	echo �    720p  [HD]              - 1280:720                          �
	echo �    1080p [Full HD]         - 1920:1080                         �
	echo �    4K    [UHDTV]           - 3840:2160                         �
	echo �                                                                �
	echo ����������������������������������������������������������������͹
	echo �    NOTA: SE PUEDE DEFINIR ALTURA CON -1 PARA QUE EL CALCULE    �
	echo �          SEA AUTOMATICO Y MANTENGA LA RELACION DE ASPECTO.     �
	echo �                                                                �
	echo �          ALTURA AUTO PARA 1080p = 1920:-1                      �
	echo �                                                                �
	echo �    NOTA: SI SE HA EFECTUA DETECCION DE BORDE NO FUNCIONA EL    �
	echo �          PARAMETRO -1 HAY QUE PONER LA RESOLUCION NUEVA        �
	echo �          ENTERA.                                               �
	echo �              EJEMPLO: 1280:720 (OK), 1280:-1 (ERROR)           �
	echo �                                                                �
	echo ����������������������������������������������������������������ͼ
	if not "!tfStreamV!" == "" (
		echo [VIDEO] - [INFO] - INFORMACION PISTA DE VIDEO:
		type !tfStreamV!
		echo.
	)
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
			echo [GLOBAL] - [VIDEO] - [MODIFICADO] - NUEVO TAMA�O: !InputNewOutNewSize!
		) else (
			echo [VIDEO] - [MODIFICADO] - NUEVO TAMA�O: !InputNewOutNewSize!
		)
		
	)
	set "%~2=!tmp_OutNewSize!"
	goto:eof
