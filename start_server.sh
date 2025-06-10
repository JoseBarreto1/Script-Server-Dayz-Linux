#!/bin/bash

# ===== CONFIGURAÇÕES =====
PROTON_DIR="$HOME/.steam/steam/steamapps/common/Proton 9.0 (Beta)"
PROTON_RUN="$PROTON_DIR/proton"
SERVER_DIR="$HOME/.steam/steam/steamapps/common/DayZServer"
SERVER_EXE="DayZServer_x64.exe"
SCRIPT_DIR="$SERVER_DIR/script_server_linux"
MOD_ID_FILE="mod_ids.txt"

SERVER_MODS='-serverMod=servermod'
SERVER_PORT='-port=2302'
SERVER_CPU='-cpuCount=2'
SERVER_OTHERS='-dologs -adminlog -netlog -freezecheck'

CONFIG="-config=serverDZ.cfg"
PROFILES="-profiles=profiles"

# ===== PREPARA A LISTA DE MODS =====
MODS_SUBDIR="mods/"

if [ ! -f "$SCRIPT_DIR/$MOD_ID_FILE" ]; then
    echo "❌ Arquivo mod_ids.txt não encontrado!"
    exit 1
fi

MODS_ID=$(<"$SCRIPT_DIR/$MOD_ID_FILE")
MODS_ID="${MODS_ID//\"/}"  # Remove aspas
MODS_ID="${MODS_ID// /}"   # Remove espaços

MODS_PARAM_TEMP=""
IFS=';' read -ra IDS <<< "$MODS_ID"
for id in "${IDS[@]}"; do
    MODS_PARAM_TEMP+="${MODS_SUBDIR}${id};"
done

if [[ -z "$MODS_PARAM_TEMP" ]]; then
    echo "⚠️ Nenhum mod foi carregado, verifique o arquivo mod_ids.txt"
    exit 1
fi

# ===== Remove o último ponto e vírgula =====
MODS_PARAM_TEMP="${MODS_PARAM_TEMP::-1}"

MODS="-mod=${MODS_PARAM_TEMP}"
echo "✅ Todos os mods foram formatados."

# ===== PREFIXO E VARIÁVEIS NECESSÁRIAS =====
STEAM_COMPAT_DATA_PATH="$HOME/.steam/steam/steamapps/compatdata"
STEAM_COMPAT_CLIENT_INSTALL_PATH="$HOME/.steam/steam"

export STEAM_COMPAT_DATA_PATH
export STEAM_COMPAT_CLIENT_INSTALL_PATH

# ===== LIMPEZA DE LOGS =====
echo "🧹 Apagando arquivos .RPT, .log e .mdmp em: $SERVER_DIR/profiles"
rm -f "$SERVER_DIR"/profiles/*.RPT "$SERVER_DIR"/profiles/*.ADM "$SERVER_DIR"/profiles/*.log "$SERVER_DIR"/profiles/*.mdmp
echo "✅ Limpeza concluída."

# ===== EXECUÇÃO =====
cd "$SERVER_DIR" || { echo "❌ Não foi possível entrar no diretório do servidor."; exit 1; }

echo "🚀 Iniciando servidor DayZ com Proton..."
"$PROTON_RUN" run "./$SERVER_EXE" $CONFIG $PROFILES "$MODS" "$SERVER_MODS" "$SERVER_PORT" "$SERVER_CPU" "$SERVER_OTHERS" &

SERVER_LAUNCH_PID=$!

if ! kill -0 "$SERVER_LAUNCH_PID" 2>/dev/null; then
    echo "❌ Falha ao iniciar o servidor com Proton."
    exit 1
fi

# Aguarda um pouco para o processo iniciar
sleep 5

# Captura todos os PIDs do processo real (filhos do Proton)
SERVER_PIDS=$(pgrep -u "$USER" -f "$SERVER_EXE")

# Verifica se o PID foi capturado com sucesso
if [[ -n "$SERVER_PIDS" ]]; then
    echo "✅ Servidor iniciado com os PIDs: $SERVER_PIDS"
else
    echo "❌ Não foi possível capturar o PID do servidor."
fi
# ===== CÁLCULO DO TEMPO ATÉ O PRÓXIMO REINÍCIO =====

# Obtém hora e minuto atuais
nowHour=$((10#$(date +%H)))
nowMin=$((10#$(date +%M)))

echo "Hora atual: $nowHour:$nowMin"

# Converte hora atual para minutos desde a meia-noite
totalNowMins=$((nowHour * 60 + nowMin))
echo "Minutos desde meia-noite: $totalNowMins"

# Intervalo de reinício (6 em 6 horas = 360 minutos)
interval=360

# Calcula o próximo horário de reinício em minutos desde a meia-noite
nextRestart=$(( (totalNowMins / interval + 1) * interval ))

# Ajusta para o limite do dia (1440 minutos)
if [ "$nextRestart" -ge 1440 ]; then
    nextRestart=1440
    echo "Ajuste para o restart da meia-noite: $nextRestart"
fi

# Calcula os minutos restantes até o próximo reinício
waitMins=$((nextRestart - totalNowMins))
echo "Minutos restantes: $waitMins"

# Converte para segundos
waitSecs=$((waitMins * 60))
echo "Próximo restart em $waitMins minutos ($waitSecs segundos)."

# Aguarda até o próximo reinício
sleep "$waitSecs"

# Encerra processos (ajuste conforme o nome do processo real)
echo "Encerrando servidor..."

if [[ -n "$SERVER_PIDS" ]]; then
    echo "🛑 Encerrando os seguintes PIDs: $SERVER_PIDS"
    kill $SERVER_PIDS
    sleep 2
    for pid in $SERVER_PIDS; do
        if ps -p "$pid" > /dev/null; then
            kill -9 "$pid"
        fi
    done
else
    echo "⚠️ Nenhum processo do servidor encontrado para encerrar."
fi

echo "$(date +%T) Servidor reiniciando..."

# Aguarda 10 segundos antes de reiniciar
sleep 10

# ===== Reinicia =====
exec "$SCRIPT_DIR/start_server.sh"

