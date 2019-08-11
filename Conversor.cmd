@echo off
cls
setlocal ENABLEDELAYEDEXPANSION
title Conversor 4.5

rem *********************************** CONVERSION DE FORMATOS MULTIMEDIA ***********************************
rem **                                                                                                     **
rem **  VERSION 4.5 - 08/01/2019                                                                           **
rem **  - NEW: A๑adir resolucion de aspecto 1.85:1, actualmente solo para 1080p.                           **
rem **                                                                                                     **
rem **                                                                                                     **
rem **  VERSION 4.4 - 27/10/2018                                                                           **
rem **  - FIX: Corriguir error en relacion de aspecto 2.35.                                                **
rem **                                                                                                     **
rem **                                                                                                     **
rem **  VERSION 4.3 - 27/08/2018                                                                           **
rem **  - UPDATE: Cambiar los 20 segundos de espera por 10 segundos.                                       **
rem **  - FIX: Ajustar la opcion por defecto de la seleccion de BitRate Video.                             **
rem **                                                                                                     **
rem **                                                                                                     **
rem **  VERSION 4.2 - 25/08/2018                                                                           **
rem **  - ADD: Nuevas calidades de audio, resoluciones y aspectos.                                         **
rem **                                                                                                     **
rem **                                                                                                     **
rem **  VERSION 4.1 - 21/08/2018                                                                           **
rem **  - NEW: Aคadir cuadro selecciขn para tipo de recodificaciขn solo audio o audio y video.             **
rem **  - UPDATE: Rediseคar cuadros de selecciขn.                                                          **
rem **  - UPDATE: Mover cuadro de selecciขn de codec de recodificaciขn de video dentro del bloque          **
rem **            de los par metros de opciones de video.                                                  **
rem **                                                                                                     **
rem **                                                                                                     **
rem **  VERSION 4.0 - 21/08/2018                                                                           **
rem **  - NEW: Aคadir detecciขn de si el Video y el audio empiezan a a la vez. Si no empiezan a la vez     **
rem **         se aคade un silencio del tiempo correspondiente a la diferencia de tiempo.                  **
rem **                                                                                                     **
rem **                                                                                                     **
rem **  - UPDATE: Aคadir pantallas para configurar todos los par metros de la recodificaciขn (fps,         **
rem **            bitrate, resolucion), se elimina la pantalla de las opciones est ticas.                  **
rem **                                                                                                     **
rem **                                                                                                     **
rem **  VERSION 3.4 - 13/08/2018                                                                           **
rem **  - FIX: Modificar texto de cabecera de compresiขn, si el video no se recodifica.                    **
rem **                                                                                                     **
rem **                                                                                                     **
rem **  VERSION 3.3 - 10/07/2018                                                                           **
rem **  - UPDATE: AฅADIR TWOLOOP A LA CONVERSION DE AUDIO                                                  **
rem **                                                                                                     **
rem **                                                                                                     **
rem **  VERSION 3.2 - 17/06/2018                                                                           **
rem **  - FIX: Al seleccionar la opciขn de compresiขn 5 y 6 siempre usa "gpu nvidia".                      **
rem **  - NEW: Definir variables para los path de los archivos dentro del for.                             **
rem **                                                                                                     **
rem **                                                                                                     **
rem **  VERSION 3.1 - 26/05/2018                                                                           **
rem **  - NEW: detectar SO bits (x86, x64) y support gpu nvidia                                            **
rem **                                                                                                     **
rem **                                                                                                     **
rem **  VERSION 3.0 - 09/11/2017                                                                           **
rem **                                                                                                     **
rem **  Inspirado en el cขdigo de Ghalager, alias Kalimero, alias Mikel                                    **
rem **                                                                                                     **
rem *********************************************************************************************************

REM https://fsymbols.com/es/teclado/windows/alt-codes/lista/



:VARIABLES
set _os_bitness=
set ffmpeg_bits=
set ffmpeg_threads=4
set ffmpeg_cv=
set InputType=
set OptionNoHead=
set OptionNoPause=
set OptionNoTemp=
set OutputAudioType=
set OutputVideoType=
set OutputVideoSize=
set OutputVideoAspect=
set OutputVideoFPS=
set OutputVideoBitrate=
set OutputCodec=




:CONFPROGSEGUNSO
set _os_bitness=64
IF %PROCESSOR_ARCHITECTURE% == x86 (
	IF NOT DEFINED PROCESSOR_ARCHITEW6432 Set _os_bitness=32
)
If %_os_bitness% == 32 (
	set ffmpeg_bits=x86
) ELSE If %_os_bitness% == 64 (
	set ffmpeg_bits=x64
) ELSE (
	echo "ERROR 1!"
	pause
	exit
)

 
rem echo      SISTEMA DE %_os_bitness% BITS 




:CONFIG_COLOR
cls
color 1e











:SELECTTYPEFILEOUT
cls
echo     ษออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออป
echo     บ ษออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออป บ
echo     บ บ                                                                              บ บ
echo     บ บ                      CONVERSION DE FORMATOS MULTIMEDIA                       บ บ
echo     บ บ                                                                              บ บ
echo     บ ฬออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออน บ
echo     บ ฬออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออน บ
echo     บ บ                                                                              บ บ
echo     บ บ  จQUE TIPO DE ARCHIVO DE SALIDA DESEAS?                                      บ บ
echo     บ บ                                                                              บ บ
echo     บ บ      1. AVI                                                                  บ บ
echo     บ บ      2. MP4                                                                  บ บ
echo     บ บ  [*] 3. MKV                                                                  บ บ
echo     บ บ                                                                              บ บ
echo     บ บ      4. ABORTAR / SALIR                                                      บ บ
echo     บ บ                                                                              บ บ
echo     บ ศออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออผ บ
echo     บ ษออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออผ
echo     บ บ  [*] EN 10 SEG. SE AUTO SELECCIONARA
echo     บ ศออออออออออออออออออออออออออออออออออออออป
echo     ศออออออออออออออออออออออออออออออออออออออออผ
echo.
@CHOICE /C:1234 /N /t 10 /d 3
IF "%ERRORLEVEL%"=="4" GOTO SEC_PROCESS_ABORT
IF "%ERRORLEVEL%"=="3" GOTO SELECTTYPEFILEOUT_OPT3
IF "%ERRORLEVEL%"=="2" GOTO SELECTTYPEFILEOUT_OPT2
IF "%ERRORLEVEL%"=="1" GOTO SELECTTYPEFILEOUT_OPT1
GOTO SEC_PROCESS_ABORT

:SELECTTYPEFILEOUT_OPT1
	set OutputAudioType=mp3
	set OutputVideoType=avi
	GOTO SELECTTYPEFILEOUT_END

:SELECTTYPEFILEOUT_OPT2
	set OutputAudioType=m4a
	set OutputVideoType=mp4
	GOTO SELECTTYPEFILEOUT_END
	
:SELECTTYPEFILEOUT_OPT3
	set OutputAudioType=m4a
	set OutputVideoType=mkv
	GOTO SELECTTYPEFILEOUT_END
	
	
:SELECTTYPEFILEOUT_END
color 1e











:SELECTTYPERECODIFICACION
cls
echo     ษออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออป
echo     บ ษออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออป บ
echo     บ บ                                                                              บ บ
echo     บ บ                      CONVERSION DE FORMATOS MULTIMEDIA                       บ บ
echo     บ บ                                                                              บ บ
echo     บ ฬออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออน บ
echo     บ ฬออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออน บ
echo     บ บ                                                                              บ บ
echo     บ บ  TIPO DE RECODIFICACION:                                                     บ บ
echo     บ บ                                                                              บ บ
echo     บ บ      1. SOLO AUDIO                                                           บ บ
echo     บ บ  [*] 2. AUDIO Y VIDEO                                                        บ บ
echo     บ บ                                                                              บ บ
echo     บ บ      3. ABORTAR / SALIR                                                      บ บ
echo     บ บ                                                                              บ บ
echo     บ ศออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออผ บ
echo     บ ษออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออผ
echo     บ บ  [*] EN 10 SEG. SE AUTO SELECCIONARA
echo     บ ศออออออออออออออออออออออออออออออออออออออป
echo     ศออออออออออออออออออออออออออออออออออออออออผ
echo.
@CHOICE /C:123 /N /t 10 /d 2
IF "%ERRORLEVEL%"=="3" GOTO SEC_PROCESS_ABORT
IF "%ERRORLEVEL%"=="2" GOTO SELECTTYPERECODIFICACION_OPT2
IF "%ERRORLEVEL%"=="1" GOTO SELECTTYPERECODIFICACION_OPT1
GOTO SEC_PROCESS_ABORT

:SELECTTYPERECODIFICACION_OPT1
	set InputType=1
	GOTO SELECTAUDIOBITRATE

:SELECTTYPERECODIFICACION_OPT2
	set InputType=2
	GOTO SELECTTYPERECODIFICACION_END
	
	
:SELECTTYPERECODIFICACION_END
color 1e











:SELECTVIDEOBITRATE
cls
echo.
echo     ษออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออป
echo     บ ษออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออป บ
echo     บ บ                                                                              บ บ
echo     บ บ                      CONVERSION DE FORMATOS MULTIMEDIA                       บ บ
echo     บ บ                                                                              บ บ
echo     บ ฬออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออน บ
echo     บ ฬออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออน บ
echo     บ บ                                                                              บ บ
echo     บ บ  BITRATE VIDEO:                                                              บ บ
echo     บ บ                                                                              บ บ
echo     บ บ      1. LD 240p 3G Mobile @ H.264 base profile   350 kbps (3 MB/min)         บ บ
echo     บ บ      2. LD 360p 4G Mobile @ H.264 main profile   700 kbps (6 MB/min)         บ บ
echo     บ บ      3. SD 480p WiFi      @ H.264 main profile  1200 kbps (10 MB/min)        บ บ
echo     บ บ  [*] 4. HD 720p           @ H.264 high profile  2500 kbps (20 MB/min)        บ บ
echo     บ บ      5. HD 1080p          @ H.264 high profile  5000 kbps (35 MB/min)        บ บ
echo     บ บ                                                                              บ บ
echo     บ บ      6. ABORTAR / SALIR                                                      บ บ
echo     บ บ                                                                              บ บ
echo     บ ศออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออผ บ
echo     บ ษออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออผ
echo     บ บ  [*] EN 10 SEG. SE AUTO SELECCIONARA
echo     บ ศออออออออออออออออออออออออออออออออออออออป
echo     ศออออออออออออออออออออออออออออออออออออออออผ
echo.
@CHOICE /C:123456 /N /t 10 /d 4
IF "%ERRORLEVEL%"=="6" GOTO SEC_PROCESS_ABORT
IF "%ERRORLEVEL%"=="5" GOTO SELECTVIDEOBITRATE_OPT5
IF "%ERRORLEVEL%"=="4" GOTO SELECTVIDEOBITRATE_OPT4
IF "%ERRORLEVEL%"=="3" GOTO SELECTVIDEOBITRATE_OPT3
IF "%ERRORLEVEL%"=="2" GOTO SELECTVIDEOBITRATE_OPT2
IF "%ERRORLEVEL%"=="1" GOTO SELECTVIDEOBITRATE_OPT1
GOTO SEC_PROCESS_ABORT
	
:SELECTVIDEOBITRATE_OPT1
	set OutputVideoBitrate=350
	GOTO SELECTVIDEOBITRATE_END

:SELECTVIDEOBITRATE_OPT2
	set OutputVideoBitrate=700
	GOTO SELECTVIDEOBITRATE_END
	
:SELECTVIDEOBITRATE_OPT3
	set OutputVideoBitrate=1200
	GOTO SELECTVIDEOBITRATE_END
	
:SELECTVIDEOBITRATE_OPT4
	set OutputVideoBitrate=2500
	GOTO SELECTVIDEOBITRATE_END
	
:SELECTVIDEOBITRATE_OPT5
	set OutputVideoBitrate=5000
	GOTO SELECTVIDEOBITRATE_END

:SELECTVIDEOBITRATE_END
color 1e




:SELECTVIDEOFPS
cls
echo.
echo     ษออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออป
echo     บ ษออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออป บ
echo     บ บ                                                                              บ บ
echo     บ บ                      CONVERSION DE FORMATOS MULTIMEDIA                       บ บ
echo     บ บ                                                                              บ บ
echo     บ ฬออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออน บ
echo     บ ฬออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออน บ
echo     บ บ                                                                              บ บ
echo     บ บ  FPS VIDEO:                                                                  บ บ
echo     บ บ                                                                              บ บ
echo     บ บ  [*] 1. 23.976 fps                                                           บ บ
echo     บ บ      2. 25.000 fps                                                           บ บ
echo     บ บ                                                                              บ บ
echo     บ บ      3. ABORTAR / SALIR                                                      บ บ
echo     บ บ                                                                              บ บ
echo     บ ศออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออผ บ
echo     บ ษออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออผ
echo     บ บ  [*] EN 10 SEG. SE AUTO SELECCIONARA
echo     บ ศออออออออออออออออออออออออออออออออออออออป
echo     ศออออออออออออออออออออออออออออออออออออออออผ
echo.
@CHOICE /C:123 /N /t 10 /d 1
IF "%ERRORLEVEL%"=="3" GOTO SEC_PROCESS_ABORT
IF "%ERRORLEVEL%"=="2" GOTO SELECTVIDEOFPS_OPT2
IF "%ERRORLEVEL%"=="1" GOTO SELECTVIDEOFPS_OPT1
GOTO SEC_PROCESS_ABORT

:SELECTVIDEOFPS_OPT1
	set OutputVideoFPS=23.976
	GOTO SELECTVIDEOFPS_END

:SELECTVIDEOFPS_OPT2
	set OutputVideoFPS=25
	GOTO SELECTVIDEOFPS_END

:SELECTVIDEOFPS_END
color 1e




:SELECTVIDEOASPECTO
cls
echo.
echo     ษออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออป
echo     บ ษออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออป บ
echo     บ บ                                                                              บ บ
echo     บ บ                      CONVERSION DE FORMATOS MULTIMEDIA                       บ บ
echo     บ บ                                                                              บ บ
echo     บ ฬออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออน บ
echo     บ ฬออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออน บ
echo     บ บ                                                                              บ บ
echo     บ บ  ASPECTO DEL VIDEO:                                                          บ บ
echo     บ บ                                                                              บ บ
echo     บ บ      1.    4:3  (1,33)                                                       บ บ
echo     บ บ      2.   12:5  (2,40) - (Panoramico - Normal en Peliculas)                  บ บ
echo     บ บ  [*] 3.   16:9  (1,78) - (Panoramico - Normal en Series)                     บ บ
echo     บ บ      4. 2.35:1  (2,35) - (Super35 - Peliculas usado en el CINE)              บ บ
echo     บ บ      5. 1.85:1  (1,85) - ()                                                  บ บ
echo     บ บ                                                                              บ บ
echo     บ บ      6. ABORTAR / SALIR                                                      บ บ
echo     บ บ                                                                              บ บ
echo     บ ศออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออผ บ
echo     ศออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออผ
echo.
@CHOICE /C:123456 /N
IF "%ERRORLEVEL%"=="6" GOTO SEC_PROCESS_ABORT
IF "%ERRORLEVEL%"=="5" GOTO SELECTVIDEOASPECTO_OPT5
IF "%ERRORLEVEL%"=="4" GOTO SELECTVIDEOASPECTO_OPT4
IF "%ERRORLEVEL%"=="3" GOTO SELECTVIDEOASPECTO_OPT3
IF "%ERRORLEVEL%"=="2" GOTO SELECTVIDEOASPECTO_OPT2
IF "%ERRORLEVEL%"=="1" GOTO SELECTVIDEOASPECTO_OPT1
GOTO SEC_PROCESS_ABORT

:SELECTVIDEOASPECTO_OPT1
	set OutputVideoAspect=4:3
	GOTO SELECTVIDEOASPECTO_END

:SELECTVIDEOASPECTO_OPT2
	set OutputVideoAspect=12:5
	GOTO SELECTVIDEOASPECTO_END

:SELECTVIDEOASPECTO_OPT3
	set OutputVideoAspect=16:9
	GOTO SELECTVIDEOASPECTO_END
	
:SELECTVIDEOASPECTO_OPT4
	set OutputVideoAspect=2.35
	GOTO SELECTVIDEOASPECTO_END
	
:SELECTVIDEOASPECTO_OPT5
	set OutputVideoAspect=1.85
	GOTO SELECTVIDEOASPECTO_END
	
:SELECTVIDEOASPECTO_END
color 1e




:SELECTVIDEORESOLUCION
cls
echo.
echo     ษอออออออออออออป
echo     บ ษอออออออออออผ
echo     บ บ CONFIGURADO PARA RECODIFICACION A: %OutputVideoAspect%
echo     บ ศออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออป
echo     บ ษออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออป บ
echo     บ บ                                                                                                  บ บ
echo     บ บ                      CONVERSION DE FORMATOS MULTIMEDIA                                           บ บ
echo     บ บ                                                                                                  บ บ
echo     บ ฬออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออน บ
echo     บ ฬออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออน บ
echo     บ บ                                                                                                  บ บ
echo     บ บ  RESOLUCION:                                                                                     บ บ
echo     บ บ                                                                                                  บ บ
echo     บ บ      1.             - 640x268   (12:5)   640x360  (16:9)   640x480 (4:3)                         บ บ
echo     บ บ      2. DVD/SD/NTSC - 720x304   (12:5)   720x480  (16:9)   720x576 (4:3)                         บ บ
echo     บ บ      3.             - 1024x428  (12:5)  1024x576  (16:9)  1024x768 (4:3)                         บ บ
echo     บ บ  [*] 4. HD Ready    - 1280x536  (12:5)  1280x720  (16:9)  1280x544 (2.35:1)                      บ บ
echo     บ บ      5. FullHD      - 1920x800  (12:5)  1920x1080 (16:9)  1920x816 (2.35:1)  1920x1040 (1.85:1)  บ บ
echo     บ บ      6. 4K          - 3840x2880 (12:5)  3840x2160 (16:9)                                         บ บ
echo     บ บ                                                                                                  บ บ
echo     บ บ      7. ABORTAR / SALIR                                                                          บ บ
echo     บ บ                                                                                                  บ บ
echo     บ ศออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออผ บ
echo     ศออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออผ
echo.
@CHOICE /C:1234567 /N
IF "%ERRORLEVEL%"=="7" GOTO SEC_PROCESS_ABORT
IF "%ERRORLEVEL%"=="6" GOTO SELECTVIDEORESOLUCION_OPT6
IF "%ERRORLEVEL%"=="5" GOTO SELECTVIDEORESOLUCION_OPT5
IF "%ERRORLEVEL%"=="4" GOTO SELECTVIDEORESOLUCION_OPT4
IF "%ERRORLEVEL%"=="3" GOTO SELECTVIDEORESOLUCION_OPT3
IF "%ERRORLEVEL%"=="2" GOTO SELECTVIDEORESOLUCION_OPT2
IF "%ERRORLEVEL%"=="1" GOTO SELECTVIDEORESOLUCION_OPT1
GOTO SEC_PROCESS_ABORT

:SELECTVIDEORESOLUCION_OPT1
	if /i "%OutputVideoAspect%" equ "4:3" (
		set OutputVideoSize=640x480
	) else if /i "%OutputVideoAspect%" equ "12:5" (
		set OutputVideoSize=640x268
	) else if /i "%OutputVideoAspect%" equ "16:9" (
		set OutputVideoSize=640x360
	)
	GOTO SELECTVIDEORESOLUCION_END
	
	
:SELECTVIDEORESOLUCION_OPT2
	if /i "%OutputVideoAspect%" equ "4:3" (
		set OutputVideoSize=720x576

	) else if /i "%OutputVideoAspect%" equ "12:5" (
		set OutputVideoSize=720x304
		
	) else if /i "%OutputVideoAspect%" equ "16:9" (
		set OutputVideoSize=720x480
	)
	GOTO SELECTVIDEORESOLUCION_END
	
	
:SELECTVIDEORESOLUCION_OPT3
	if /i "%OutputVideoAspect%" equ "4:3" (
		set OutputVideoSize=1024x768
	) else if /i "%OutputVideoAspect%" equ "12:5" (
		set OutputVideoSize=1024x428
	) else if /i "%OutputVideoAspect%" equ "16:9" (
		set OutputVideoSize=1024x576
	)
	GOTO SELECTVIDEORESOLUCION_END
	
	
:SELECTVIDEORESOLUCION_OPT4
	if /i "%OutputVideoAspect%" equ "12:5" (
		set OutputVideoSize=1280x536
	) else if /i "%OutputVideoAspect%" equ "16:9" (
		set OutputVideoSize=1280x720
	) else if /i "%OutputVideoAspect%" equ "2.35" (
		set OutputVideoSize=1280x544
		rem set OutputVideoAspect=16:9
		REM ************************************************************************************************************************ MODIFICADO LINEA ANTERIOR PARA EVITAR ERROR, HAY QUE MODIFICAR ASPECTO DESPUES DE RECODIFICAR.
	)

	GOTO SELECTVIDEORESOLUCION_END
	
	
:SELECTVIDEORESOLUCION_OPT5
	if /i "%OutputVideoAspect%" equ "12:5" (
		set OutputVideoSize=1920x800
	) else if /i "%OutputVideoAspect%" equ "16:9" (
		set OutputVideoSize=1920x1080
	) else if /i "%OutputVideoAspect%" equ "2.35" (
		set OutputVideoSize=1920x816
	) else if /i "%OutputVideoAspect%" equ "1.85" (
		set OutputVideoSize=1920x1040
	)
	set OutputVideoSize=1920:-1
	GOTO SELECTVIDEORESOLUCION_END
	

:SELECTVIDEORESOLUCION_OPT6
	if /i "%OutputVideoAspect%" equ "12:5" (
		set OutputVideoSize=3840x2880
	) else if /i "%OutputVideoAspect%" equ "16:9" (
		set OutputVideoSize=3840x2160
	)
	GOTO SELECTVIDEORESOLUCION_END

	
:SELECTVIDEORESOLUCION_END
if /i "%OutputVideoSize%" equ "" (
	echo "ASPECTO NO VALIDO. KO!"
	pause
	GOTO SELECTVIDEORESOLUCION
)


REM    240p  (424x240, 0.10 megapixels)
REM    360p  (640x360, 0.23 megapixels)
REM    432p  (768x432, 0.33 megapixels)
REM    480p  (848x480, 0.41 megapixels, "SD" or "NTSC widescreen")
REM    576p  (1024x576, 0.59 megapixels, "PAL widescreen")
REM    720p  (1280x720, 0.92 megapixels, "HD")
REM    1080p (1920x1080, 2.07 megapixels, "Full HD")
REM 	http://www.lighterra.com/papers/videoencodingh264/
REM		https://teradek.com/blogs/articles/what-is-the-optimal-bitrate-for-your-resolution

color 1e




:SELECTGPUOCPU
cls
echo. 
echo     ษออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออป
echo     บ ษออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออป บ
echo     บ บ                                                                              บ บ
echo     บ บ                      CONVERSION DE FORMATOS MULTIMEDIA                       บ บ
echo     บ บ                                                                              บ บ
echo     บ ฬออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออน บ
echo     บ ฬออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออน บ
echo     บ บ                                                                              บ บ
echo     บ บ  CODEC DE RECODIFICACION:                                                    บ บ
echo     บ บ                                                                              บ บ
echo     บ บ      1. CPU (libx264)                                                        บ บ
echo     บ บ  [*] 2. GPU (NVIDIA, h264_nvenc)                                             บ บ
echo     บ บ      3. CPU (libx265)                                                        บ บ
echo     บ บ      4. GPU (NVIDIA, h265_nvenc)                                             บ บ
echo     บ บ                                                                              บ บ
echo     บ บ      5. ABORTAR / SALIR                                                      บ บ
echo     บ บ                                                                              บ บ
echo     บ ศออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออผ บ
echo     บ ษออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออผ
echo     บ บ  [*] EN 10 SEG. SE AUTO SELECCIONARA
echo     บ ศออออออออออออออออออออออออออออออออออออออป
echo     ศออออออออออออออออออออออออออออออออออออออออผ
echo. 
@CHOICE /C:12345 /N /t 10 /d 2
IF "%ERRORLEVEL%"=="5" GOTO SEC_PROCESS_ABORT
IF "%ERRORLEVEL%"=="4" GOTO SELECTGPUOCPU_OPT4
IF "%ERRORLEVEL%"=="3" GOTO SELECTGPUOCPU_OPT3
IF "%ERRORLEVEL%"=="2" GOTO SELECTGPUOCPU_OPT2
IF "%ERRORLEVEL%"=="1" GOTO SELECTGPUOCPU_OPT1
GOTO SEC_PROCESS_ABORT

:SELECTGPUOCPU_OPT1
	set ffmpeg_cv=libx264
	set OutputCodec=h264
	GOTO SELECTGPUOCPU_END

:SELECTGPUOCPU_OPT2
	set ffmpeg_cv=h264_nvenc
	set OutputCodec=h264
	GOTO SELECTGPUOCPU_END

:SELECTGPUOCPU_OPT3
	set ffmpeg_cv=libx265
	set OutputCodec=h265
	GOTO SELECTGPUOCPU_END

:SELECTGPUOCPU_OPT4
	set ffmpeg_cv=hvec_nvenc
	set OutputCodec=h265
	GOTO SELECTGPUOCPU_END
	
:SELECTGPUOCPU_END
color 1e


















:SELECTAUDIOBITRATE
cls
echo.
echo     ษออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออป
echo     บ ษออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออป บ
echo     บ บ                                                                              บ บ
echo     บ บ                      CONVERSION DE FORMATOS MULTIMEDIA                       บ บ
echo     บ บ                                                                              บ บ
echo     บ ฬออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออน บ
echo     บ ฬออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออน บ
echo     บ บ                                                                              บ บ
echo     บ บ  BITRATE AUDIO:                                                              บ บ
echo     บ บ                                                                              บ บ
echo     บ บ  [*] 1. AUDIO 128 kbps                                                       บ บ
echo     บ บ      2. AUDIO 160 kbps                                                       บ บ
echo     บ บ      3. AUDIO 192 kbps                                                       บ บ
echo     บ บ      4. AUDIO 256 kbps                                                       บ บ
echo     บ บ      5. AUDIO 320 kbps                                                       บ บ
echo     บ บ                                                                              บ บ
echo     บ บ      6. ABORTAR / SALIR                                                      บ บ
echo     บ บ                                                                              บ บ
echo     บ ศออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออผ บ
echo     บ ษออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออผ
echo     บ บ  [*] EN 10 SEG. SE AUTO SELECCIONARA
echo     บ ศออออออออออออออออออออออออออออออออออออออป
echo     ศออออออออออออออออออออออออออออออออออออออออผ
echo.
@CHOICE /C:123456 /N /t 10 /d 1
IF "%ERRORLEVEL%"=="6" GOTO SEC_PROCESS_ABORT
IF "%ERRORLEVEL%"=="5" GOTO SELECTAUDIOBITRATE_OPT5
IF "%ERRORLEVEL%"=="4" GOTO SELECTAUDIOBITRATE_OPT4
IF "%ERRORLEVEL%"=="3" GOTO SELECTAUDIOBITRATE_OPT3
IF "%ERRORLEVEL%"=="2" GOTO SELECTAUDIOBITRATE_OPT2
IF "%ERRORLEVEL%"=="1" GOTO SELECTAUDIOBITRATE_OPT1
GOTO SEC_PROCESS_ABORT

:SELECTAUDIOBITRATE_OPT1
	set OutputAudioBitrate=128
	GOTO SELECTAUDIOBITRATE_END

:SELECTAUDIOBITRATE_OPT2
	set OutputAudioBitrate=160
	GOTO SELECTAUDIOBITRATE_END

:SELECTAUDIOBITRATE_OPT3
	set OutputAudioBitrate=192
	GOTO SELECTAUDIOBITRATE_END

:SELECTAUDIOBITRATE_OPT4
	set OutputAudioBitrate=256
	GOTO SELECTAUDIOBITRATE_END

:SELECTAUDIOBITRATE_OPT5
	set OutputAudioBitrate=320
	GOTO SELECTAUDIOBITRATE_END	
	
	
:SELECTAUDIOBITRATE_END
color 1e




















:LOCAL
color 1e
cls

echo.
echo ฺฤฤดณ INFO:
echo ณ   ณ 
if /i "%InputType%" equ "1" (
	echo ณ   รฤฤฤฤดณ USAR ENCODE: NONE
	echo ณ   ณ
	echo ณ   รฤฤฤฤดณ VIDEO: COPY
) else (
	if /i "%ffmpeg_cv%" equ "libx264"    echo ณ   รฤฤฤฤดณ USAR ENCODE: CPU - (x264)
	if /i "%ffmpeg_cv%" equ "h264_nvenc" echo ณ   รฤฤฤฤดณ USAR ENCODE: GPU - NVIDIA - (x264)
	if /i "%ffmpeg_cv%" equ "libx265"    echo ณ   รฤฤฤฤดณ USAR ENCODE: CPU - (x265)
	if /i "%ffmpeg_cv%" equ "hvec_nvenc" echo ณ   รฤฤฤฤดณ USAR ENCODE: GPU - NVIDIA - (x265)
	echo ณ   ณ
	echo ณ   รฤฤฤฤดณ NEW FPS:           %OutputVideoFPS% fps
	echo ณ   รฤฤฤฤดณ NEW RELACION:      %OutputVideoAspect%
	echo ณ   รฤฤฤฤดณ NEW RESOLUCION:    %OutputVideoSize%
	echo ณ   รฤฤฤฤดณ NEW VIDEO BITRATE: %OutputVideoBitrate% kbps
)
echo ณ   รฤฤฤฤดณ NEW AUDIO BITRATE: %OutputAudioBitrate% kbps
echo ณ   ภฤฤฤฤดณ NEW NEW EXTENSION: %OutputVideoType%
echo ณ
echo ณ
echo ณ
echo รฤฤดณ INICIANDO CONVERSION...
echo ณ   ณ
rem #no recursivo#


set tPathOrige=%~dp0Original
set tPathProce=%~dp0Proceso
set tPathConve=%~dp0Convertido
set tPathffmpeg="%~dp0tools\%ffmpeg_bits%\ffmpeg.exe"
set tPathaacgain="%~dp0tools\aacgain.exe"


If not exist "%tPathProce%" (mkdir "%tPathProce%")
If not exist "%tPathConve%" (mkdir "%tPathConve%")



for %%i in ("%tPathOrige%\*.avi" "%tPathOrige%\*.flv" "%tPathOrige%\*.mkv" "%tPathOrige%\*.mp4") do (
	
	set tProcFAudi="%tPathProce%\%%~ni.%OutputAudioType%"
	set tProcFConv="%tPathConve%\%%~ni.%OutputVideoType%"
	
	set tProcFInfo="%tPathProce%\%%~ni.info"
	set tProcFInfoB="%tPathProce%\%%~ni.info2"
	set tProcFInfoC="%tPathProce%\%%~ni.info3"
	set tProcFInfoD="%tPathProce%\%%~ni.info4"
	set tProcFInfoE="%tPathProce%\%%~ni.info5"
	set tProcFInfoF="%tPathProce%\%%~ni.info6"
	
	set tProcFixVol="%tPathProce%\%%~ni.fixvol"
	set tProcFixInitTime="0"
	
	
	

echo ณ   ณ	
echo ณ   รฤฤฤฤดณ PROCESANDO "%%~nxi"
echo ณ   ณ     ณ
	
	
	If exist !tProcFConv! (
echo ณ   ณ     ภฤฤฤฤดณ IGNORADO: YA ESTA RECODIFICADO!			
echo ณ   ณ
echo ณ   ณ
	) ELSE (
	
	
		REM ***** INI: PREPARANDO EL PROCESO *****
		
		
		If exist !tProcFInfo! (del /f /q !tProcFInfo!)
		If exist !tProcFInfoB! (del /f /q !tProcFInfoB!)
		If exist !tProcFInfoC! (del /f /q !tProcFInfoC!)
		If exist !tProcFInfoD! (del /f /q !tProcFInfoD!)
		If exist !tProcFInfoE! (del /f /q !tProcFInfoE!)
		If exist !tProcFInfoF! (del /f /q !tProcFInfoF!)
		If exist !tProcFixVol! (del /f /q !tProcFixVol!)
				
		del /f /q "ffmpeg2pass-0.*" 2>nul
		
		%tPathffmpeg% -i "%%~fi" 2> !tProcFInfo!
		
		
		REM ***** END: PREPARANDO EL PROCESO *****
		
		
		
		
		
		REM ***** INI: EXTRAER PISTA AUDIO *****
		if not exist !tProcFAudi! (
			set VarCheck=
			
			findstr.exe /i /c:"Audio: " !tProcFInfo! > !tProcFInfoB!
			if not errorlevel 1 (copy /y !tProcFInfoB! !tProcFInfoC! >nul)			
			
			findstr.exe /i /c:"Audio: " !tProcFInfo! | findstr.exe /i /c:"5.1" > !tProcFInfoB!
			if not errorlevel 1 (copy /y !tProcFInfoB! !tProcFInfoC! >nul)
			
			findstr.exe /i /c:"Audio: " !tProcFInfo! | findstr.exe /i /c:"(default)" > !tProcFInfoB!
			if not errorlevel 1 (copy /y !tProcFInfoB! !tProcFInfoC! >nul)
			
			findstr.exe /i /c:"Audio: " !tProcFInfo! | findstr.exe /i /c:"(default)" | findstr.exe /i /c:"5.1" > !tProcFInfoB!
			if not errorlevel 1 (copy /y !tProcFInfoB! !tProcFInfoC! >nul)
			
			findstr.exe /i /c:"Audio: " !tProcFInfo! | findstr.exe /i /c:"(spa)" > !tProcFInfoB!
			if not errorlevel 1 (copy /y !tProcFInfoB! !tProcFInfoC! >nul)
			
			findstr.exe /i /c:"Audio: " !tProcFInfo! | findstr.exe /i /c:"(spa)" | findstr.exe /i /c:"5.1" > !tProcFInfoB!
			if not errorlevel 1 (copy /y !tProcFInfoB! !tProcFInfoC! >nul)
			
			if exist !tProcFInfoC! (
				findstr.exe /i /c:"Input #0, avi" !tProcFInfo! >nul
				if not errorlevel 1 (
					for /f "tokens=2 delims=: usebackq" %%j in (!tProcFInfoC!) do ( 
						set VarCheck=%%j
					)
				) else (
					for /f "tokens=2 delims=: usebackq" %%j in (!tProcFInfoC!) do (
						for /f "tokens=1 delims=(" %%k in ("%%j") do ( 
							set VarCheck=%%k 
						) )
					)
					findstr.exe /i /c:"5.1" !tProcFInfoC! >nul
					if not errorlevel 1 (
						set VarCheck=!VarCheck!- 5.1 a stereo
					) else (
						set VarCheck=!VarCheck!- stereo
					)
					if /i "%OutputAudioType%" equ "m4a" (
						findstr.exe /i /c:"Audio: aac (LC)" !tProcFInfoC! | findstr.exe /i /c:"stereo" | findstr.exe /i /c:"44100 Hz">nul
					) else (
						findstr.exe /i /c:"Audio: %OutputAudioType%" !tProcFInfoC! | findstr.exe /i /c:"stereo" | findstr.exe /i /c:"44100 Hz">nul
					)
					
					if not errorlevel 1 (
echo ณ   ณ     ภฤฤฤฤดณ EXTRAYENDO AUDIO !VarCheck:~2! ^(pista !VarCheck:~,1!^)
						start "" /wait /min %tPathffmpeg% -i "%%~fi" -map 0:!VarCheck:~,1! -y -threads %ffmpeg_threads% -acodec copy !tProcFAudi!
					)
					
					if not exist !tProcFAudi! (
echo ณ   ณ     ภฤฤฤฤดณ CONVIERTIENDO AUDIO !VarCheck:~2! ^(pista !VarCheck:~,1!^)



						%tPathffmpeg% -i "%%~fi" -af "ashowinfo" -map 0:!VarCheck:~,1! -y -f alaw -frames:a !VarCheck:~,1! nul 2> !tProcFInfoE!
						findstr.exe  /i /c:"Parsed_ashowinfo" !tProcFInfoE! | findstr.exe /i /c:"pts_time" > !tProcFInfoF!
					
						set /p tProcFixInitTime=<!tProcFInfoF!
						for /f %%i in ('cscript /nologo AudioGetInitTimeOld.vbs "!tProcFixInitTime!"') do set tProcFixInitTime=%%i
						echo !tProcFixInitTime! > !tProcFInfoF!
						
						
						
						if /i !tProcFixInitTime! neq 0 (
echo ณ   ณ          ณรฤฤฤฤดณ EL AUDIO Y VIDEO INICIAN A LA VEZ = NO AUDIO INICIA [!tProcFixInitTime!] SEG MAS TARDE!!!!
							start "" /wait /min %tPathffmpeg% -f lavfi -i aevalsrc=0:d=!tProcFixInitTime! -i "%%~fi" -y -threads %ffmpeg_threads% -filter_complex "[0:a] [1:!VarCheck:~,1!] concat=n=2:v=0:a=1 [a]" -map [a] -ab %OutputAudioBitrate%k -ar 44100 -ac 2 -aac_coder twoloop !tProcFAudi!
						) else (
echo ณ   ณ          ณรฤฤฤฤดณ EL AUDIO Y VIDEO INICIAN A LA VEZ = OK
							start "" /wait /min %tPathffmpeg% -i "%%~fi" -map 0:!VarCheck:~,1! -y -threads %ffmpeg_threads% -ab %OutputAudioBitrate%k -ar 44100 -ac 2 -aac_coder twoloop !tProcFAudi!
						)
echo ณ   ณ          ณณ
					)
				)
				
				If exist !tProcFInfoB! (del /f /q !tProcFInfoB!)
				If exist !tProcFInfoC! (del /f /q !tProcFInfoC!)
				If exist !tProcFInfoC! (del /f /q !tProcFInfoE!)
				If exist !tProcFInfoC! (del /f /q !tProcFInfoF!)
				
			) else (
echo ณ   ณ     ภฤฤฤฤดณ ERROR: ALGO HA FALLADO AL PROCESAR LA PISTA DE AUDIO!
			)
			
			set VarCheck=
		)
		REM ***** END: EXTRAER PISTA AUDIO *****
		

		
		
		
		REM ***** INI: AJUSTE DEL VOLUMEN *****
		if exist !tProcFAudi! (
			set VarCheck=
			
echo ณ   ณ          ณภฤฤฤฤดณ ANALIZANDO VOLUMEN
			%tPathaacgain% /q !tProcFAudi! | findstr.exe /i /c:"Track" | findstr.exe /i /c:"mp3" > !tProcFixVol!
			for /f "tokens=2 delims=: usebackq" %%j in (!tProcFixVol!) do (
				set VarCheck=%%j
			)
			If exist !tProcFixVol! (del /f /q !tProcFixVol!)
				
			if !VarCheck! gtr 0 (
echo ณ   ณ          ณ      ภฤฤฤฤดณ APLICANDO AJUSTE RECOMENDADO !VarCheck!
				start "" /wait /min %tPathaacgain% /r /c /q !tProcFAudi!
			) else (
echo ณ   ณ          ณ      ภฤฤฤฤดณ IGNORANDO AJUSTE RECOMENDADO !VarCheck!
			)
			
			set VarCheck=
		)
		REM ***** END: AJUSTE DEL VOLUMEN *****
		
		
		
		
		
echo ณ   ณ          ณ
		
		
		
		
		
		REM ***** INI: PREOCESO DE RECODIFICACION DEL VIDEO *****
		if not exist !tProcFConv! (
			set VarCheck=
			
			findstr.exe /i /c:"Video: " !tProcFInfo! | findstr.exe /i /v /c:"Video: mjpeg" > !tProcFInfoD!
			if not errorlevel 1 (
				findstr.exe /i /c:"Input #0, avi" !tProcFInfo! >nul
				if not errorlevel 1 (
					for /f "tokens=2 delims=: usebackq" %%j in (!tProcFInfoD!) do ( 
						set VarCheck=%%j 
					)
				) else (
					for /f "tokens=2 delims=: usebackq" %%j in (!tProcFInfoD!) do (
						for /f "tokens=1 delims=(" %%k in ("%%j") do ( 
							set VarCheck=%%k 
						) )
					)
				)
			)
			
			If exist !tProcFInfoD! (del /f /q !tProcFInfoD!)

			if /i "!VarCheck!" neq "" (
echo ณ   ณ          ณณ CONVIRTIENDO VIDEO ...
					
				if exist !tProcFAudi! (
					if /i "%OutputVideoBitrate%" equ "" (
echo ณ   ณ           ภฤฤฤฤดณ COPIANDO ...
						start "" /wait /min %tPathffmpeg% -i "%%~fi" -i !tProcFAudi! -map 0:!VarCheck! -map 1:0 -y -threads %ffmpeg_threads% -vcodec copy -acodec copy !tProcFConv!
					) else (
echo ณ   ณ           รฤฤฤฤดณ PASADA 1/2
						if /i "%OutputCodec%" equ "h264" (
							echo %tPathffmpeg% -i "%%~fi" -i !tProcFAudi! -map 0:!VarCheck! -map 1:0 -y -threads %ffmpeg_threads% -pass 1 -s %OutputVideoSize% -aspect %OutputVideoAspect% -r %OutputVideoFPS% -vb %OutputVideoBitrate%k -c:v %ffmpeg_cv% -acodec copy !tProcFConv!
							pause
							start "" /wait /min %tPathffmpeg% -i "%%~fi" -i !tProcFAudi! -map 0:!VarCheck! -map 1:0 -y -threads %ffmpeg_threads% -pass 1 -s %OutputVideoSize% -aspect %OutputVideoAspect% -r %OutputVideoFPS% -vb %OutputVideoBitrate%k -c:v %ffmpeg_cv% -acodec copy !tProcFConv!
							
						)
						if /i "%OutputCodec%" equ "h265" (
							if /i "%ffmpeg_cv%" equ "libx265" (
								start "" /wait /min %tPathffmpeg% -i "%%~fi" -i !tProcFAudi! -map 0:!VarCheck! -map 1:0 -y -threads %ffmpeg_threads% -x265-params pass=1 -s %OutputVideoSize% -aspect %OutputVideoAspect% -r %OutputVideoFPS% -vb %OutputVideoBitrate%k -c:v %ffmpeg_cv% -acodec copy !tProcFConv!
							) else (
								start "" /wait /min %tPathffmpeg% -i "%%~fi" -i !tProcFAudi! -map 0:!VarCheck! -map 1:0 -y -threads %ffmpeg_threads% -x265-params pass=1 -s %OutputVideoSize% -aspect %OutputVideoAspect% -r %OutputVideoFPS% -vb %OutputVideoBitrate%k -c:v %ffmpeg_cv% -acodec copy !tProcFConv!
							)
						)
echo ณ   ณ           ภฤฤฤฤดณ PASADA 2/2
						if /i "%OutputCodec%" equ "h264" (
							start "" /wait /min %tPathffmpeg% -i "%%~fi" -i !tProcFAudi! -map 0:!VarCheck! -map 1:0 -y -threads %ffmpeg_threads% -pass 2 -s %OutputVideoSize% -aspect %OutputVideoAspect% -r %OutputVideoFPS% -vb %OutputVideoBitrate%k -c:v %ffmpeg_cv% -acodec copy !tProcFConv!
						)
						if /i "%OutputCodec%" equ "h265" (
							if /i "%ffmpeg_cv%" equ "libx265" (
								start "" /wait /min %tPathffmpeg% -i "%%~fi" -i !tProcFAudi! -map 0:!VarCheck! -map 1:0 -y -threads %ffmpeg_threads% -x265-params pass=2 -s %OutputVideoSize% -aspect %OutputVideoAspect% -r %OutputVideoFPS% -vb %OutputVideoBitrate%k -c:v %ffmpeg_cv% -acodec copy !tProcFConv!
							) else (
								start "" /wait /min %tPathffmpeg% -i "%%~fi" -i !tProcFAudi! -map 0:!VarCheck! -map 1:0 -y -threads %ffmpeg_threads% -x265-params pass=2 -s %OutputVideoSize% -aspect %OutputVideoAspect% -r %OutputVideoFPS% -vb %OutputVideoBitrate%k -c:v %ffmpeg_cv% -acodec copy !tProcFConv!
							)
						)
					)
				
				) else (
					if /i "%OutputVideoBitrate%" equ "" (
echo ณ   ณ           ภฤฤฤฤดณ COPIANDO ...
						start "" /wait /min %tPathffmpeg% -i "%%~fi" -map 0:!VarCheck! -y -threads %ffmpeg_threads% -vcodec copy -acodec copy !tProcFConv!
					) else (
echo ณ   ณ           รฤฤฤฤดณ PASADA 1/2
						if /i "%OutputCodec%" equ "h264" (
							start "" /wait /min %tPathffmpeg% -i "%%~fi" -map 0:!VarCheck! -y -threads %ffmpeg_threads% -pass 1 -s %OutputVideoSize% -aspect %OutputVideoAspect% -r %OutputVideoFPS% -vb %OutputVideoBitrate%k -c:v %ffmpeg_cv% -acodec copy !tProcFConv!
						)
						if /i "%OutputCodec%" equ "h265" (
							if /i "%ffmpeg_cv%" equ "libx265" (
								start "" /wait /min %tPathffmpeg% -i "%%~fi" -map 0:!VarCheck! -y -threads %ffmpeg_threads% -x265-params pass=1 -s %OutputVideoSize% -aspect %OutputVideoAspect% -r %OutputVideoFPS% -vb %OutputVideoBitrate%k -c:v %ffmpeg_cv% -acodec copy !tProcFConv!
							)
							else (
								start "" /wait /min %tPathffmpeg% -i "%%~fi" -map 0:!VarCheck! -y -threads %ffmpeg_threads% -x265-params pass=1 -s %OutputVideoSize% -aspect %OutputVideoAspect% -r %OutputVideoFPS% -vb %OutputVideoBitrate%k -c:v %ffmpeg_cv% -acodec copy !tProcFConv!
							)
						)
echo ณ   ณ           ภฤฤฤฤดณ PASADA 2/2
						if /i "%OutputCodec%" equ "h264" (
							start "" /wait /min %tPathffmpeg% -i "%%~fi" -map 0:!VarCheck! -y -threads %ffmpeg_threads% -pass 2 -s %OutputVideoSize% -aspect %OutputVideoAspect% -r %OutputVideoFPS% -vb %OutputVideoBitrate%k -c:v %ffmpeg_cv% -acodec copy !tProcFConv!
						)
						if /i "%OutputCodec%" equ "h265" (
							if /i "%ffmpeg_cv%" equ "libx265" (
								start "" /wait /min %tPathffmpeg% -i "%%~fi" -map 0:!VarCheck! -y -threads %ffmpeg_threads% -x265-params pass=2 -s %OutputVideoSize% -aspect %OutputVideoAspect% -r %OutputVideoFPS% -vb %OutputVideoBitrate%k -c:v %ffmpeg_cv% -acodec copy !tProcFConv!
							)
							else (
								start "" /wait /min %tPathffmpeg% -i "%%~fi" -map 0:!VarCheck! -y -threads %ffmpeg_threads% -x265-params pass=2 -s %OutputVideoSize% -aspect %OutputVideoAspect% -r %OutputVideoFPS% -vb %OutputVideoBitrate%k -c:v %ffmpeg_cv% -acodec copy !tProcFConv!
							)
						)
					)
				)
				
				del /f /q "ffmpeg2pass-0.*" 2>nul
			) else (
				if exist !tProcFAudi! (
echo ณ   ณ          ภฤฤฤฤดณ GUARDANDO CONVERSION...
					move /y !tProcFAudi! !tProcFConv! >nul
				)
			)
			
			if /i "%OptionNoTemp%" equ "NoTemp" (
				If exist !tProcFAudi! (del /f /q !tProcFAudi!)
				If exist !tProcFInfo! (del /f /q !tProcFInfo!)
			)
			
			set VarCheck=
		)
		REM ***** END: PREOCESO DE RECODIFICACION DEL VIDEO *****
	
		
echo ณ   ณ
echo ณ   ณ
	
	)
)

echo ณ   ณ
echo ภฤฤดณ CONVERSION COMPLETADA
if /i "%OptionNoPause%" neq "NoPause" (pause)
endlocal
goto :EOF





:SEC_PROCESS_ABORT
cls
echo. 
echo     ษออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออป
echo     บ ษออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออป บ
echo     บ บ                                                                              บ บ
echo     บ บ                           *** PROCESO ABORTADO ***                           บ บ
echo     บ บ                                                                              บ บ
echo     บ ศออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออผ บ
echo     ศออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออผ
echo.
goto :EOF