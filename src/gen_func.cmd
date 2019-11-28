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



:GetWidthByResolution
	:: @call src\gen_func.cmd GetWidthByResolution : %tSizeReal_crop% tWidthOrig
	REM
	REM %~1 es el separador entre ancho y alto
	REM %~2 es la variable que tiene el valor del que deseamos obtener la anchura.
	REM %~3 es la variable donde se va a guardar la anchura obtenida.
	
	for /f "delims=%~1" %%A in ("%~2") do (
		set "%~3=%%~A"
	)
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
	set RunFunction=
	goto:eof


:FUN_CLEAR_TRIM_COMILLAS
	:: @call src\gen_func.cmd FUN_CLEAR_TRIM_COMILLAS var_a_limpiar
	REM *** ELIMINA LAS COMILLAS AL COMIENZO Y AL FINAL UNA O VARIAS. EJ: """PRUEBA""" > PRUEBA
	
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
	REM *** ELIMINA LAS COMILLAS AL COMIENZO Y AL FINAL.
	REM *** NOTA!!! SI TIENE MULTIPLES COMILLAS EN ALGUNO DE LOS LADOS SOLO ELIMINARA UNA. EJ """PRUEBA""" > ""PRUEBA""
	
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



:END
exit /b 0