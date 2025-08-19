#!/bin/bash

PROTON_DIR="$HOME/.steam/steam/steamapps/common/Proton 9.0 (Beta)"
PROTON_RUN="$PROTON_DIR/proton"
WORK_DIR="$HOME/.steam/steam/steamapps/common/DayZ Tools/Bin/Workbench"
WORK_EXE="$WORK_DIR/workbenchApp.exe"

# ===== PREFIXO E VARIÁVEIS NECESSÁRIAS =====
STEAM_COMPAT_DATA_PATH="$HOME/.steam/steam/steamapps/compatdata"
STEAM_COMPAT_CLIENT_INSTALL_PATH="$HOME/.steam/steam"

export STEAM_COMPAT_DATA_PATH
export STEAM_COMPAT_CLIENT_INSTALL_PATH

# Executa o Workbench com Proton e mostra saída no terminal
"$PROTON_RUN" run "$WORK_EXE"

