@echo off
setlocal enabledelayedexpansion

:: ===== CONFIGURAÇÃO =====
set "BASE_DIR=%~dp0"
set "BOT_FILE=%BASE_DIR%bot.py"

:: Executa o script Python usando o caminho completo da variável
python "%BOT_FILE%"
pause
