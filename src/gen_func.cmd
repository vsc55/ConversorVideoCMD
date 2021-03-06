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
set "CallArgsFix=%*"
call :!CallArgsFix!
(set CallArgsFix=)
exit /b 0


:GetWidthByResolution
	:: @call src\gen_func.cmd GetWidthByResolution : %tSizeReal_crop% tWidthOrig
	::
	:: %~1 es el separador entre ancho y alto
	:: %~2 es la variable que tiene el valor del que deseamos obtener la anchura.
	:: %~3 es la variable donde se va a guardar la anchura obtenida.
	
	setlocal
		set t_delims=%~1
		set t_value=%~2
		for /f "delims=%t_delims%" %%A in ("%t_value%") do (
			set t_return=%%~A
		)
	endlocal&(
		set _t_return=%t_return%
	)
	SET "%~3=!_t_return!"
	goto:eof


:RUN_EXE
	:: @call src\gen_func.cmd RUN_EXE [type_std(0|1|2|3)] [path_file_out]
	REM **
	REM **** TYPES_STD
	REM **** 0 = NULL
	REM **** 1 = STDOUT = Text output
	REM **** 2 = STDERR = Error text output
	REM **** 3 = STDOUT + STDERR (DEFAULT)
	REM https://support.microsoft.com/es-es/help/110930/redirecting-error-messages-from-command-prompt-stderr-stdout
	
	set t_out_type=%~1
	set t_path_out=%2
	
	if not "!t_path_out!" == "" (
		CALL:FUN_CLEAR_TRIM_COMILLAS t_path_out
	)
	if "!t_path_out!" == "" (
		set t_path_out=nul
		set t_out_type=0
	) else (
		set t_path_out="!t_path_out!"
		if "!t_out_type!" == "" (
			set t_out_type=3
		) else (
			if !t_out_type! LSS 0 (
				set t_out_type=3
			) else (
				if !t_out_type! GTR 3 (
					set t_out_type=3
				)
			)
		)
	)
	
	if not "!RunFunction!" == "" (
		if "%_debug%" == "YES" (
			echo.
			echo ************** DEBUG - INI **************
			echo.
			echo RUN ^=^> !RunFunction!
			if not "!t_path_out!" == "" (echo OUT ^=^> !t_path_out!)
			if not "!t_out_type!" == "" (echo TYPEOUT ^=^> !t_out_type!)
			pause
			echo.
			
			if "!t_out_type!" == "1" (
				!RunFunction! > !t_path_out!
			) else (
				if "!t_out_type!" == "2" (
					!RunFunction! 2> !t_path_out!
				) else (
					if "!t_out_type!" == "3" (
						!RunFunction! > !t_path_out! 2>&1
					) else (
						!RunFunction!
					)
				)
			)
			echo.
			echo ************** DEBUG - END **************
			echo.
			pause	
		) else (
			if "!t_out_type!" == "1" (
				start "" /wait /min cmd /c ^(!RunFunction! ^> !t_path_out!^)
			) else (
				if "!t_out_type!" == "2" (
					start "" /wait /min cmd /c ^(!RunFunction! 2^> !t_path_out!^)
				) else (
					if "!t_out_type!" == "3" (
						start "" /wait /min cmd /c ^(!RunFunction! ^> !t_path_out! 2^>^&1^)
					) else (
						start "" /wait /min !RunFunction!
					)
				)
			)
		)
	)
	(set RunFunction=)
	goto:eof


:FUN_CLEAR_TRIM_COMILLAS
	:: @call src\gen_func.cmd FUN_CLEAR_TRIM_COMILLAS var_a_limpiar
	:: *** ELIMINA LAS COMILLAS AL COMIENZO Y AL FINAL UNA O VARIAS. EJ: """PRUEBA""" > PRUEBA
	
	if "%~1" == "" (goto:eof)
	for /f "delims=" %%A in ('echo %%%1%%') do set t_text=%%~A

	:FUN_CLEAR_TRIM_COMILLAS_VOLVER_A_LIMPIAR
	set t_text_muestra=!t_text!
	CALL:FUN_CLEAR_TRIM_COMILLAS_PROCESS t_text
	if not !t_text_muestra! == !t_text! (goto FUN_CLEAR_TRIM_COMILLAS_VOLVER_A_LIMPIAR)
 	set %1=!t_text!
	goto:eof


:FUN_CLEAR_TRIM_COMILLAS_PROCESS
	:: @call src\gen_func.cmd FUN_CLEAR_TRIM_COMILLAS_PROCESS var_a_limpiar
	:: *** ELIMINA LAS COMILLAS AL COMIENZO Y AL FINAL.
	:: *** NOTA!!! SI TIENE MULTIPLES COMILLAS EN ALGUNO DE LOS LADOS SOLO ELIMINARA UNA. EJ """PRUEBA""" > ""PRUEBA""
	
	for /f "delims=" %%A in ('echo %%%1%%') do set %1=%%~A
	goto:eof


:FUN_FILE_DELETE_FILE
	:: @call src\gen_func.cmd FUN_FILE_DELETE_FILE path_file_a_borrar

	setlocal
		if "%~1" == "" (
			if "%_debug%" == "YES" (
				echo [DEBUG] - [FUN_FILE_DELETE_FILE] - NO SE HA PASADO NINGUN PATH DE ARCHIVO^!^!
			)
			goto:eof
		)

		set t_file=%1
		
		CALL:FUN_CLEAR_TRIM_COMILLAS t_file
		set t_file="!t_file!"
		
		If exist !t_file! (
			if "%_debug%" == "YES" (
				echo|set /p="[DEBUG] - [FUN_FILE_DELETE_FILE] - ARCHIVO [!t_file!] BORRADO..."
			)
			del /f /q !t_file! 2> nul
			IF not "%ERRORLEVEL%" == "0" (
				if "%_debug%" == "YES" (
					echo|set /p="  [ERR %ERRORLEVEL% ^!^!]"
					echo.
				)
			) else (
				REM *** BUG WINDOWS *** AUNQUE RETORNE ERROR 0, HAY QUE COMPROBAR SI EXISTE EL ARCHIVO YA QUE EL ERROR DE ACCESO DENEGADO RETORNA TAMBIEN ERRORLEVE 0
				REM                     ESTO NO PASA EN TODAS LA VERSIONES DE WINDOWS, PERO POR SI LAS MOSCAS AQUI ESTA ESTO.
				if "%_debug%" == "YES" (
					If exist !t_file! (
						echo|set /p="  [ERR 0, PERO SIGUE EXISTIENDO ARCHIVO^!^!]"
					) else (
						echo|set /p="  [OK]"
					)
					echo.
				)
			)
		) else (
			if "%_debug%" == "YES" (
				echo [DEBUG] - [FUN_FILE_DELETE_FILE] - ARCHIVO [!t_file!] NO EXISTE [SKIP]^!^!
			)
		)
		
	endlocal
	goto:eof


:CHECK_EXIST_AND_DOWNLOAD
	:: @call src\gen_func.cmd CHECK_EXIST_AND_DOWNLOAD "path_file" "url" is_exist
	:: https://stackoverflow.com/questions/4619088/windows-batch-file-file-download-from-a-url
	:: https://superuser.com/questions/25538/how-to-download-files-from-command-line-in-windows-like-wget-or-curl
	:: https://idiallo.com/blog/download-file-in-windows-command-line

	setlocal
		set t_file=%~1
		set t_url=%2

		set t_return=NO
		If exist !t_file! (
			set t_return=YES
		) else (
			::TODO Pendiente comprobar si url no esta vacia.
			if "!t_url!" neq "" (
				echo Descargando:
				echo - !t_url!
				curl -f -# !t_url! -o !t_file!
				If exist !t_file! (
					set t_return=DOWNLOAD_YES
				)
			)
		)
	endlocal&(
		SET "%~3=%t_return%"
	)
	goto:eof


:CHECK_FILE_AND_FIX
	:: @call src\gen_func.cmd CHECK_FILE_AND_FIX "path_file" "url" "MSG ERROR FIX" is_exist

	setlocal
		set t_file=%~1
		set t_url=%2
		set t_msg=%~3
		set t_return=

		CALL:CHECK_EXIST_AND_DOWNLOAD !t_file! !t_url! _checkExist
		if "!_checkExist!" == "NO" (
			if "!t_msg!" neq "" (
				echo.
				echo !t_msg!
			)
			::SET "%~4=ERROR_FIX"
			set t_return=ERROR_FIX
		)
		::(set _checkExist=)
	endlocal&(
		SET _t_return=%t_return%
	)
	if DEFINED _t_return ( SET "%~4=!_t_return!" )
	goto:eof


:CHECK_DIR_AND_CREATE
	:: @call src\gen_func.cmd CHECK_DIR_AND_CREATE "path a comprobar" is_exist["NO" si no existe y no se ha podido crear|Nada si existe]

	setlocal
		::set t_return=OK
		set t_dir=%~1
		If not exist "!t_dir!" (
			if "%_debug%" == "YES" (
				echo|set /p="[DEBUG] - [CHECK_DIR_AND_CREATE] - CREANDO [!t_dir!] ..."
			)
			mkdir "!t_dir!"
			IF not "%ERRORLEVEL%" == "0" (
				set t_return=NO
				if "%_debug%" == "YES" (
					echo|set /p="  [ERR %ERRORLEVEL% ^!^!]"
					echo.
				)
			) else (
				If not exist "!t_dir!" ( 
					set t_return=NO 
				)
				if "%_debug%" == "YES" (
					If exist "!t_dir!" (
						echo|set /p="  [OK]"	
					) else (
						echo|set /p="  [ERR 0, PERO NO SE HA CREADO EL DIRECTORIO^!^!]"
					)
					echo.
				)
			)
		) else (
			if "%_debug%" == "YES" (
				echo [DEBUG] - [CHECK_DIR_AND_CREATE] - DIR [!t_dir!] SI EXISTE [SKIP]^!^!
			)
		)
	endlocal&(
		SET _t_return=%t_return%
	)
	if DEFINED _t_return ( SET "%~2=!_t_return!" )
	goto:eof



:RUN_SUB_EXE
	:: RunExternal=echo Hola Mundo
	:: @call src\gen_func.cmd RUN_SUB_EXE [type_std(0|1|2|3)] [path_file_out] _var_return [type_win(MIN|MAX)]
	REM **
	REM **** TYPES_STD
	REM ****** 0 = NULL
	REM ****** 1 = STDOUT = Text output
	REM ****** 2 = STDERR = Error text output
	REM ****** 3 = STDOUT + STDERR (DEFAULT)
	REM https://support.microsoft.com/es-es/help/110930/redirecting-error-messages-from-command-prompt-stderr-stdout

	SETLOCAL
		set t_type_out=%~1
		set t_path_out=%~2
		set t_type_win=%~4
		set t_cmd=!RunExternal!

		if "!t_type_win!" == "AUTO" (
			(set t_type_win=)
		) else if "!t_type_win!" == "MAX" (
			set t_type_win=/MAX
		else if "!t_type_win!" == "MIN" (
			set t_type_win=/MIN
		) else (
			set t_type_win=/MIN
		)

		if not defined t_path_out (
			set t_type_out=0
			set t_path_out=nul
		) else (
			if not defined t_type_out (
				set t_type_out=3
			) else (
				if !t_type_out! LSS 0 (
					set t_type_out=3
				) 
				if !t_type_out! GTR 3 (
					set t_type_out=3
				)
			)
		)

		if defined t_cmd (
			if not "!t_cmd!" == "" (
				if "%_debug%" == "YES" (
					echo.
					echo [DEBUG] ************** DEBUG - INI **************
					echo [DEBUG]
					echo [DEBUG] - RUN      ^=^> !t_cmd!
					if not "!t_path_out!" == "" (echo [DEBUG] - OUT      ^=^> !t_path_out!)
					if not "!t_type_out!" == "" (echo [DEBUG] - TYPEOUT  ^=^> !t_type_out!)
					if not "!t_type_win!" == "" (echo [DEBUG] - TYPEWIN  ^=^> !t_type_win!)
					echo [DEBUG]
					echo [DEBUG]   ...PRESION UNA TECLA PARA EJECUTAR...
					echo [DEBUG] EJECUTANDO...
					echo [DEBUG]
					pause > NUL
					if "!t_type_out!" == "1" (
						%t_cmd% > "!t_path_out!"
					) else if "!t_type_out!" == "2" (
						%t_cmd% 2> "!t_path_out!"
					) else if "!t_type_out!" == "3" (
						%t_cmd%  > "!t_path_out!" 2>&1
					) else (
						%t_cmd%
					)
					echo [DEBUG]
					echo [DEBUG] ************** DEBUG - END **************
					echo.
					pause
				) else (
					if "!t_type_out!" == "1" (
						start "" /wait !t_type_win! cmd /c ^(!t_cmd! ^> "!t_path_out!"^)
					) else if "!t_type_out!" == "2" (
						start "" /wait !t_type_win! cmd /c ^(!t_cmd! 2^> "!t_path_out!"^)
					) else if "!t_type_out!" == "3" (
						start "" /wait !t_type_win! cmd /c ^(!t_cmd! ^> "!t_path_out!" 2^>^&1^)
					) else (
						start "" /wait !t_type_win! !t_cmd!
					)
				)

				if defined t_path_out (
					if not "!t_path_out!" == "nul" (
						if exist "!t_path_out!" (
							set /p t_return=<"!t_path_out!"
						)
					)
				)
			)
		)
	ENDLOCAL & (
		if not "%~3" == "" ( set "%~3=%t_return%" )
	)
	(set RunExternal=)
	goto:eof




:FILE_SIZE
	:: @call src\gen_func.cmd FILE_SIZE _return_size "C:\file.log"
	SETLOCAL
		set size=%~z2
		if not defined size (
			set size=0
		)

	ENDLOCAL & (
		set "%~1=%size%"
	)
	goto :eof

