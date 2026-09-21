@echo off
setlocal
cd /d "%~dp0"

if not "%~1"=="" goto dogrudan
goto menu

:dogrudan
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0kur.ps1" %*
if errorlevel 1 (
    echo.
    echo   Islem hata veya guvenlik engeli nedeniyle tamamlanmadi.
)
echo.
pause
goto son

:menu
echo.
echo   ============================================================
echo     amcaoglu_anticheat - korumali transport kurulumu
echo   ============================================================
echo.
echo     [1]  Rapor     - ne yapilacagini gosterir, dosya degismez
echo     [2]  Uygula    - kurulumu yapar
echo     [3]  Geri al   - kurulumu tamamen geri alir
echo     [4]  Cikis
echo.
choice /c 1234 /n /m "  Seciminiz [1-4]: "
if errorlevel 255 goto son
if errorlevel 4 goto son
if errorlevel 3 goto gerial
if errorlevel 2 goto uygula
if errorlevel 1 goto rapor
goto son

:rapor
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0kur.ps1"
goto bitti

:uygula
echo.
echo   DIKKAT: Bu islem resource'larin meta.xml dosyalarini degistirir ve
echo   crown bundle'larindaki hile koruma katmanini kaldirir.
echo   Tamami geri alinabilir: menuden [3] Geri al.
echo.
choice /c EH /n /m "  Devam edilsin mi? (E/H): "
if not errorlevel 1 goto menu
if errorlevel 2 goto menu
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0kur.ps1" -Uygula
if errorlevel 1 (
    echo.
    echo   Kurulum uygulanmadi. Yukaridaki uyariyi duzeltip tekrar deneyin.
    goto bitti
)
echo.
echo   Kurulum bitti. Sunucuyu TAMAMEN kapatip acin.
echo   refresh + restart yeterli degildir, meta.xml degisti.
goto bitti

:gerial
echo.
choice /c EH /n /m "  Kurulum tamamen geri alinacak. Devam? (E/H): "
if not errorlevel 1 goto menu
if errorlevel 2 goto menu
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0kur.ps1" -GeriAl -Uygula
echo.
echo   Geri alma bitti. Sunucuyu TAMAMEN kapatip acin.
goto bitti

:bitti
echo.
pause
goto menu

:son
endlocal
exit /b
