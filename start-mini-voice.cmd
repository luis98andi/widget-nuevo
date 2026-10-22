@echo off
setlocal

set "HTA=%~dp0mini-voice.hta"
set "VOLUME_HELPER=%~dp0mini-voice-volume.ps1"
set "MSHTA=%SystemRoot%\System32\mshta.exe"

if not exist "%HTA%" (
  echo ERROR: No se encontro el archivo:
  echo "%HTA%"
  pause
  exit /b 1
)

if not exist "%VOLUME_HELPER%" (
  echo ERROR: No se encontro el auxiliar de volumen:
  echo "%VOLUME_HELPER%"
  echo Coloca mini-voice-volume.ps1 en la misma carpeta que mini-voice.hta.
  pause
  exit /b 1
)

if not exist "%MSHTA%" (
  echo ERROR: No se encontro mshta.exe en:
  echo "%MSHTA%"
  echo Windows no puede abrir archivos HTA en este equipo.
  pause
  exit /b 1
)

"%MSHTA%" "%HTA%"
set "EXIT_CODE=%ERRORLEVEL%"

if not "%EXIT_CODE%"=="0" (
  echo.
  echo ERROR: mshta.exe termino con el codigo %EXIT_CODE%.
  pause
)

exit /b %EXIT_CODE%
