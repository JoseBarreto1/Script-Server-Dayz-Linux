#!/bin/bash

# ===== CONFIGURAÇÃO =====
SERVER_DIR="$HOME/.steam/steam/steamapps/common/DayZServer"
SCRIPT_DIR="$SERVER_DIR/script_server_linux"
MOD_ID_FILE="mod_ids.txt"

MODS_ID=$(<"$SCRIPT_DIR/$MOD_ID_FILE")
MODS_ID="${MODS_ID//\"/}"  # Remove aspas
MODS_ID="${MODS_ID// /}"   # Remove espaços
MODS_ID="${MODS_ID//$'\n'/}"  # Remove quebras de linha
MODS_ID="${MODS_ID//$'\t'/}"  # (Opcional) Remove tabs

IFS=';' read -ra IDS <<< "$MODS_ID"

WEBHOOK_URL=""
CACHE_FILE="$HOME/.cache/dayz_mods_update_check"
mkdir -p "$(dirname "$CACHE_FILE")"
touch "$CACHE_FILE"

echo "🚀 Iniciando verificação contínua de atualizações de mods Steam Workshop..."
echo "⏱️ Intervalo: a cada 10 minutos"
echo "📅 Início: $(date)"
echo "------------------------------------------"

while true; do
    echo "🔄 Verificando atualizações... ($(date))"
    
    for id in "${IDS[@]}"; do
    	[[ -z "$id" ]] && continue  # pula entradas vazias (como a última)
    	
        MOD_URL="https://steamcommunity.com/sharedfiles/filedetails/?id=$id"
        
        HTML=$(curl -s "$MOD_URL")

        # Extrai o nome do mod
        MOD_NAME=$(echo "$HTML" | grep -oP '<div class="workshopItemTitle">.*?</div>' | sed -e 's/<[^>]*>//g' | xargs)

        # Extrai a data da última atualização
        UPDATED_DATE=$(echo "$HTML" | grep -oP '<div class="detailsStatRight">.*?</div>' | sed -e 's/<[^>]*>//g' | sed -n '3p' | xargs)

        # Converte a data para timestamp (Unix time)
        if [[ -n "$UPDATED_DATE" ]]; then
            UPDATED_DATE_EN=$(echo "$UPDATED_DATE" | sed -e 's/jan\./Jan/' -e 's/fev\./Feb/' -e 's/mar\./Mar/' -e 's/abr\./Apr/' \
                                              -e 's/mai\./May/' -e 's/jun\./Jun/' -e 's/jul\./Jul/' -e 's/ago\./Aug/' \
                                              -e 's/set\./Sep/' -e 's/out\./Oct/' -e 's/nov\./Nov/' -e 's/dez\./Dec/')

	    # Remove vírgulas e "@"
	    UPDATED_DATE_CLEAN=$(echo "$UPDATED_DATE" | sed -E 's/,//g; s/@//g' | xargs)

	    # Se já contém ano explícito
	    if [[ "$UPDATED_DATE_CLEAN" =~ [0-9]{4} ]]; then
	        DATE_TO_PARSE="$UPDATED_DATE_CLEAN"
	    else
	        CURRENT_YEAR=$(date +%Y)
	        # Move o horário para o fim: ex: "28 Feb 8:02am" -> "28 Feb 2025 8:02am"
	        DATE_TO_PARSE=$(echo "$UPDATED_DATE_CLEAN $CURRENT_YEAR" | awk '{print $1, $2, $4, $3}')
	    fi

	    # Converte para timestamp
	    MOD_TIMESTAMP=$(date -d "$DATE_TO_PARSE" +%s 2>/dev/null)
        
        else
            MOD_TIMESTAMP=0
        fi
        
        # Verifica se a conversão foi bem-sucedida
	if [[ -z "$MOD_TIMESTAMP" ]]; then
	    echo "⚠️ [$id] $MOD_NAME — Erro ao converter a data: '$UPDATED_DATE' (tratada: '$DATE_TO_PARSE')"
	fi

        # Carrega timestamp salvo
        LAST_TIMESTAMP=$(grep "^$id:" "$CACHE_FILE" | cut -d: -f2)

        # Verificação de atualização
        if [[ -z "$LAST_TIMESTAMP" ]]; then
            echo "📌 [$id] $MOD_NAME — Primeira verificação, atualizado em: $UPDATED_DATE"
            if [[ "$MOD_TIMESTAMP" -gt 0 ]]; then
	        echo "$id:$MOD_TIMESTAMP" >> "$CACHE_FILE"
	    fi
        elif [[ "$MOD_TIMESTAMP" -gt "$LAST_TIMESTAMP" ]]; then
            echo "✅ [$id] $MOD_NAME — FOI ATUALIZADO! Nova data: $UPDATED_DATE"
            sed -i "s/^$id:.*/$id:$MOD_TIMESTAMP/" "$CACHE_FILE"

            # Envia notificação ao Discord
            curl -s -X POST "$WEBHOOK_URL" \
                -H "Content-Type: application/json" \
                -d @- <<EOF
{
  "username": "DayZ Mod Watcher",
  "content": "🧩 **Mod atualizado!**\n📌 Nome: **$MOD_NAME**\n🆔 ID: \`$id\`\n📅 Atualizado em: $UPDATED_DATE\n🔗 $MOD_URL\n@everyone""
}
EOF
        else
            echo "⏸️ [$id] $MOD_NAME — Sem alterações desde: $UPDATED_DATE"
        fi

        sleep 2  # Atraso entre as requisições
    done

    echo "🕔 Aguardando 10 minutos para próxima verificação..."
    echo "------------------------------------------"
    sleep 600
done

