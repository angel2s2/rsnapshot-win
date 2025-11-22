:: github https://github.com/angel2s2/rsnapshot-win

@echo off
chcp 1251 >nul
setlocal ENABLEDELAYEDEXPANSION

:: Источник
set "SRC=\\10.10.10.10\share"
:: Хранилище
set "DSTROOT=C:\bak"
:: Количества сохраняемых копий (обязательно >0)
set "MAX_COPIES=10"



:: Получение даты в формате ГГГГ-ММ-ДД_ЧЧ-ММ
for /f "tokens=1-3 delims=." %%a in ('date /t') do (
    set "DD=%%a"
    set "MM=%%b"
    set "YYYY=%%c"
)
for /f "tokens=1-2 delims=:" %%a in ('time /t') do (
    set "HOUR=%%a"
    set "MIN=%%b"
)
:: Удаляем пробелы из даты и времени
set "DD=!DD: =!"
set "MM=!MM: =!"
set "YYYY=!YYYY: =!"
set "HOUR=!HOUR: =0!"
set "MIN=!MIN: =0!"

:: Формируем путь хранения
set "BACKUP_DATE=!YYYY!-!MM!-!DD!_!HOUR!-!MIN!"
set "DST=!DSTROOT!\!BACKUP_DATE!"

:: Создать корневую папку, если не существует
if not exist "!DSTROOT!\" mkdir "!DSTROOT!"



:: 1. Находим предыдущую папку-версию
set "PREV="
for /f "delims=" %%L in ('dir /b /ad /o-d "!DSTROOT!" 2^>nul') do (
    set "PREV=!DSTROOT!\%%L"
    goto :create_hardlinks
)


:create_hardlinks
:: Создаем папку назначения
if not exist "!DST!\" mkdir "!DST!"

:: Проверка источника
if not exist "!SRC!\" (
    echo ERROR: Source not available >> "!DST!\log_!BACKUP_DATE!.log"
    exit /b 1
)

echo Backup start: !DST! > "!DST!\log_!BACKUP_DATE!.log"



:: 2. Если есть предыдущая версия — создаем жесткие ссылки на все файлы
if not "!PREV!"=="" (
    echo Creating hardlinks from previous backup: !PREV! >> "!DST!\log_!BACKUP_DATE!.log"
    set START_TIME=!time!
    
    :: Рекурсивно создаем жесткие ссылки на все файлы из предыдущего бэкапа
    for /f "delims=" %%F in ('dir "!PREV!" /s /b /a-d 2^>nul ^| findstr /v /i "\\log_"') do (
        :: Получаем относительный путь файла
        set "fullPath=%%~F"
        set "relPath=!fullPath:%PREV%=!"
		set "relPath=!relPath:~1!"
		
		:: Получаем путь к папке (без имени файла)
		set "targetDir=!DST!\!relPath!"
		set "targetDir=!targetDir:\%%~nxF=!"
		if not exist "!targetDir!\" mkdir "!targetDir!"
		
        :: Создаем жесткую ссылку в новой папке
        fsutil hardlink create "!DST!\!relPath!" "%%F" >nul 2>&1 || (
			echo WARNING: Failed to create hardlink for !relPath! >> "!DST!\log_!BACKUP_DATE!.log"
		)
    )
	set END_TIME=!time!
    echo Hardlinks created in !START_TIME! - !END_TIME! >> "!DST!\log_!BACKUP_DATE!.log"
) else (
    echo No previous backup found, creating first full copy... >> "!DST!\log_!BACKUP_DATE!.log"
)



:: 3. Копируем только изменённые файлы
echo Starting copy... >> "!DST!\log_!BACKUP_DATE!.log"
robocopy "!SRC!" "!DST!" /e /z /copy:DAT /XO /XF ~$* Thumbs.db /r:1 /w:1 /mt:8 /np /log+:"!DST!\log_!BACKUP_DATE!.log"

:: Проверка успешности копирования
set /a ROBORESULT=!ERRORLEVEL!
echo Robocopy exit code: !ROBORESULT! >> "!DST!\log_!BACKUP_DATE!.log"
:: Коды 0-7 - нормально, продолжаем
:: Коды 8+ - фатальная ошибка
if !ROBORESULT! EQU 0 (
    echo Perfect copy - no errors >> "!DST!\log_!BACKUP_DATE!.log"
) else if !ROBORESULT! LEQ 7 (
    echo Copy completed with warnings >> "!DST!\log_!BACKUP_DATE!.log"
) else (
    echo ERROR: Fatal robocopy error !ROBORESULT! >> "!DST!\log_!BACKUP_DATE!.log"
    echo Cleaning up failed backup... >> "!DST!\log_!BACKUP_DATE!.log"
    rmdir /s /q "!DST!" 2>nul
    exit /b !ROBORESULT!
)


:: 4. Очистка старых копий (оставляем последние !MAX_COPIES!)
set /a SKIP_COUNT=!MAX_COPIES!
for /f "skip=%SKIP_COUNT% delims=" %%I in ('dir "!DSTROOT!" /ad /b /od 2^>nul') do (
        echo Deleting old backup: %%I >> "!DST!\log_!BACKUP_DATE!.log"
        rmdir /s /q "!DSTROOT!\%%I" || echo Could not delete: %%I
)


echo Backup completed: !DST! >> "!DST!\log_!BACKUP_DATE!.log"
exit /b 0
