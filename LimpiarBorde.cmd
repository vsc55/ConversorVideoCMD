@echo off
cls
setlocal enabledelayedexpansion
title ClearBorde 2.2


rem *********************************** CONVERSION DE FORMATOS MULTIMEDIA ***********************************
rem **                                                                                                     **
rem **  VERSION 2.2 - 02/12/2019                                                                           **
rem **  - NEW:                                                                                             **
rem **       - CREAR FUNCION "CHECK_DIR_AND_CREATE" COMPROBAR SI EXISTEN LOS DIRECTORIO Y CREARLOS SI      **
rem **         NO EXISTEN.                                                                                 **
rem **       - CREAR FUNCION "CHECK_FILE_AND_FIX" PARA ELIMINAR CODIGO DUPLICADO                           **
rem **                                                                                                     **
rem **  - UPDATE:                                                                                          **
rem **       - IMPLEMENTAR "CHECK_DIR_AND_CREATE" Y "CHECK_FILE_AND_FIX" PARA LIMPIAR CODIGO               **
rem **                                                                                                     **
rem ** ----------------------------------------------------------------------------------------------------**
rem **                                                                                                     **
rem **  VERSION 2.1 - 01/12/2019                                                                           **
rem **  - NEW:                                                                                             **
rem **       - CREAR FUNCION PARA DESCARGAR ARCHIVOS DE INTERNET                                           **
rem **       - AL ARRANCAR COMPRUEBA SI EXISTEN LOS EJECUTABLES NECESARIOS Y SI ALGUNO NO EXISTE LO        **
rem **         DESCARGA DE INTERNET.                                                                       **
rem **                                                                                                     **
rem ** ----------------------------------------------------------------------------------------------------**
rem **                                                                                                     **
rem **  VERSION 2.0 - 28/11/2019                                                                           **
rem **  - NEW:                                                                                             **
rem **       - A¥ADIR MENU CON PERFILES PREDEFINIDOS DE LOS AJUSTES DE CODIFICACION, SE CREA UNA NUEVA     **
rem **         VARIABLE (all_profile) DONDE SE ESPECIFICA QUE PERFIL SE HA CARGADO.                        **
rem **       - CREAR NUEVA VARIABLE all_a_hz PARA LA RECODIFICACION DEL ADUIO.                             **
rem **                                                                                                     **
rem **  - UPDATE:                                                                                          **
rem **       - SEGMENTAR EL CODIGO EN DISTINTOS ARCHIVOS PARA UN MEJOR MANTENIMIENTO                       **
rem **                                                                                                     **
rem ** ----------------------------------------------------------------------------------------------------**
rem **                                                                                                     **
rem **  VERSION 1.9 - 18/04/2019                                                                           **
rem **  - NEW:                                                                                             **
rem **       - A¥ADIR A LA CODIFICAION DE VIDEO EL PARAMETOR DE "fps"                                      **
rem **       - A¥ADIR INFORMACION DE DURACION DE VIDEO AL INICIAR EL PROCESO                               **
rem **       - A¥ADIR A libx265 LA OPCION DE PROFILE Y LEVEL                                               **
rem **       - A¥ADIR A LA FUNCION RUN_EXE LA OPOCION DE CAPTURAR STDOUT, STDERR O LAS DOS                 **
rem **       - A¥ADIR FUNCION FUN_FILE_DELETE_FILE PARA BORRAR ARCHIVOS                                    **
rem **       - A¥ADIR MENSAJE PARA PODER ELIMINAR LA PISTA DE AUDIO O VIDEO QUE YA ESTA CODIFICADA Y PODER **
rem **         RECODIFICARLA OTRA VEZ                                                                      **
rem **       - A¥ADIR MENSAJE PARA PODER DECIR SI EL VIDEO DE DE ANIMACION O NO PARA ESPECIFICAR ESE TUNE  **
rem **                                                                                                     **
rem **  - UPDATE:                                                                                          **
rem **       - MODIFICAR libx265 PARA QUE EN VEZ DE USAR UN CFR FIJADO EN EL cmd USE EL QMIN QUE SE        **
rem **         CONFIGURA EL INICIO DEL PROCESO                                                             **
rem **       - MODIFICACIONES MENOS DE ALGUNOS TEXTOS INFORMATIVOS                                         **
rem **       - MODIFICAR EN VideoSizeReal_Crop_ClearLog PARA QUE RETORNE LA LISTA DE RESOLUCIONES          **
rem **         DETECTADAS Y EL NUMERO DE VECES QUE SE HA DETECTADO CADA UNA. AHORA EL LISTADO DE           **
rem **         RESOLUCIONES TAMBIEN SALE EL NUMERO DE VECES QUE SE HA DETECTADO ELIMINADO LAS QUE NO       **
rem **         SE REPITEN MAS DE 5 VECES                                                                   **
rem **       - REDISE¥AR LA OBTENCION DE DATOS DE QMIN Y QMAX                                              **
rem **       - ACTUALIZAR ALGUNOS TEXTOS DE MENSAJES                                                       **
rem **                                                                                                     **
rem **  - FIX:                                                                                             **
rem **       - BUG CODEC AAC, SI USAMOS EL CODEC ACC PARA CREAR ELSILENCIO Y UNIRLO A LA PISTA DE AUDIO    **
rem **         ESTE A¥ADE UNOS SEGUNDOS ENTRE LAS DOS PISTAS (SILENCIO + AUDIO) HACIENDO QUE SE EL VIDEO   **
rem **         Y EL AUDIO SE DESINCRONICE, SE USA UN ARTICHIO TEMPORAL WAv PARA A¥ADIR EL SILENCIO Y ESE   **
rem **         ARCHIVO ES EL QUE LUEGO SE RECODIFICA, CUANO SE SOLUCIONE EL BUG SE ELIMINARA ESE PROCESO   **
rem **         TEMPORAL: https://trac.ffmpeg.org/ticket/7846                                               **
rem **       - CORREGUIR EN LA FUNCION FUN_CLEAR_TRIM_COMILLAS PARA QUE BORRE TODAS LAS COMILLAS AL        **
rem **         COMIENZO Y AL FINAL CUANDO HAY MAS DE UNA                                                   **
rem **       - CORREGUIR EN RUN_EXE EL REENVIO DE STDOUT Y STDERR CON EL COMANDO START                     **
rem **                                                                                                     **
rem **   - DEL:                                                                                            **
rem **       - ELIMINAR EL PARAMETOR -dn DE LAS EJECUCIONES DE FFMPEG                                      **
rem **                                                                                                     **
rem ** ----------------------------------------------------------------------------------------------------**
rem **                                                                                                     **
rem **  VERSION 1.8 - 16/04/2019                                                                           **
rem **  - NEW:                                                                                             **
rem **       - SEPARAR LA CODIFICACION DEL VIDEO Y LA CREACION DEL ARCHIVO FINAL EN DOS PROCESOS DISTINTOS **
rem **         ProcessVideoFix SIGUE ENCARGANDOSE DE PREPARAR LA PISTA DE VIDEO Y ProcessMultiplexFiles    **
rem **         SE ENCARGA DE UNIR LA PISTA DE VIDEO+AUDIO+SUB                                              **
rem **                                                                                                     **
rem **  - FIX:                                                                                             **
rem **       - A¥ADIR ^ A LOS SIMBOLOS ESPECIALES COMO LAS ADMIRACIONES !                                  **
rem **       - SOLUCIONAR PROBLEMA EN LA PISTA DE AUDIO YA QUE ADEMAS DEL AUDIO COPIABA TAMBIEN LOS        **
rem **         CAPITULOS DEL MKV, AHORA YA SOLO SE COPIA LA PISTA DE AUDIO.                                **
rem **                                                                                                     **
rem ** ----------------------------------------------------------------------------------------------------**
rem **                                                                                                     **
rem **  VERSION 1.7 - 06/04/2019                                                                           **
rem **  - NEW:                                                                                             **
rem **       - A¥ADIR EN LA SECCION SELECT_ENCODE LA DETECCION SI ES H264 O H265 PARA PODER MODIFICAR LOS  **
rem **         PARAMETROS DE CONFIGURACION SEGUN EL CODEC                                                  **
rem **       - CREAR UN ARCHIVO DE DE PROCESADO NUEVO _info_stream.txt DONDE SE GUARDARAN TODAS LAS        **
rem **         STREAMS QUE TIENGA EL ARCHIVO                                                               **
rem **       - CREAR UNA NUEVA FUNCION FUN_CLEAR_TRIM_COMILLAS PARA ELIMINAR LAS COMILLAS A LA DRECHA HE   **
rem **         IZQUIERDA, POR EJEMPLO EJEMPLO EN UN ARCHIVO "OUT.MKV" SE QUEDARIA OUT.MKV                  **
rem **                                                                                                     **
rem **  - UPDATE:                                                                                          **
rem **       - ACTUALICAR ETIQUETAS DE POSICION EN LA SECCION SELECT                                       **
rem **       - ACTUALICAR LOS ECHO CON LA SECCION EN LA QUE SE ESTA EJECUTANDO [GLOBAL], [AUDIO], [VIDEO]  **
rem **       - AHORA LAS STREAM DE CADA TIPO SE OBTIENE DE _info_stream.txt EN VEZ DE  _info_ffmpeg.txt    **
rem **       - IMPLEMENTAR RUN_EXE EN UNOS CUANTOS PROCESOS DE LA SECCION VIDEO                            **
rem **                                                                                                     **
rem **  - FIX:                                                                                             **
rem **       - APLICAR ESTANDAR PARAMETROS INTERNOS.                                                       **
rem **       - ELIMINAR TODOS LOS () DE LOS ECHO Y CAMBIARLOS POR [] PARA EVITAR ERRORES                   **
rem **       - MODIFICAR TANTO EN AUDIO COMO EN VIDIO UNOS IF AL COMIENZO QUE TE HACIAN UN EXIT SUB SIN    **
rem **         EJECUTAR ENDLOCAL, AHORA ESOS IF SE EJECUTAN ANTES DE SETLOCAL                              **
rem **                                                                                                     **
rem ** ----------------------------------------------------------------------------------------------------**
rem **                                                                                                     **
rem **  VERSION 1.6 - 04/04/2019                                                                           **
rem **  - NEW:                                                                                             **
rem **       - CREAR AUDIOGETMAXVOL.VBS PARA COMPROBAR SI EL VOLUMEN ES CORRECTO O HAY QUE CORREGIRLO      **
rem **       - A¥ADIR FUNCION DEBUG EN LOS ARCHIVOS *.VBS                                                  **
rem **       - A¥ADIR SOPORTE PARA LA CORRECCION DEL VOLUMEN DE LOS ARCHIVOS CON AACGAIN. PARA CAMBIAR     **
rem **         ENTRE FFMPGE Y AACGAIN HAY QUE MODIFICAR LA VARIABLE default_a_process, DEFINIENDOLA COMO   **
rem **         set default_a_process=ACCGAIN PARA ACCGAIN Y set default_a_process=FFMPGE PARA FFMPEG       **
rem **       - A¥ADIR CONFIGURACION DEFAUL (default_a_hz) PARA LOS HZ EN LA RECODIFICACION DEL AUDIO       **
rem **       - A¥ADIR LA DETECCION DE SI EL ARCHIVO TIENE PISTAS DE VIDEO, AUDIO O SUBTITULOS              **
rem **                                                                                                     **
rem **  - UPDATE:                                                                                          **
rem **       - ACTUALIZAR AUDIOGETINITTIME.VBS PARA QUE SE ENCARGE DE LEER EL LOG DE FFMPG Y OBTENER       **
rem **         LOS SEGUNDOS DE DESFASE ENTRE AUDIO Y VIDEO                                                 **
rem **       - UNIR LA RECODIFICACION DEL AUDIO Y EL AJUSTE DEL VOLUMEN EN EL MISMO PROCESO                **
rem **       - ELIMINAR LA DETECCION DE LA PISTA DE AUDIO DEL CMD, AHORA LA OBTIENE AUDIOGETID.VBS         **
rem **       - A¥ADIR A LA FUNCION RUN_EXE LA OPCION DE QUE DATOS DESEAMOS CAPTURAR, SI QUEREMOS USAR      **
rem **         ( RUN > FILE) O ( RUN 2> FILE). POR DEFECTO SI NO SE PASA NADA SE USAR "2>" PARA USAR ">"   **
rem **         TENDREMOS QUE PASARLE EL PAREMETRO "1" ( > RUN_EXE !FileOut! 1 )                            **
rem **                                                                                                     **
rem **  - FIX:                                                                                             **
rem **       - SOLUCIONAR ERROR QUE SE PRODUCIA SI EL ARCHIVO NO TENIA SUBTITULOS                          **
rem **                                                                                                     **
rem **  - DEL:                                                                                             **
rem **       - ELIMINAR COMENTARIO NO NECESARIOS                                                           **
rem **                                                                                                     **
rem ** ----------------------------------------------------------------------------------------------------**
rem **                                                                                                     **
rem **  VERSION 1.5 - 01/04/2019                                                                           **
rem **  - NEW:                                                                                             **
rem **       - CREAR NUEVA FUNCION RUN_EXE PARA EJECUTAR PROGRAMA EXTERNOS Y CONTRLAR EL DEBUG             **
rem **       - A¥ADIR RECODIFICACION Y CONTROL DEL VOLUMEN EN LA PISTA DE AUDIO.                           **
rem **       - A¥ADIR MENU PARA PODER DEFINIR EL NUEVO BITRATE PARA LA PISTA DE AUDIO                      **
rem **       - A¥ADIR NUEVA OPCION DE ENCODE DE VIDEO LLAMADA COPY, DE ESTE MODO LA PISTA DE VIDEO SOLO    **
rem **         SE COPIARA NO SE EFECTUARA NINGUNA MODIFICACION. ESTO PUEDE USARSE SI SOLO SE QUIERE        **
rem **         RECODIFICAR LA PISTA DE AUDIO                                                               **
rem **                                                                                                     **
rem **  - UPDATE:                                                                                          **
rem **       - ETIQUETAR PROCESOS DE VIDEO Y AUDIO                                                         **
rem **       - IMPLEMENTAR NUEVA FUNCION RUN_EXE EN TODAS LAS EJECUCIONES EXTERNAS                         **
rem **       - ELIMINAR DEBUGMODE yesSTOP Y CREAR 2 NUEVOS PARA STOP AUDIO Y STOP VIDEO                    **
rem **                                                                                                     **
rem **  - FIX:                                                                                             **
rem **       - SOLUCIONAR PROBLEMA QUE PRODUCIA QUE NO SE COPIASEN LOS SUBTITULOS                          **
rem **                                                                                                     **
rem **  - DEL:                                                                                             **
rem **       - ELIMINAR CODIGO OBSOLETO O NO NECESARIO                                                     **
rem **                                                                                                     **
rem ** ----------------------------------------------------------------------------------------------------**
rem **                                                                                                     **
rem **  VERSION 1.4 - 31/03/2019                                                                           **
rem **  - NEW:                                                                                             **
rem **       - A¥ADIR PARAMETROS DE CONFIGURACION DE VALORES POR DEFECTO                                   **
rem **       - ACTUALIZAR SISTEMA DE DETECCION DE BORDES NUEVOS, AHORA SE ELIMINAN LAS RESOLUCIONES        **
rem **         DUPLICADAS Y DEFINIMOS EL SEGUDO DONDE DESEAMOS INICIAR EL MUESTRESO Y LA DURACION          **
rem **         DE DICHO MUESTREO.                                                                          **
rem **       - A¥ADOR SOPORTE PARA QMIN Y QMAX (DINAMICO) O UNA Q ESTATICA TANTO EN X264 COM X265.         **
rem **       - A¥ADIR -pix_fmt                                                                             **
rem **       - A¥ADIR CONFIGURACIONES GLOBALES COMO SI DESEASMOS OMITIR LA DETECCION DE BORDE A TODOS      **
rem **         LOS ARCHIVOS, O EL CAMBIO DE TAMA¥O.                                                        **
rem **  - UPDATE:                                                                                          **
rem **       - MOVER LOS CUADROS DE CONFIGURACION (CAMBIO TAMA¥O, PERFIL, ETC) A SUB FUNCIONES.            **
rem **       - AHORA DEFINIMOS SI ESTAMOS EN MODO DEBUG CREANDO UN ARCHIVO EN EL DIRECTORIO DONDE          **
rem **         ESTA EL SCRIPT "debug_on".                                                                  **
rem **                                                                                                     **
rem ** ----------------------------------------------------------------------------------------------------**
rem **                                                                                                     **
rem **  VERSION 1.3 - 03/02/2019                                                                           **
rem **  - NEW:                                                                                             **
rem **       - A¥ADIR SOPORTE H265 - GPU                                                                   **
rem **       - A¥ADIR SOPORTE H264 Y H265 - CPU                                                            **
rem **       - A¥ADIR SOPORTE PARA CAMBIAR DE TAMA¥O EL VIDEO                                              **
rem **       - A¥ADIR OPCION DE SOLO RECODIFICAR SIN DETECTAR BORDE                                        **
rem **       - A¥ADIR SECCION PARA RECODIFICAR AUDIO, AUNQUE NO HACE NADA AUN                              **
rem **       - CREAR FUNCION GetWidthByResolution PARA OBTENER LA ANCHURA DESDE UNA RESOLUCION             **
rem **  - UPDATE:                                                                                          **
rem **       - LA VAR (!RunFunction!) SE HA ELIMINADO DE CADA ENCODER Y SE EJECUTA AL FINAL                **
rem **       - CADA ENCODER AJUSTAR LAS NUEVAS VAR !video_f!, !video_e!, !audio_f!, !audio_e!, QUE         **
rem **         SE USARAN LUEGO AL EJECUTAR FFMPEG                                                          **
rem **  - DEL:                                                                                             **
rem **       - ELIMINAR CODIGO QUE USA BITRATE MANUAL                                                      **
rem **                                                                                                     **
rem ** ----------------------------------------------------------------------------------------------------**
rem **                                                                                                     **
rem **  VERSION 1.2 - 03/02/2019                                                                           **
rem **  - NEW:                                                                                             **
rem **       - A¥ADIR OPCION DEBUG PARA MOSTRAR MAS INFO (no/yes/yesSTOP).                                 **
rem **       - A¥ADIR SOPORTE PARA ENCODING POR CPU (libx264).                                             **
rem **       - SI NO SE OBTIENE EL BITRATE CON ffprobe SE LLAMA A MediaInfo PARA OBTENER INFO DEL BITRATE. **
rem **  - UPDATE:                                                                                          **
rem **       - REORGANIZAR CODIGO                                                                          **
rem **  - FIX:                                                                                             **
rem **       - ELIMINAR LAS DOS PASADAS CON CODIFICADOR NVIDIA YA QUE NO LO SOPORTA, A¥ADIR SOPORTE.       **
rem **                                                                                                     **
rem ** ----------------------------------------------------------------------------------------------------**
rem **                                                                                                     **
rem **  VERSION 1.1 - 28/01/2019                                                                           **
rem **  - NEW:                                                                                             **
rem **       - A¥ADIR OPACION PARA PODER EFECTUAR UN NUEVO MUESTRESO DE BORDES CON PARAMETROS DISTINTOS.   **
rem **                                                                                                     **
rem ** ----------------------------------------------------------------------------------------------------**
rem **                                                                                                     **
rem **  VERSION 1.0 - 19/01/2019                                                                           **
rem **  - NEW:                                                                                             **
rem **       - CREAR SCRIPT, SOPORTE UNICAMENTE A GPU (h264_nvenc).                                        **
rem **                                                                                                     **
rem *********************************************************************************************************




:: _stage > C = Config, G = Global, F = File
:VARIABLES
set _HACK_CHEKC_=1987
set _os_bitness=
set _debug=NO
set _debug_sa=NO
set _debug_sv=NO
set _stage=
set ffmpeg_bits=
set ffmpeg_threads=0
set ffmpeg_refs=4
set ffmpeg_fps=23.976
REM set ffmpeg_fps=25.000
set ffmpeg_cv=libx264
set ffmpeg_border_detect_star=0
set ffmpeg_border_detect_dura=20

set default_crf=21
set default_qmin=0
set default_qmax=23
set default_a_br=192k
set default_a_hz=44100
set default_a_process=ACCGAIN
rem set default_a_process=FFMPGE



REM PROFILE - CONFIG
REM set profile_default_animation=Y
set profile_default_animation=N




:CONFIGDEBUGMODE
If exist %~dp0debug_on (
	set _debug=YES
)
If exist %~dp0debug_stop_a (
	set _debug_sa=YES
)
If exist %~dp0debug_stop_v (
	set _debug_sv=YES
)





:CONFPROGSEGUNSO
set _os_bitness=64
IF %PROCESSOR_ARCHITECTURE% == x86 (
	IF NOT DEFINED PROCESSOR_ARCHITEW6432 Set _os_bitness=32
)
If %_os_bitness% == 32 (
	set ffmpeg_bits=x86
) ELSE If %_os_bitness% == 64 (
	set ffmpeg_bits=x64
)




:CONFIG_COLOR
cls
color 1e




if "%_debug%" == "YES" (
	echo.
	echo ***********************************************
	echo ************** DEBUG MODE ACTIVE **************
	echo ***********************************************
	echo.	
)



set _stage=C
set tPath=%~dp0
set tPathOrige=%~dp0Original
set tPathProce=%~dp0Proceso
set tPathConve=%~dp0Convertido
set tPathTools=%~dp0tools
set tPathFF=%tPathTools%\%ffmpeg_bits%
set tPathffmpeg="%tPathFF%\ffmpeg.exe"
set tPathffprobe="%tPathFF%\ffprobe.exe"
set tPathffplay="%tPathFF%\ffplay.exe"
set tPathaacgain="%tPathTools%\aacgain.exe"

set tURLBaseTools=https://raw.githubusercontent.com/vsc55/ConversorVideoCMD/master/tools


@call src\gen_func.cmd CHECK_DIR_AND_CREATE "%tPathProce%" _error_falta_algo
@call src\gen_func.cmd CHECK_DIR_AND_CREATE "%tPathConve%" _error_falta_algo
@call src\gen_func.cmd CHECK_DIR_AND_CREATE "%tPathTools%" _error_falta_algo
@call src\gen_func.cmd CHECK_DIR_AND_CREATE "%tPathFF%" _error_falta_algo
if DEFINED _error_falta_algo (
	echo.
	echo *** EXIT: ERROR CODE 1^!
	pause
	exit /b 1
)

@call src\gen_func.cmd CHECK_FILE_AND_FIX "%tPathffmpeg%" "%tURLBaseTools%/%ffmpeg_bits%/ffmpeg.exe" "ERROR: No se ha localizado el programa FFMPEG ^(%ffmpeg_bits%^)^^^^^^^!" _error_falta_algo
@call src\gen_func.cmd CHECK_FILE_AND_FIX "%tPathffprobe%" "%tURLBaseTools%/%ffmpeg_bits%/ffprobe.exe" "ERROR: No se ha localizado el programa FFPROBE ^(%ffmpeg_bits%^)^^^^^^^!" _error_falta_algo
@call src\gen_func.cmd CHECK_FILE_AND_FIX "%tPathffplay%" "%tURLBaseTools%/%ffmpeg_bits%/ffplay.exe" "ERROR: No se ha localizado el programa FFPLAY ^(%ffmpeg_bits%^)^^^^^^^!" _error_falta_algo
@call src\gen_func.cmd CHECK_FILE_AND_FIX "%tPathaacgain%" "%tURLBaseTools%/aacgain.exe" "No se ha localizado el programa AACGAIN^^^^^^^!" _error_falta_algo
if DEFINED _error_falta_algo (
	echo.
	echo *** EXIT: ERROR CODE 2^!
	pause
	exit /b 2
)



set OutputVideoFormat=matroska
set OutputVideoType=mkv
set tfInfoffmpeg=
set tfInfoBordeA=
set tfInfoBordeE=
set tfInfoBordeC=
set tfInfoSizeOrig=
set tfInfoDuration=
set tfInfoTestPlay=
set tfStreamV_NULL=
set tfStreamV=
set tfStreamA_NULL=
set tfStreamA=
set tfStreamA_A=
set tfStreamA_I=
set tfStreamS_NULL=
set tfStreamS=
set tfInfoFixVol=
set tfInfoFixVolR=
set tfInfoFixInitTime=
set tfInfoFixInitTimeR=
set tfProcesAudio=
set tfProcesAudioConcat=
set tfProcesAudioSilencio=
set tfProcesVideo=
set tPathFileOrig=
set tPathFileConvrt=
set tFileName=


:: GLOBALES - AJUESTES DE RECODIFICACION
:: ffmpeg_cv = [copy|hevc_nvenc|libx265|h264_nvenc|libx264]
:: all_v_profile = [baseline|main|main10|etc...]
:: all_v_level = [4|5|5.2|etc...]
:: all_qmin = 0    q minimo -> nvenc
:: all_qmax = 23   q maximo -> nvenc
:: all_crv= 23      -> libx265 y libx264
:: all_detect_borde = [NO|YES]
:: all_change_size = [NO|1920:-1|1280:-1]
:: all_a_bitrate = [96K|192K|lo que quieras]
:: TODO: all_a_hz, all_v_encoder que remplace a ffmpeg_cv

set all_v_encoder=
set all_qmin=
set all_qmax=
set all_crv=
set all_detect_borde=
set all_change_size=
set all_v_profile=
set all_v_level=
set all_a_bitrate=
set all_a_hz=
set all_profile=


:INIT_SELECT_PROFILE
set _stage=G
echo.
@call src\select_profile.cmd SELECT_PROFILE
echo.
@call src\select_profile.cmd PRINT_CONFIG_GLOBAL
echo.
if "!all_profile!" == "" (
	echo ERROR: No se ha seleccionado ningun perfil.
	exit
)
:SKIP_SELECT_PROFILE



for %%i in ("%tPathOrige%\*.avi" "%tPathOrige%\*.flv" "%tPathOrige%\*.mkv" "%tPathOrige%\*.mp4") do (
	
	set _stage=F
	set tfInfoffmpeg="%tPathProce%\%%~ni_info_ffmpeg.txt"
	set tfInfoBordeA="%tPathProce%\%%~ni_info_borde0.txt"
	set tfInfoBordeE="%tPathProce%\%%~ni_info_borde1.txt"
	set tfInfoBordeC="%tPathProce%\%%~ni_info_borde2.txt"
	set tfInfoSizeOrig="%tPathProce%\%%~ni_info_size_orig.txt"
	set tfInfoTestPlay="%tPathProce%\%%~ni_info_test_play.txt"
	set tfInfoDuration="%tPathProce%\%%~ni_info_duration.txt"
	set tfStreamAll="%tPathProce%\%%~ni_info_stream.txt"
	set tfStreamV="%tPathProce%\%%~ni_info_stream_video.txt"
	set tfStreamA="%tPathProce%\%%~ni_info_stream_audio.txt"
	set tfStreamA_A="%tPathProce%\%%~ni_info_stream_audio_A.txt"
	set tfStreamA_I="%tPathProce%\%%~ni_info_stream_audio_ID.txt"
	set tfStreamS="%tPathProce%\%%~ni_info_stream_sub.txt"
	set tfInfoFixVol="%tPathProce%\%%~ni_info_fix_vol.txt"
	set tfInfoFixVolR="%tPathProce%\%%~ni_info_fix_vol_r.txt"
	set tfInfoFixInitTime="%tPathProce%\%%~ni_info_fix_inittime.txt"
	set tfInfoFixInitTimeR="%tPathProce%\%%~ni_info_fix_inittime_r.txt"
	
	
	set tfProcesAudio="%tPathProce%\%%~ni.m4a"
	set tfProcesAudioConcat="%tPathProce%\%%~ni_concat.wav"
	set tfProcesAudioSilencio="%tPathProce%\%%~ni_silencio.m4a"
	
	
	set tfProcesVideo="%tPathProce%\%%~ni.mkv"
	if "%ffmpeg_cv%" == "h264_nvenc" (
rem		set tfProcesVideo="%tPathProce%\%%~ni.avc"
	) else if "%ffmpeg_cv%" == "hevc_nvenc" (
rem		set tfProcesVideo="%tPathProce%\%%~ni.hevc"
	) else if "%ffmpeg_cv%" == "libx264" (
rem		set tfProcesVideo="%tPathProce%\%%~ni.avc"
	) else if "%ffmpeg_cv%" == "libx265" (
rem		set tfProcesVideo="%tPathProce%\%%~ni.hevc"
	) else if "%ffmpeg_cv%" == "copy" (
		set tfProcesVideo=
	)
	
	
	
	
	
	REM INFO: NOMBRE DEL ARCHIVO A PROCESAR CON SU PATH COMPLETO.
	set tPathFileOrig=%2
	
	REM INFO: NOMBRE DEL ARCHIVO YA PROCESADO CON SU PATH COMPLETO.
	set tPathFileConvrt=%3
	
	REM INFO: NOMBRE DEL ARCHIVO A PROCESAR SIN PATH, SOLO EL NOMBRE DEL ARCHIVO.
	set tFileName=%1
	
	
	
	REM INFO: NOMBRE DEL ARCHIVO A PROCESAR CON SU PATH COMPLETO.
	set tPathFileOrig="%%~fi"
	
	REM INFO: NOMBRE DEL ARCHIVO YA PROCESADO CON SU PATH COMPLETO.
	set tPathFileConvrt="%tPathConve%\%%~ni.%OutputVideoType%"
	
	REM INFO: NOMBRE DEL ARCHIVO A PROCESAR SIN PATH, SOLO EL NOMBRE DEL ARCHIVO.
	set tFileName="%%~nxi"
	
	
	
	echo.
	echo ********************************
	echo [GLOBAL] - [INFO] - PROCESANDO: %%~nxi
	If exist !tPathFileConvrt! (
		echo [GLOBAL] - [SKIP] - YA SE HA PROCESADO^!
		echo.
	) else (
		
		@call src\gen_func.cmd FUN_FILE_DELETE_FILE !tfInfoffmpeg!
		@call src\gen_func.cmd FUN_FILE_DELETE_FILE !tfInfoDuration!
		
		REM GET INFO GENERAL DEL ARCHIVO CON FFMPEG
		set RunFunction=%tPathffmpeg% -i !tPathFileOrig!
		@call src\gen_func.cmd RUN_EXE 2 !tfInfoffmpeg!
		set RunFunction=
		
		
		REM **** DURACION DEL VIDEO
		set RunFunction=%tPathffprobe% -v error -show_entries format=duration -sexagesimal -of default=noprint_wrappers=1:nokey=1 !tPathFileOrig!
		@call src\gen_func.cmd RUN_EXE 1 !tfInfoDuration!
		set RunFunction=
		set /p tDuration=<!tfInfoDuration!
		for /f "delims=." %%A in ("!tDuration!") do set tDuration=%%~A
		echo [GLOBAL] - [INFO] - DURACION: !tDuration!
		echo.
		
		
		@call src\gen_func.cmd FUN_FILE_DELETE_FILE !tfStreamAll!
		@call src\gen_func.cmd FUN_FILE_DELETE_FILE !tfStreamS!
		@call src\gen_func.cmd FUN_FILE_DELETE_FILE !tfStreamA!
		@call src\gen_func.cmd FUN_FILE_DELETE_FILE !tfStreamV!
		
		set tfStreamS_NULL=YES
		set tfStreamA_NULL=YES
		set tfStreamV_NULL=YES
		
		findstr.exe /i /c:"Stream " !tfInfoffmpeg! > !tfStreamAll!
		
		findstr.exe /i /c:"Subtitle: " !tfStreamAll! > !tfStreamS!
		if not errorlevel 1 (set tfStreamS_NULL=NO)
		
		findstr.exe /i /c:"Audio: " !tfStreamAll! > !tfStreamA!
		if not errorlevel 1 (set tfStreamA_NULL=NO)
		
		findstr.exe /i /c:"Video: " !tfStreamAll! > !tfStreamV!
		if not errorlevel 1 (set tfStreamV_NULL=NO)
		
		if "!tfStreamS_NULL!" == "NO" (
			set _stage=FS
			rem call :ProcessSubFix
			rem echo.
		)
		if "!tfStreamA_NULL!" == "NO" (
			set _stage=FA
			call :ProcessAudioFix
			echo.
		)
		if "!tfStreamV_NULL!" == "NO" (
			set _stage=FV
			call :ProcessVideoFix
			echo.
		)
		
		
		set _stage=FM
		call :ProcessMultiplexFiles
		echo.
		
		
		echo [GLOBAL] - [INFO] - FINALIZADO PROCESADO
		echo ********************************
		echo.
	)
)


echo.
echo [GLOBAL] - [END] - TODOS LOS ARCHIVOS HAN SIDO PROCESADOS
pause
GOTO :eof





:ProcessMultiplexFiles
	
	if "%tfStreamV_NULL%" == "YES" (
		echo [MULTIPLEX] - [SKIP] - NO SE HAN DETECTADO NINGUNA PISTA DE VIDEO^!
		GOTO :eof
	)
	If exist !tPathFileConvrt! (
		echo [MULTIPLEX] - [SKIP] - YA SE HA PROCESADO^!
		GOTO :eof
	)
	if not exist !tfProcesAudio! (
		echo [MULTIPLEX] - [STOP] - EL ARCHIVO DE LA PISTA DE AUDIO NO SE HA LOCALIZADO^!
		GOTO :eof
	)
	
	SETLOCAL
	echo [MULTIPLEX] - PROGRESO INICIANDO...
	
	set map_ord=
	set metadata_all=
	set metadata_v=
	set metadata_a=
	set metadata_s=
	
	set RunFunction=%tPathffmpeg% -hide_banner -y -threads %ffmpeg_threads%
	
	If exist !tfProcesVideo! (
		set RunFunction=!RunFunction! -i !tfProcesVideo!
	) else (
		set RunFunction=!RunFunction! -i !tPathFileOrig!
	)
	set RunFunction=!RunFunction! -i !tfProcesAudio!
	
	if "%tfStreamS_NULL%" == "NO" (
		If exist !tfProcesVideo! (
			set RunFunction=!RunFunction! -i !tPathFileOrig!
		)
	)
	
	
	
	set map_ord=!map_ord! -map 0:0
	set map_ord=!map_ord! -map 1:a:0
	if "%tfStreamS_NULL%" == "NO" (
		rem set map_ord=!map_ord! -map 0:m:language:spa
		If exist !tfProcesVideo! (
			set map_ord=!map_ord! -map 2:s
		) else (
			set map_ord=!map_ord! -map 0:s
		)
	)
	
	
	
	rem **** este ejemplo seria para solo la pista 0 de audio
	rem set metadata_s=!metadata_s! -metadata:s:a:0 title=""
	
	set metadata_all=-metadata title=""
	
	set metadata_v=!metadata_v! -metadata:s:v title=""
	set metadata_v=!metadata_v! -metadata:s:v language=und
	
	set metadata_a=!metadata_a! -metadata:s:a title=""
	set metadata_a=!metadata_a! -metadata:s:a language=spa
	
	if "%tfStreamS_NULL%" == "NO" (
		set metadata_s=!metadata_s! -metadata:s:s title=""
		set metadata_s=!metadata_s! -metadata:s:s language=spa
	)
	
	echo [MULTIPLEX] - PROCESANDO....
	
	set RunFunction=!RunFunction! !metadata_all! !metadata_a! !metadata_v! !metadata_s! !map_ord! -c:v copy -c:s copy -c:a copy -f %OutputVideoFormat% !tPathFileConvrt!
	@call src\gen_func.cmd RUN_EXE
	set RunFunction=
	
	
	if not "%_debug%" == "YES" (
		@call src\gen_func.cmd FUN_FILE_DELETE_FILE !tfProcesVideo!
		rem	@call src\gen_func.cmd FUN_FILE_DELETE_FILE !tfProcesAudio!
	)
	
	echo [MULTIPLEX] - FINALIZADO
	ENDLOCAL
	GOTO :eof







	





REM ***************************************************
REM ****           VIDEO - VIDEO - VIDEO           ****
REM ***************************************************

:ProcessVideoFix

	if "%_debug_sv%" == "YES" (
		rem ******** DEBUG!!!!!!!!!!!!!!!!
		echo [VIDEO] - tPathFileOrig:   %tPathFileOrig%
		echo [VIDEO] - tPathFileConvrt: %tPathFileConvrt%
		echo [VIDEO] - tFileName:       %tFileName%
		echo [VIDEO] - tfInfoffmpeg:    %tfInfoffmpeg%
		echo.
		pause
		GOTO :eof
		rem ******** DEBUG!!!!!!!!!!!!!!!!
	)

	if "%tfStreamV_NULL%" == "YES" (
		echo [VIDEO] - [SKIP] - NO SE HAN DETECTADO NINGUNA PISTA DE VIDEO^!
		GOTO :eof
	)
	If exist !tPathFileConvrt! (
		echo [VIDEO] - [SKIP] - YA SE HA PROCESADO^!
		GOTO :eof
	)
	If exist !tfProcesVideo! (
		@CHOICE /C:YN /d N /t 10 /M "[VIDEO] - LA PISTA DE VIDEO YA SE HA PROCESADO ¨QUIERES VOLVER A PROCESARLA [AUDO **NO** EN 10 SEG]"
		IF Errorlevel 2 GOTO VIDEO_CHOICE_PROCESAR_OTRA_VEZ_NO
		IF Errorlevel 1 GOTO VIDEO_CHOICE_PROCESAR_OTRA_VEZ_SI
		GOTO :eof
		
		:VIDEO_CHOICE_PROCESAR_OTRA_VEZ_NO
		echo [VIDEO] - [SKIP] - PISTA DE VIDEO YA PROCESADA^!
		GOTO :eof
		
		:VIDEO_CHOICE_PROCESAR_OTRA_VEZ_SI
		@call src\gen_func.cmd FUN_FILE_DELETE_FILE !tfProcesVideo!
	)
	REM ** SI SE DEFINE COPY NO HAY QUE HACER NADA CON EL VIDEO POR LO QUE SALTAMOS A LA EJECUCION DE FFMPEG **
	if "%ffmpeg_cv%" == "copy" ( 
		echo [VIDEO] - [SKIP] - SE COPIAR LA PISTA ORIGINAL^!
		GOTO :eof
	)	
	
	
	SETLOCAL
	
	echo [VIDEO] - [PROGRESS] - INICIANDO...
	
	REM *** ELIMINA LAS COMILLAS AL COMIENZO Y AL FINAL DEL NOMBRE DEL ARCHIVO
	@call src\gen_func.cmd FUN_CLEAR_TRIM_COMILLAS tFileName
	
	
	@call src\gen_func.cmd FUN_FILE_DELETE_FILE !tfInfoBordeA!
	@call src\gen_func.cmd FUN_FILE_DELETE_FILE !tfInfoBordeE!
	@call src\gen_func.cmd FUN_FILE_DELETE_FILE !tfInfoBordeC!
	@call src\gen_func.cmd FUN_FILE_DELETE_FILE !tfInfoSizeOrig!
	@call src\gen_func.cmd FUN_FILE_DELETE_FILE !tfInfoTestPlay!
	REM TODO: PENDIENTE COMPROBAR SI LA FUNCION DE BORRADO FUNCIONA TAMBIEN CON COMODINES.
	del /f /q "ffmpeg2pass-0.*" 2>nul
	
	
	set tSizeReal_crop=
	set tSizeReal_size=
	set tSizeOrig_size=
	set tWidthOrig=
	
	
	
	REM ******************************
	REM *** GET INFO FILE ORIGINAL ***
	REM ******************************
	
	REM **** Resolucion orginal
	set RunFunction=%tPathffprobe% -v error -select_streams v:0 -show_entries stream=width,height -of csv=s=x:p=0 !tPathFileOrig!
 	@call src\gen_func.cmd RUN_EXE 1 !tfInfoSizeOrig!
 	set RunFunction=
	set /p tSizeOrig_size=<!tfInfoSizeOrig!
	REM ******************************
	REM ******************************
	
	
	
	
	
	
	REM ********************************************************
	REM *** DETECCION DEL TAMA¥O DEL VIDEO SIN BORDES NEGROS ***
	REM ********************************************************
	
	if "%all_detect_borde%" == "NO" (
		echo [VIDEO] - [SKIP] - NO SE EFECTUA DETECCION DE BORDES NEGROS [GLOBAL]
		goto RESIZE_VIDEO_INIT
	)
	@CHOICE /C:YN /d Y /t 10 /M "[VIDEO] - ¨DESEAS DETECTAR BORDE NEGRO SUPERIOR HE INFERIOR [AUTO **SI** EN 10 SEG]"
	IF Errorlevel 2 GOTO RESIZE_VIDEO_INIT
	IF Errorlevel 1 GOTO DETECT_BORDER_INIT
	GOTO :eof
	
	
	:DETECT_BORDER_INIT
	echo [VIDEO] - [PROGRESS] - DETECTANDO TAMA¥O REAL SIN BORDES...
	set tDetectStar=%ffmpeg_border_detect_star%
	set tDetectDura=%ffmpeg_border_detect_dura%
	
	@call src\gen_func.cmd GetWidthByResolution x %tSizeOrig_size% tWidthOrig
	
	
	:DETECT_BORDER_INIT_SCAN
	set tDetectNewScan=NONE
	set tSizeReal_crop=
	set /a tDetectStop=!tDetectStar! + !tDetectDura!
	
	
	echo [VIDEO] - [PROGRESS] - INICIANDO SCAN DE BORDES DE !tDetectDura! SEGUNDOS EMPEZANDO DESDE EL SEGUNDO !tDetectStar!...
	set RunFunction=%tPathffmpeg% -ss !tDetectStar! -to !tDetectStop! -i !tPathFileOrig! -vf cropdetect -f null -
 	@call src\gen_func.cmd RUN_EXE 2 !tfInfoBordeA!
 	set RunFunction=
	
	
	
	
	echo [VIDEO] - [PROGRESS] - ANALIZANDO RESULTADOS...
	findstr.exe  /i /c:"Parsed_cropdetect_" !tfInfoBordeA! > !tfInfoBordeE!
	cscript /nologo VideoSizeReal_Crop_ClearLog.vbs !tfInfoBordeE! !tfInfoBordeC!
	IF errorlevel 3 echo "ERROR 3"
	IF errorlevel 2 echo "ERROR 2"
	IF errorlevel 1 echo "ERROR 1"
	
	if "%_debug%" == "YES" (
		echo [VIDEO] - [DEBUG] - STOP DEPUES DE ANALIZAR RESULTADOS ^!^!^!^!
		PAUSE
	)
	
	
	for /F "usebackq tokens=*" %%i in (!tfInfoBordeC!) do (
		FOR /f "tokens=1,2 delims=-" %%a IN ("%%i") do (
			rem RES: %%a
			rem count: %%b
			for /f "delims=:" %%A in ("%%a") do (
				if %%~A == !tWidthOrig! (
					if %%b GTR 5 (
						echo [VIDEO]   -- MUESTRA: %%a  -- REPETIDA: %%b 
						set tSizeReal_crop=%%a
					) else (
						if "%_debug%" == "YES" (echo [VIDEO] - [DEBUG] - ORIG ^(!tWidthOrig!^) - MUESTRA ^(%%A^) - COUNT ^(%%b^) - MUESTRA_ALL ^(%%i^)   - NO VALIDA^!^!^!^!^!)
					)
				) else (
					if "%_debug%" == "YES" (echo [VIDEO] - [DEBUG] - ORIG ^(!tWidthOrig!^) - MUESTRA ^(%%a^) - MUESTRA_ALL ^(%%i^)   - NO VALIDA^!^!^!^!^!)
				)
			)
		)
	)
	
	
	echo.
	if "!tSizeReal_crop!" == "" (
		SET tDetectNewScan=YES
		echo [VIDEO] - NO SE ENCONTRO NINGUNA MUESTRA VALIDA, A¥ADA NUEVOS DATOS DE MUESTREO:
	) else (
		
		@CHOICE /C:YN /M "[VIDEO] - ¨DESEAS HACER OTRO MUESTREO CON OTROS VALORES"
		IF Errorlevel 2 SET tDetectNewScan=NO
		IF Errorlevel 1 SET tDetectNewScan=YES
	)
	
	if /i "!tDetectNewScan!" equ "YES" (
		set /p InputNewtDetectStar="[VIDEO] - INICIAR SCAN A LOS [!tDetectStar! SEGUDNOS]:"
		if /i "!InputNewtDetectStar!" neq "" (
			set tDetectStar=!InputNewtDetectStar!
			echo [VIDEO] - [MODIFICADO] INICIARA EL SCAN DESDE EL SEGUNDO: !tDetectStar!
		)
		set /p InputNewtDetectDura="[VIDEO] - DURACION DEL SCAN [!tDetectDura! SEGUNDOS]:"
		if /i "!InputNewtDetectDura!" neq "" (
			set tDetectDura=!InputNewtDetectDura!
			echo [VIDEO] - [MODIFICADO] - LA DURACION DEL SCAN ES AHORA DE: !tDetectDura! SEGUNDOS
		)
		echo.
		goto :DETECT_BORDER_INIT_SCAN
	)
	
	
	REM TODO: PENDIENTE DETECTAR QUE RESULTADO TIENE UN COUNT MAYOUR PARA USAR ESE COMO SELECCION POR DEFECTO.
	echo.
	set /p InputNewSize="[VIDEO] - CONFIRMA QUE LE NUEVO TAMA¥O ES [!tSizeReal_crop!]:"
	if /i "!InputNewSize!" neq "" (
		set tSizeReal_crop=!InputNewSize!
		echo [VIDEO] - [MODIFICADO] - EL NUEVO TAMA¥O SE HA DEFINIDO EN: !tSizeReal_crop!
	)
	
	for /f %%i in ('cscript /nologo VideoSizeReal_Size.vbs "!tSizeReal_crop!"') do (
		set tSizeReal_size=%%i
	)
	echo.
	
	REM ********************************************************
	REM ********************************************************
	
	
	
	
	
	
	REM **************************************************************
	REM *** DETECTAR SI EL TAMA¥O ORIGINAL Y EL NUEVO SON EL MISMO ***
	REM **************************************************************
	
	if "!tSizeReal_size!" == "!tSizeOrig_size!" (
		@CHOICE /C:YN /M "[VIDEO] - ¨NO SE HAN DETECTADO BORDES, DESEAS CANCELAR LA RECODIFICACION?"
		IF Errorlevel 2 GOTO NOBORDE_NO
		IF Errorlevel 1 GOTO NOBORDE_YES
		GOTO :eof

		:NOBORDE_YES
			echo [VIDEO] - [SKIP] EN ESTE ARCHIVO NO SE HAN DETECTADO BORDES, SE OMITE^!^!^!^!^!^!^!^!^!
			goto END_VIDEO_FIX

		:NOBORDE_NO
			set tSizeReal_crop=
			echo.
	) 
	
	if not "!tSizeReal_crop!"  == "" (
		echo [VIDEO] - [TEST] - PLAY VERSION ORIGNAL....
		set RunFunction=%tPathffplay% !tPathFileOrig!
		@call src\gen_func.cmd RUN_EXE
		set RunFunction=
		
		echo [VIDEO] - [TEST] - PLAY VERSION RECORTADA....
		set RunFunction=%tPathffplay% -vf crop=!tSizeReal_crop! !tPathFileOrig!
		if "%_debug%" == "YES" (
			@call src\gen_func.cmd RUN_EXE
		) else (
			@call src\gen_func.cmd RUN_EXE 3 !tfInfoTestPlay!
		)
		set RunFunction=
	)
	
	REM **************************************************************
	REM **************************************************************
	
	
	
	
	
	
	REM *********************************************************
	REM *** DEFINIMOS SI DESEAMOS CAMBIAR EL TAMA¥O DEL VIDEO ***
	REM *********************************************************
	
	:RESIZE_VIDEO_INIT
	
	if not "!tSizeReal_crop!" == "" (
		@call src\gen_func.cmd GetWidthByResolution : %tSizeReal_crop% tWidthOrig
	) else (
		@call src\gen_func.cmd GetWidthByResolution x %tSizeOrig_size% tWidthOrig
		set tSizeReal_size=%tSizeOrig_size%
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
	
	if "%ffmpeg_cv%" == "h264_nvenc" (
	
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
		
		set video_e=-c:v %ffmpeg_cv%
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
		
rem 	set video_e=-c:v %ffmpeg_cv% -preset llhq
rem		if not "!opt_v_profile!" == "" (set video_e=!video_e! -profile:v !opt_v_profile!)
rem		if not "!opt_v_level!" == ""   (set video_e=!video_e! -level:v !opt_v_level!)
		
		
		rem set video_e=-c:v %ffmpeg_cv% -preset llhq -profile:v !opt_v_profile! -level !opt_v_level! -rc-lookahead:v 32 -refs %ffmpeg_refs% -movflags +faststart -qmin !opt_v_qmin! -qmax !opt_v_qmax!
		rem set video_e=-c:v %ffmpeg_cv% -preset llhq -rc-lookahead:v 32 -refs %ffmpeg_refs% -movflags +faststart -qmin !opt_v_qmin! -qmax !opt_v_qmax!
		
	) else if "%ffmpeg_cv%" == "hevc_nvenc" (
	
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
		
		set video_e=-c:v %ffmpeg_cv%
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
		
rem		set video_e=-c:v %ffmpeg_cv% -preset llhq
		
		
		
		REM !!!!!!!!!!!!!! PENDIENTE AFINAR QMAX PARA QUE NO OCUPEN TANTO LOS VIDEOS!!!!!!!!!!!!! qmin 16 - qmax 23
		REM set opt_v_profile=main
		REM set opt_v_level=4.1
		REM set video_e=-c:v %ffmpeg_cv% -preset llhq -profile:v !opt_v_profile! -level !opt_v_level! -rc-lookahead:v 32 -refs %ffmpeg_refs% -movflags +faststart -qmin !opt_v_qmin! -qmax !opt_v_qmax!
		
	) else if "%ffmpeg_cv%" == "libx264" (
	
		REM **** CPU - H264
		REM ****** VERSION POR COMPRESION CONSTANT RATE FACTOR (CRF)
		REM ******
		REM ****** INFO -> ffmpeg -hide_banner -h encoder=libx264
		set OutputVideoFormat="avc"
		set opt_v_CRF=%default_crf%
		set video_e=-c:v %ffmpeg_cv% -pix_fmt yuv420p -crf !opt_v_CRF! -preset slow -refs %ffmpeg_refs% -r %ffmpeg_fps% -movflags +faststart
		
	) else if "%ffmpeg_cv%" == "libx265" (
	
		REM **** CPU - H265
		REM ****** VERSION POR COMPRESION CONSTANT RATE FACTOR (CRF)
		REM ******
		REM ****** INFO -> ffmpeg -hide_banner -h encoder=libx265
		set OutputVideoFormat="hevc"
rem		set opt_v_CRF=%default_crf%
		set opt_v_CRF=%all_qmin%

		set video_e=-c:v %ffmpeg_cv% -pix_fmt yuv420p
		
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
	echo [VIDEO] - [INFO] - IN:
	echo [VIDEO] - [INFO] -- TAMA¥O INICIAL: !tSizeReal_size!
	echo [VIDEO] - [INFO]
	echo [VIDEO] - [INFO] - OUT:
	echo [VIDEO] - [INFO] -- ENCODING: %ffmpeg_cv%
	echo [VIDEO] - [INFO] -- FORMATO SALIDA: %OutputVideoFormat% [%OutputVideoType%]
	if not "!tSizeReal_crop!" == "" (
		echo [VIDEO] - [INFO] -- RECORTAR A: !tSizeReal_crop!
	)
	if not "!OutNewSize!" ==  "" (
		echo [VIDEO] - [INFO] -- REDIMENSAION A: !OutNewSize!
	)
	if not "!opt_v_profile!" == "" (
		echo [VIDEO] - [INFO] -- ENCODING PROFILE: !opt_v_profile!
	)
	if not "!opt_v_level!" == "" (
		echo [VIDEO] - [INFO] -- ENCODING LEVEL: !opt_v_level!
	)
	if not "!opt_v_CRF!" == "" (
		echo [VIDEO] - [INFO] -- CFR FIJO A: !opt_v_CRF!
	) else (
		if not "!opt_v_q!" == "" (
			echo [VIDEO] - [INFO] -- CFR FIJO A: !opt_v_q!
		) else (
			if not "!opt_v_qmin!!opt_v_qmax!" == "" (
				echo [VIDEO] - [INFO] -- CFR DINAMICO:
				if not "!opt_v_qmin!" == "" (
					echo [VIDEO] - [INFO] ---- QMIN: !opt_v_qmin!
				)
				if not "!opt_v_qmax!" == "" (
					echo [VIDEO] - [INFO] ---- QMAX: !opt_v_qmax!
				)
			)
		)
	)
	
	echo.
	echo [VIDEO] - PROCESANDO....
	
	set RunFunction=!RunFunction! !metadata_v! !video_f! !video_e! !map_ord! -f %OutputVideoFormat% !tfProcesVideo!
	@call src\gen_func.cmd RUN_EXE
	set RunFunction=
	
	
	:END_VIDEO_FIX
	
	echo [VIDEO] - FINALIZADO
	ENDLOCAL
	GOTO :eof










REM ***************************************************
REM ****           AUDIO - AUDIO - AUDIO           ****
REM ***************************************************

:ProcessAudioFix

	if "%_debug_sa%" == "YES" (
		rem ******** DEBUG!!!!!!!!!!!!!!!!
		echo [AUDIO] - tPathFileOrig:   %tPathFileOrig%
		echo [AUDIO] - tPathFileConvrt: %tPathFileConvrt%
		echo [AUDIO] - tFileName:       %tFileName%
		echo [AUDIO] - tfInfoffmpeg:    %tfInfoffmpeg%
		echo [AUDIO] - tfProcesAudio:   %tfProcesAudio%
		echo.
		pause
		GOTO :eof
		rem ******** DEBUG!!!!!!!!!!!!!!!!
	)


	if "%tfStreamA_NULL%" == "YES" (
		echo [AUDIO] - [SKIP] - NO SE HAN DETECTADO NINGUNA PISTA DE AUDIO^!
		GOTO :eof
	)
	If exist !tPathFileConvrt! (
		echo [AUDIO] - [SKIP] - EL ARCHIVO YA SE HA PROCESADO^!
		GOTO :eof
	)
	if exist !tfProcesAudio! (
		@CHOICE /C:YN /d N /t 10 /M "[AUDIO] - LA PISTA DE AUDIO YA SE HA PROCESADO ¨QUIERES VOLVER A PROCESARLA [AUTO **NO** EN 10 SEG]"
		IF Errorlevel 2 GOTO AUDIO_CHOICE_PROCESAR_OTRA_VEZ_NO
		IF Errorlevel 1 GOTO AUDIO_CHOICE_PROCESAR_OTRA_VEZ_SI
		GOTO :eof
		
		:AUDIO_CHOICE_PROCESAR_OTRA_VEZ_NO
		echo [AUDIO] - [SKIP] - LA PISTA DE AUDIO YA SE HA PROCESADO^!
		GOTO :eof
		
		:AUDIO_CHOICE_PROCESAR_OTRA_VEZ_SI
		@call src\gen_func.cmd FUN_FILE_DELETE_FILE !tfProcesAudio!
	)
	
	
	SETLOCAL
	
	echo [AUDIO] - PROCESO INICIANDO...
	
	REM *** ELIMINA LAS COMILLAS AL COMIENZO Y AL FINAL DEL NOMBRE DEL ARCHIVO
	@call src\gen_func.cmd FUN_CLEAR_TRIM_COMILLAS tFileName
	
	
	@call src\gen_func.cmd FUN_FILE_DELETE_FILE !tfStreamA_A!
	@call src\gen_func.cmd FUN_FILE_DELETE_FILE !tfStreamA_I!
	@call src\gen_func.cmd FUN_FILE_DELETE_FILE !tfInfoFixVol!
	@call src\gen_func.cmd FUN_FILE_DELETE_FILE !tfInfoFixVolR!
	@call src\gen_func.cmd FUN_FILE_DELETE_FILE !tfInfoFixInitTime!
	@call src\gen_func.cmd FUN_FILE_DELETE_FILE !tfInfoFixInitTimeR!
	@call src\gen_func.cmd FUN_FILE_DELETE_FILE !tfProcesAudioConcat!
	@call src\gen_func.cmd FUN_FILE_DELETE_FILE !tfProcesAudioSilencio!
	
	
	set t_audio_id_pista=
	set t_audio_sync_v_a=
	set t_audio_fix_vol=
	set t_audio_ccanales=
	
	
	:INIT_AUDIO_GET_ID_PISTA
	
	set t_audio_id_pista=
	cscript /nologo AudioGetID.vbs !tfStreamA! !tfStreamA_A! !tfStreamA_I!
	set /p t_audio_id_pista=<!tfStreamA_I!
	if "!t_audio_id_pista!" == "" (
		echo [AUDIO] - [ID] - [ERR] - NO SE DETECTO LA PISTA DE AUDIO CORRECTA^!
		GOTO ProcessAudioFix_end
	)
	
	:SKIP_AUDIO_GET_ID_PISTA
	
	
	:INIT_AUDIO_SYNC_AUDIO_VIDEO
	
	set t_audio_sync_v_a=
	if "!t_audio_id_pista!" == "" (
		echo [AUDIO] - [SYNC] - [WARN^!^!] - NO SE DETECTO LA PISTA DE AUDIO CORRECTA^!^!
		GOTO ProcessAudioFix_end
	)
	
	echo|set /p="[AUDIO] - [SYNC] - [SCAN] - COMPROBANDO SI EL AUDIO Y EL VIDEO INICIAN A LA VEZ... "
	
	set RunFunction=%tPathffmpeg% -hide_banner -y -threads %ffmpeg_threads% -i !tPathFileOrig! -af "ashowinfo" -map 0:!t_Audio_Id_Pista! -y -f alaw -frames:a !t_Audio_Id_Pista! nul
 	@call src\gen_func.cmd RUN_EXE 2 !tfInfoFixInitTime!
 	set RunFunction=
	cscript /nologo AudioGetInitTime.vbs !tfInfoFixInitTime! !tfInfoFixInitTimeR!
	set /p t_audio_sync_v_a=<!tfInfoFixInitTimeR!
	
	if "!t_audio_sync_v_a!" == "" (
		echo|set /p=" [ERR^!^!] - NO SE HA LOCALIZADO pts_time^!^!^!^!"
		echo.
		goto ProcessAudioFix_end
	) else (
		if /i !t_audio_sync_v_a! neq 0 (
			echo|set /p="  [NO^!]"
		) else (
			echo|set /p="  [OK]"
		)
		echo.
	)
	
	if /i !t_audio_sync_v_a! neq 0 (
		@CHOICE /C:YN /d Y /t 10 /M "[AUDIO] - [SYNC] - [FIX] - ¨DESEAS USAR EL VALOR DETECTADO DE [!t_audio_sync_v_a! SEG] - [AUTO **SI** EN 10 SEG]"
		IF Errorlevel 2 GOTO AUDIO_CHOICE_SYNC_AUDIO_VIDEO_CUSTOM_NO
		IF Errorlevel 1 GOTO AUDIO_CHOICE_SYNC_AUDIO_VIDEO_CUSTOM_END
		GOTO :eof
		
		:AUDIO_CHOICE_SYNC_AUDIO_VIDEO_CUSTOM_NO
		set /p InputNew_t_audio_sync_v_a="[AUDIO] - [SYNC] - [FIX] - CUANTO SILENCIO HAY QUE A¥ADIR AL INCIO [!t_audio_sync_v_a! SEG]:"
		if /i "!InputNew_t_audio_sync_v_a!" neq "" (
			set t_audio_sync_v_a=!InputNew_t_audio_sync_v_a!
		)
		
		:AUDIO_CHOICE_SYNC_AUDIO_VIDEO_CUSTOM_END
		echo [AUDIO] - [SYNC] - [FIX] - SE A¥ADIRA AL INICIO UN SILENCIO DE: !t_audio_sync_v_a! SEG
	)
	
	if /i !t_audio_sync_v_a! neq 0 (
		
		REM *************** INI - CODIGO DE PRUEBAS - NO ES NECESARIO YA QUE EL SILENCIO SE GENERA DIRECTAMENTE AL EXTRAER LA PISTA DE AUDIO *********************
		
		echo|set /p="[AUDIO] - [SYNC] - [FIX] - GENERANDO SILENCIO..."
		
		set RunFunction=%tPathffmpeg% -hide_banner -y -threads %ffmpeg_threads% -y
		set RunFunction=!RunFunction! -filter_complex "aevalsrc=0:d=!t_audio_sync_v_a!:sample_rate=!all_a_hz!:channel_layout=stereo"
		set RunFunction=!RunFunction! !tfProcesAudioSilencio!
		@call src\gen_func.cmd RUN_EXE
		set RunFunction=
		
		echo|set /p="  [OK]"
		echo.
		
		REM *************** END - CODIGO DE PRUEBAS - NO ES NECESARIO YA QUE EL SILENCIO SE GENERA DIRECTAMENTE AL EXTRAER LA PISTA DE AUDIO *********************
		
		
		
		REM ***** AVISO!!!! ****** TENEMOS QUE GENERAR PRIMERO EL WAV YA QUE SI LO GENERAMOS DIRECTAMENTE EN AAC EN LA UNION DEL SILENCION CON LA PISTA DE AUDIO A¥ADE UNOS SEGUNDOS MAS DE TIEMPO Y SE DESINCRONIZA.
		
		echo|set /p="[AUDIO] - [SYNC] - [FIX] - A¥ADIENDO SILENCIO A LA PISTA DE AUDIO..."
		
		set RunFunction=%tPathffmpeg% -hide_banner -y -threads %ffmpeg_threads% -y
		set RunFunction=!RunFunction! -i !tPathFileOrig! -vn -sn -map_chapters -1
		set RunFunction=!RunFunction! -filter_complex "aevalsrc=0|:d=!t_audio_sync_v_a!:sample_rate=!all_a_hz!:channel_layout=stereo[silence];[silence][0:a]concat=n=2:v=0:a=!t_audio_id_pista![out]" -map [out]
		set RunFunction=!RunFunction! !tfProcesAudioConcat!
		@call src\gen_func.cmd RUN_EXE
		set RunFunction=
		
		If exist !tfProcesAudioConcat! (
			echo|set /p="  [OK]"
			echo.
		) else (
			echo|set /p="  [ERR^!^!]"
			echo.
			goto ProcessAudioFix_end
		)
	)
	
	:SKIP_AUDIO_SYNC_AUDIO_VIDEO
	
	
	
	
	:INIT_AUDIO_FIX
	
	set t_audio_ccanales=
	findstr.exe /i /c:"5.1" !tfStreamA_A! >nul
	if not errorlevel 1 (
		set t_audio_ccanales=5.1 A STEREO
	) else (
		set t_audio_ccanales=STEREO
	)
	
	IF "%default_a_process%" == "ACCGAIN" ( goto INIT_AUDIO_FIX_AACGAI )
	
	
REM **** INI - FIX FFMPEG ****
	
	:INIT_AUDIO_FIX_FFMPEG_VOLUMEN
	
	set t_audio_fix_vol=
	if "!t_audio_id_pista!" == "" (
		echo [AUDIO] - [VOLF] - [WARN^!^!] - NO SE DETECTO LA PISTA DE AUDIO^!^!
		GOTO END_AUDIO_FIX
	)
	
	echo [AUDIO] - [VOLF] - [SCAN] - ANALIZANDO VOLUMEN...
	
	set t_audio_fix_vol=
	set RunFunction=%tPathffmpeg% -hide_banner -y -threads %ffmpeg_threads%
	if exist !tfProcesAudioConcat! (
		set RunFunction=!RunFunction! -i !tfProcesAudioConcat!
		set RunFunction=!RunFunction! -map 0:a
	) else (
		set RunFunction=!RunFunction! -i !tPathFileOrig!
		set RunFunction=!RunFunction! -map 0:!t_audio_id_pista!
		set RunFunction=!RunFunction! -vn -sn -map_chapters -1
	)
	set RunFunction=!RunFunction! -af volumedetect -f null -
 	@call src\gen_func.cmd RUN_EXE 2 !tfInfoFixVol!
 	set RunFunction=
	
	cscript /nologo AudioGetMaxVol.vbs !tfInfoFixVol! !tfInfoFixVolR!
	set /p t_audio_fix_vol=<!tfInfoFixVolR!
	
	if "!t_audio_fix_vol!" == "" (
		echo [AUDIO] - [VOLF] - [ERR^!^!] - NO SE HA LOCALIZADO max_volume^!^!^!
		goto END_AUDIO_FIX
	) else (
		if /i !t_audio_fix_vol! gtr 0 (
 			echo [AUDIO] - [VOLF] - [FIX] - APLICANDO AJUSTE RECOMENDADO [!t_audio_fix_vol!]...
		) else (
			echo [AUDIO] - [VOLF] - [SKIP] - IGNORANDO AJUSTE RECOMENDADO [!t_audio_fix_vol!]^!
			set t_audio_fix_vol=0
			goto SKIP_AUDIO_FIX_FFMPEG_VOLUMEN
		)
	)
	
	:SKIP_AUDIO_FIX_FFMPEG_VOLUMEN
	
	
	
	:INIT_AUDIO_FIX_FFMPEG_RECODIFICAR
	
	if "!t_audio_id_pista!" == "" (
		echo [AUDIO] - [RECODIFICAR] - [WARN^!^!] - NO SE DETECTO LA PISTA DE AUDIO^!^!
		GOTO END_AUDIO_FIX
	)
	if "!all_a_bitrate!" == "" (
		echo [AUDIO] - [RECODIFICAR] - [SKIP] - NO SE HA DEFINIDO BITRATE^!^!
		goto SKIP_AUDIO_FIX_FFMPEG_RECODIFICAR
	)
	
	echo [AUDIO] - [RECODIFICAR] - RECODIFICANDO AUDIO !t_audio_ccanales! CON UN BITRATE [!all_a_bitrate!]...
	
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
			set RunFunction=!RunFunction! -filter_complex "[0:!t_audio_id_pista!]volume=!t_audio_fix_vol!dB:precision=fixed[out]" -map [out]
		) else (
			set RunFunction=!RunFunction! -map 0:!t_audio_id_pista!
		)
	)
	
	if not "!all_a_bitrate!" == "" (
		set RunFunction=!RunFunction! -b:a !all_a_bitrate!
	)
	
	REM set RunFunction=!RunFunction! -c:a aac -strict experimental
	
	set RunFunction=!RunFunction! -ar !all_a_hz!
	set RunFunction=!RunFunction! -ac 2
	set RunFunction=!RunFunction! -aac_coder twoloop
	
	set RunFunction=!RunFunction! !tfProcesAudio!
	@call src\gen_func.cmd RUN_EXE
	set RunFunction=
	
	:SKIP_AUDIO_FIX_FFMPEG_RECODIFICAR
	
	GOTO END_AUDIO_FIX
	
REM **** END - FIX FFMPEG ****




REM **** INI - AACGAIN ****
	
	:INIT_AUDIO_FIX_AACGAI
	
	set t_audio_fix_vol=
	if "!t_audio_id_pista!" == "" (
		echo [AUDIO] - [VOLF] - [WARN^!^!] - NO SE DETECTO LA PISTA DE AUDIO^!^!
		GOTO END_AUDIO_FIX
	)
	
	echo [AUDIO] - [VOLF] - RECODIFICANDO AUDIO [PISTA !t_audio_id_pista!] !t_audio_ccanales! CON UN BITRATE [!all_a_bitrate!]...
	
	set RunFunction=%tPathffmpeg% -hide_banner -y -threads %ffmpeg_threads% -y
	
	if exist !tfProcesAudioConcat! (
		set RunFunction=!RunFunction! -i !tfProcesAudioConcat!
		set RunFunction=!RunFunction! -map 0:a
	) else (
		set RunFunction=!RunFunction! -i !tPathFileOrig!
		set RunFunction=!RunFunction! -vn -sn -map_chapters -1
		set RunFunction=!RunFunction! -map 0:!t_audio_id_pista!
	)
	
	if not "!all_a_bitrate!" == "" (
		set RunFunction=!RunFunction! -b:a !all_a_bitrate!
	)
	
	rem set RunFunction=!RunFunction! -c:a aac
	set RunFunction=!RunFunction! -ar !all_a_hz!
	set RunFunction=!RunFunction! -ac 2
	set RunFunction=!RunFunction! -aac_coder twoloop
	
	set RunFunction=!RunFunction! !tfProcesAudio!
	@call src\gen_func.cmd RUN_EXE
	set RunFunction=
	
	echo [AUDIO] - [VOLF] - [SCAN] - ANALIZANDO VOLUMEN...
	
 	set RunFunction=%tPathaacgain% /q !tfProcesAudio!
	@call src\gen_func.cmd RUN_EXE 1 !tfInfoFixVol!
	set RunFunction=
	
	cscript /nologo AudioGetMaxVolAACGain.vbs !tfInfoFixVol! !tfInfoFixVolR!
	set /p t_audio_fix_vol=<!tfInfoFixVolR!
	
	if /i !t_audio_fix_vol! gtr 0 (
		echo [AUDIO] - [VOLF] - [FIX] - APLICANDO AJUSTE RECOMENDADO [!t_audio_fix_vol!]...
	) else (
		echo [AUDIO] - [VOLF] - [SKIP] - IGNORANDO AJUSTE RECOMENDADO [!t_audio_fix_vol!]
		goto SKIP_AUDIO_FIX_AACGAI
	)
	
	set RunFunction=%tPathaacgain% /r /c /q !tfProcesAudio!
	@call src\gen_func.cmd RUN_EXE
	set RunFunction=
	
	:SKIP_AUDIO_FIX_AACGAI

REM **** END - AACGAIN ****
	
	
	
	
	:END_AUDIO_FIX
	
	
	:ProcessAudioFix_end
	
	if not "%_debug%" == "YES" (
		@call src\gen_func.cmd FUN_FILE_DELETE_FILE !tfProcesAudioConcat!
		@call src\gen_func.cmd FUN_FILE_DELETE_FILE !tfProcesAudioSilencio!
	)
	
	echo [AUDIO] - FINALIZADO
	ENDLOCAL
	GOTO :eof



rem *** INFO FFMPEG *** > "-map_chapters -1" evita que se copien los capitulos del archivo original.
