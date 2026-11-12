@echo off
title Instalar App Up! TSI no Celular
cd /d "%~dp0"
powershell -ExecutionPolicy Bypass -File "%~dp0install_to_phone.ps1"
pause
