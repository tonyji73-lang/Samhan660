@echo off
setlocal
cd /d "%~dp0"
if not exist "project.godot" goto project_error
if not exist "military_preparation.gd" goto project_error
set "GODOT_EXE=%USERPROFILE%\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe"
if exist "PLAYTEST_GODOT_PATH.txt" set /p GODOT_EXE=<"PLAYTEST_GODOT_PATH.txt"
if not exist "%GODOT_EXE%" goto godot_error
set "APPDATA=%~dp0.godot\player-playtest-profile"
if not exist "%APPDATA%" mkdir "%APPDATA%"
if not exist "%APPDATA%" goto profile_error
set "AUDIT_SCRIPT="
if "%~1"=="--inspect" set "AUDIT_SCRIPT=--script res://tests/player_playtest_inspect.gd"
if "%~1"=="--audit" set "AUDIT_SCRIPT=--script res://tests/player_playtest_ui.gd"
if "%~1"=="--restore" set "AUDIT_SCRIPT=--script res://tests/player_playtest_restore.gd"
echo Project: %CD%
echo Review profile: %APPDATA%\Godot\app_userdata\Samhan660
"%GODOT_EXE%" --path "%CD%" %AUDIT_SCRIPT% --log-file "%APPDATA%\launch-%RANDOM%.log"
if errorlevel 1 goto launch_error
exit /b 0
:project_error
echo ERROR: Keep this launcher in the project-foundation-v1 worktree beside project.godot.
pause
exit /b 1
:godot_error
echo ERROR: Godot was not found: "%GODOT_EXE%"
echo Put the absolute Godot executable path in PLAYTEST_GODOT_PATH.txt next to this launcher.
pause
exit /b 1
:profile_error
echo ERROR: Cannot create the review profile: "%APPDATA%"
pause
exit /b 1
:launch_error
echo ERROR: Godot failed. Check launch logs in "%APPDATA%".
pause
exit /b 1
