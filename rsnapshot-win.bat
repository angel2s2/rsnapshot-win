:: github https://github.com/angel2s2/rsnapshot-win

@echo off

REM
REM Check for commandline args
REM
if "[%~1]" == "[]" goto error
if "[%~2]" == "[]" goto error

set "LN=D:\tmp\rsnapshot-win-test\ln.exe"

if not exist "%~1" goto error
if not exist "%~2" goto error

setLocal EnableDelayedExpansion

REM
REM Get date and time for timestamps on directories
REM
for /f "delims=" %%a in ('%LN% --datetime') do set DATETIMESTAMP=%%a

set SourceDir=%~n1%~x1
set DestDir=%~2

REM Take care of root source folder, e.g. c:\
if "%SourceDir%"=="" (
  set SourceDir=%~d1
  set SourceDir=!SourceDir:~0,1!
  set SourcePath=%~d1\\
  REM set BACKUPOPTIONS=--excludedir "System Volume Information" --exclude "~$*" --exclude "Thumbs.db" --exclude "log_*.log"
) else (
  set SourcePath=%~1
)

REM
REM Do the Delorean Copy
REM
pushd %DestDir%
set errlev=0
set "BACKUPCREATED=%DestDir%\%DATETIMESTAMP%"
set "BACKUPLOG=%BACKUPCREATED%\log_%DATETIMESTAMP%.log"
set BACKUPOPTIONS=--quiet 3 --excludedir "System Volume Information" --exclude "~$*" --exclude "Thumbs.db" --exclude "log_*.log"


if exist "????-??-?? ??-??-??" (
  for /f "delims=" %%a in ('dir /b /AD /O:N "????-??-?? ??-??-??"') do set LastBackup=%%a
  popd
  mkdir "%BACKUPCREATED%"
  type nul > "%BACKUPLOG%"
  REM echo delorean >> "%BACKUPLOG%" 2>&1
  REM echo "%SourcePath%" >> "%BACKUPLOG%" 2>&1
  REM echo "%DestDir%\!LastBackup!" >> "%BACKUPLOG%" 2>&1
  REM echo "%BACKUPCREATED%" >> "%BACKUPLOG%" 2>&1
  %LN% %BACKUPOPTIONS% --delorean "%SourcePath%" "%DestDir%\!LastBackup!" "%BACKUPCREATED%" >> "%BACKUPLOG%" 2>&1
  set errlev=!errorlevel!
) else (
  popd
  mkdir "%BACKUPCREATED%"
  type nul > "%BACKUPLOG%"
  REM echo copy >> "%BACKUPLOG%" 2>&1
  REM echo "%SourcePath%" >> "%BACKUPLOG%" 2>&1
  REM echo "%DestDir%\%DATETIMESTAMP%" >> "%BACKUPLOG%" 2>&1
  %LN% %BACKUPOPTIONS% --copy "%SourcePath%" "%DestDir%\%DATETIMESTAMP%" >> "%BACKUPLOG%" 2>&1
  set errlev=!errorlevel!
)
if %errlev% NEQ 0 goto errorexit

REM
REM Remove old backup sets (if KeepMaxCopies has been provided)
REM
if not "%3"=="" (set /a KeepMax=%~3) else (set KeepMax=0)
pushd %DestDir%
if %KeepMax% GTR 0 (
  echo ................................................... >> "%BACKUPLOG%" 2>&1
  for /f "skip=%KeepMax% tokens=* delims=" %%G in ('dir /b /A:D /O:-N "????-??-?? ??-??-??"') do (
    echo Removing backup set "%%G"... >> "%BACKUPLOG%" 2>&1
    %LN% --quiet 0 --delete "%%G" 2>>"%BACKUPLOG%" 1>nul && echo ...done >> "%BACKUPLOG%" 2>&1 || echo ...FAIL >> "%BACKUPLOG%" 2>&1
  )
)
popd

goto :EOF

REM
REM Usage
REM
:error
echo Usage: %~n0 ^<SourcePath^> ^<DestPath^> (^<KeepMaxCopies^>)
echo.
echo  SourcePath    directory containing the files to be backed up
echo  DestPath      directory where "DeLorean copy" sets will be created
echo  KeepMaxCopies (opt.) remove any exceeding number of DLC sets before copying
echo.
echo e.g. %~n0 c:\data\source c:\data\backup 90
goto :EOF

:errorexit
echo ................................................... >> "%BACKUPLOG%" 2>&1
echo Error: %errlev% >> "%BACKUPLOG%" 2>&1
exit /b %errlev%
