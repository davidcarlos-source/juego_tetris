@echo off
C:\masm32\bin\ml.exe /c /coff tetris.asm
if %errorlevel% neq 0 exit /b %errorlevel%
C:\masm32\bin\link.exe /subsystem:console tetris.obj
if %errorlevel% neq 0 exit /b %errorlevel%