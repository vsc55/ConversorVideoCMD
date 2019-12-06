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


:INIT_SELECT_ENCODER


:INIT_SELECT_ENCODER_VIDEO
@call src\select_encoder_video.cmd SELECT_ENCODER all_v_encoder


:INIT_SELECT_ENCODER_VIDEO_OPTIONS

if "!all_v_encoder!" == "copy" ( GOTO SKIP_SELECT_ENCODER_VIDEO_OPTIONS )

@call src\select_encoder_video.cmd DETECTAR_BORDES all_detect_borde
@call src\select_encoder_video.cmd CAMBIAR_SIZE all_change_size

if "!all_v_encoder!" == "libx264" 	 ( goto INIT_SELECT_ENCODER_VIDEO_OPTIONS_H264 )
if "!all_v_encoder!" == "h264_nvenc" ( goto INIT_SELECT_ENCODER_VIDEO_OPTIONS_H264 )
if "!all_v_encoder!" == "libx265" 	 ( goto INIT_SELECT_ENCODER_VIDEO_OPTIONS_H265 )
if "!all_v_encoder!" == "hevc_nvenc" ( goto INIT_SELECT_ENCODER_VIDEO_OPTIONS_H265 )
GOTO SKIP_SELECT_ENCODER_VIDEO_OPTIONS




REM **** H264 CONFIG - INIT ****

:INIT_SELECT_ENCODER_VIDEO_OPTIONS_H264
if "!all_v_encoder!" == "libx264" 	 ( goto INIT_SELECT_ENCODER_VIDEO_OPTIONS_H264_PROFILE_LEVEL )
if "!all_v_encoder!" == "h264_nvenc" ( goto INIT_SELECT_ENCODER_VIDEO_OPTIONS_H264_PROFILE_LEVEL )
goto SKIP_SELECT_ENCODER_VIDEO_OPTIONS_H264


:INIT_SELECT_ENCODER_VIDEO_OPTIONS_H264_PROFILE_LEVEL
@call src\select_encoder_video_opt_h264.cmd SELECT_PROFILE all_v_profile
echo.
if not "!all_v_profile!" == "" (
	@call src\select_encoder_video_opt_h264.cmd SELECT_LEVEL 0 all_v_level
	echo.
)
:SKIP_SELECT_ENCODER_VIDEO_OPTIONS_H264_PROFILE_LEVEL


:INIT_SELECT_ENCODER_VIDEO_OPTIONS_H264_QMIN_QMAX
@call src\select_encoder_video_opt_h264.cmd SELECT_QMIN_QMAX %default_qmin% %default_qmax% all_qmin all_qmax
echo.
:SKIP_SELECT_ENCODER_VIDEO_OPTIONS_H264_QMIN_QMAX


:SKIP_SELECT_ENCODER_VIDEO_OPTIONS_H264
GOTO SKIP_SELECT_ENCODER_VIDEO_OPTIONS

REM **** H264 CONFIG - END ****




REM **** H265 CONFIG - INIT ****

:INIT_SELECT_ENCODER_VIDEO_OPTIONS_H265
if "!all_v_encoder!" == "libx265" 	 ( goto INIT_SELECT_ENCODER_VIDEO_OPTIONS_H265_PROFILE_LEVEL )
if "!all_v_encoder!" == "hevc_nvenc" ( goto INIT_SELECT_ENCODER_VIDEO_OPTIONS_H265_PROFILE_LEVEL )
goto SKIP_SELECT_ENCODER_VIDEO_OPTIONS_H265


:INIT_SELECT_ENCODER_VIDEO_OPTIONS_H265_PROFILE_LEVEL
@call src\select_encoder_video_opt_h265.cmd SELECT_PROFILE all_v_profile
echo.
if not "!all_v_profile!" == "" (
	@call src\select_encoder_video_opt_h265.cmd SELECT_LEVEL 0 all_v_level
	echo.
)
:SKIP_SELECT_ENCODER_VIDEO_OPTIONS_H265_PROFILE_LEVEL


:INIT_SELECT_ENCODER_VIDEO_OPTIONS_H265_QMIN_QMAX
@call src\select_encoder_video_opt_h265.cmd SELECT_QMIN_QMAX %default_qmin% %default_qmax% all_qmin all_qmax
echo.
:SKIP_SELECT_ENCODER_VIDEO_OPTIONS_H265_QMIN_QMAX


:SKIP_SELECT_ENCODER_VIDEO_OPTIONS_H265
GOTO SKIP_SELECT_ENCODER_VIDEO_OPTIONS

REM **** H265 CONFIG - END ****

:SKIP_SELECT_ENCODER_VIDEO_OPTIONS

:END_SELECT_ENCODER_VIDEO_OPTIONS




:INIT_SELECT_ENCODER_AUDIO
@call src\select_encoder_audio.cmd SELECT_BITRATE %default_a_br% all_a_bitrate all_a_encoder
echo.
:SKIP_SELECT_ENCODER_AUDIO


:SKIP_SELECT_ENCODER
