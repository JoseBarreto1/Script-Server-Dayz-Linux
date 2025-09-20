@echo off
setlocal enabledelayedexpansion

:: ===== CONFIGURAÇÃO =====
set "BASE_DIR=%~dp0"
set "MOD_ID_FILE=%BASE_DIR%mod_ids.txt"
set "CACHE_FILE=%BASE_DIR%cache.txt"
set "WEBHOOK_URL=https://discord.com/api/webhooks/hash-here"

:: Verificar se curl está disponível
curl --version >nul 2>&1
if errorlevel 1 (
    echo ERRO: curl nao foi encontrado no sistema!
    echo Solucoes possiveis:
    echo 1. Instale curl ou use Windows 10/11 que ja possui curl integrado
    echo 2. Baixe curl.exe e coloque na mesma pasta do script
    echo 3. Adicione curl ao PATH do sistema
    pause
    exit /b 1
)

if not exist "%CACHE_FILE%" type nul > "%CACHE_FILE%"

echo Iniciando verificacao continua de atualizacoes de mods Steam Workshop...
echo Intervalo: a cada 10 minutos
echo Inicio: %date% %time%
echo ------------------------------------------

:LOOP

for /f "delims=" %%i in (%MOD_ID_FILE%) do (
    set "MOD_ID=%%i"
    if "!MOD_ID!"=="" goto continue

    :: Remove ; do final, se houver
    if "!MOD_ID:~-1!"==";" set "MOD_ID=!MOD_ID:~0,-1!"

    set "MOD_URL=https://steamcommunity.com/sharedfiles/filedetails/?id=!MOD_ID!"

    echo Verificando mod !MOD_ID!...
    
    :: Usar curl com tratamento de erro melhorado
    curl -s --max-time 30 --retry 2 "!MOD_URL!" -o "!BASE_DIR!tmp_mod_!MOD_ID!.html" 2>nul
    if errorlevel 1 (
        echo [!MOD_ID!] Erro ao baixar pagina do mod. Pulando...
        goto continue
    )
    
    :: Verificar se o arquivo foi criado e não está vazio
    if not exist "!BASE_DIR!tmp_mod_!MOD_ID!.html" (
        echo [!MOD_ID!] Arquivo temporario nao foi criado. Pulando...
        goto continue
    )

    :: Extrai o nome do mod
    set "MOD_NAME="
    for /f "delims=" %%a in ('findstr /C:"workshopItemTitle" "!BASE_DIR!tmp_mod_!MOD_ID!.html" 2^>nul') do (
        set "line=%%a"
        setlocal enabledelayedexpansion
        for /f "tokens=2 delims=>" %%x in ("!line!") do (
            for /f "tokens=1 delims=<" %%y in ("%%x") do (
                endlocal & set "MOD_NAME=%%y"
            )
        )
    )

    :: Se não conseguir extrair o nome, usar ID como fallback
    if "!MOD_NAME!"=="" set "MOD_NAME=Mod !MOD_ID!"

    :: Extrai a terceira <div class="detailsStatRight"> que contém a data
    set /a counter=0
    set "UPDATED_DATE="
    for /f "delims=" %%a in ('findstr /C:"detailsStatRight" "!BASE_DIR!tmp_mod_!MOD_ID!.html" 2^>nul') do (
        set /a counter+=1
        if !counter! EQU 3 (
            set "line=%%a"
            setlocal enabledelayedexpansion
            for /f "tokens=2 delims=>" %%x in ("!line!") do (
                for /f "tokens=1 delims=<" %%y in ("%%x") do (
                    endlocal & set "UPDATED_DATE=%%y"
                )
            )
        )
    )

    del "!BASE_DIR!tmp_mod_!MOD_ID!.html" >nul 2>&1

    if "!UPDATED_DATE!"=="" (
        echo [!MOD_ID!] !MOD_NAME! - Erro ao obter data de atualizacao.
        goto continue
    )

    :: Remove @ da string se existir
    set "UPDATED_DATE=!UPDATED_DATE:@= !"
    
    :: Detecta se a data contém vírgula (formato com ano)
    echo !UPDATED_DATE! | findstr "," >nul
    if !errorlevel! EQU 0 (
        :: Formato com ano: "7 Nov, 2023 5:03am"
        :: Primeiro, separa a parte antes e depois da vírgula
        for /f "tokens=1,2 delims=," %%a in ("!UPDATED_DATE!") do (
            set "DATE_PART=%%a"
            set "YEAR_TIME_PART=%%b"
        )
        
        :: Extrai dia e mês da primeira parte
        for /f "tokens=1,2" %%c in ("!DATE_PART!") do (
            set "DAY=%%c"
            set "MONTH=%%d"
        )
        
        :: Remove espaços extras do início da segunda parte
        set "YEAR_TIME_PART=!YEAR_TIME_PART!"
        for /f "tokens=* delims= " %%x in ("!YEAR_TIME_PART!") do set "YEAR_TIME_PART=%%x"
        
        :: Extrai ano e hora da segunda parte
        for /f "tokens=1,2 delims= " %%e in ("!YEAR_TIME_PART!") do (
            set "YEAR=%%e"
            set "TIME=%%f"
        )
    ) else (
        :: Formato sem ano: "12 Jun 11:45am" - usa ano atual
        for /f "tokens=1,2,3 delims= " %%a in ("!UPDATED_DATE!") do (
            set "DAY=%%a"
            set "MONTH=%%b"
            set "TIME=%%c"
        )
        
        :: Obter ano atual usando wmic
        set "YEAR="
        for /f "tokens=2 delims==" %%Y in ('wmic os get LocalDateTime /value 2^>nul ^| find "="') do (
            set "LOCALDT=%%Y"
        )
        if defined LOCALDT (
            set "YEAR=!LOCALDT:~0,4!"
        ) else (
            echo Erro: Nao foi possivel obter o ano atual.
            set "YEAR=2025" :: Valor padrão
        )
    )

    :: Converte nome do mês para número (incluindo versões em inglês)
    set "MONTH_NUM="
    if /i "!MONTH!"=="Jan" set "MONTH_NUM=1"
    if /i "!MONTH!"=="Feb" set "MONTH_NUM=2"
    if /i "!MONTH!"=="Fev" set "MONTH_NUM=2"
    if /i "!MONTH!"=="Mar" set "MONTH_NUM=3"
    if /i "!MONTH!"=="Apr" set "MONTH_NUM=4"
    if /i "!MONTH!"=="Abr" set "MONTH_NUM=4"
    if /i "!MONTH!"=="May" set "MONTH_NUM=5"
    if /i "!MONTH!"=="Mai" set "MONTH_NUM=5"
    if /i "!MONTH!"=="Jun" set "MONTH_NUM=6"
    if /i "!MONTH!"=="Jul" set "MONTH_NUM=7"
    if /i "!MONTH!"=="Aug" set "MONTH_NUM=8"
    if /i "!MONTH!"=="Ago" set "MONTH_NUM=8"
    if /i "!MONTH!"=="Sep" set "MONTH_NUM=9"
    if /i "!MONTH!"=="Set" set "MONTH_NUM=9"
    if /i "!MONTH!"=="Oct" set "MONTH_NUM=10"
    if /i "!MONTH!"=="Out" set "MONTH_NUM=10"
    if /i "!MONTH!"=="Nov" set "MONTH_NUM=11"
    if /i "!MONTH!"=="Dec" set "MONTH_NUM=12"
    if /i "!MONTH!"=="Dez" set "MONTH_NUM=12"
    
    if not defined MONTH_NUM (
        echo Erro: Mes '!MONTH!' nao reconhecido. Pulando mod !MOD_ID!.
        goto continue
    )

    :: Extrair hora e minuto corretamente do formato 12h para 24h
    set "HOUR="
    set "MINUTE="
    set "AMPM="
    
    :: Extrair AM/PM
    echo !TIME! | findstr /i "am" >nul
    if !errorlevel! EQU 0 set "AMPM=AM"
    echo !TIME! | findstr /i "pm" >nul
    if !errorlevel! EQU 0 set "AMPM=PM"
    
    :: Remove AM/PM da string de tempo
    set "TIME_CLEAN=!TIME!"
    set "TIME_CLEAN=!TIME_CLEAN:am=!"
    set "TIME_CLEAN=!TIME_CLEAN:pm=!"
    set "TIME_CLEAN=!TIME_CLEAN:AM=!"
    set "TIME_CLEAN=!TIME_CLEAN:PM=!"
    
    :: Extrai hora e minuto
    for /f "tokens=1,2 delims=:" %%s in ("!TIME_CLEAN!") do (
        set "HOUR=%%s"
        set "MINUTE=%%t"
    )
    
    :: Se não conseguiu extrair minuto, assume 0
    if not defined MINUTE set "MINUTE=0"
    
    :: Converte para formato 24h
    if defined HOUR (
        set /a HOUR_NUM=!HOUR!
        if "!AMPM!"=="PM" (
            if !HOUR_NUM! NEQ 12 set /a HOUR_NUM=!HOUR_NUM!+12
        )
        if "!AMPM!"=="AM" (
            if !HOUR_NUM! EQU 12 set /a HOUR_NUM=0
        )
    ) else (
        set /a HOUR_NUM=0
    )

    :: Garantir que variáveis sejam numéricas
    set /a YEAR_NUM=!YEAR!
    set /a MONTH_NUM_NUM=!MONTH_NUM!
    set /a DAY_NUM=!DAY!
    set /a MINUTE_NUM=!MINUTE!

    :: Calcular timestamp simplificado baseado em minutos
    set /a "MOD_TIMESTAMP=(YEAR_NUM*525600) + (MONTH_NUM_NUM*43200) + (DAY_NUM*1440) + (HOUR_NUM*60) + MINUTE_NUM"

    :: Verificar se o MOD_ID já existe no cache e obter o último timestamp
    set "LAST_TIMESTAMP="
    set "MOD_EXISTS_IN_CACHE=0"
    
    if exist "%CACHE_FILE%" (
        for /f "usebackq tokens=1,2 delims=:" %%a in ("%CACHE_FILE%") do (
            if "%%a"=="!MOD_ID!" (
                set "LAST_TIMESTAMP=%%b"
                set "MOD_EXISTS_IN_CACHE=1"
            )
        )
    )

    if "!MOD_EXISTS_IN_CACHE!"=="0" (
        :: Primeira verificação - adicionar ao cache
        echo [!MOD_ID!] !MOD_NAME! - Primeira verificacao, atualizado em: !UPDATED_DATE!
        echo !MOD_ID!:!MOD_TIMESTAMP!>>"%CACHE_FILE%"
    ) else (
        :: MOD já existe no cache - comparar timestamps
        set /a DIFF=!MOD_TIMESTAMP!-!LAST_TIMESTAMP!
        
        if !DIFF! GTR 0 (
            echo [!MOD_ID!] !MOD_NAME! - FOI ATUALIZADO! Nova data: !UPDATED_DATE!

            :: Criar arquivo temporário para atualizar o cache
            set "TEMP_CACHE=%BASE_DIR%temp_cache.txt"
            if exist "!TEMP_CACHE!" del "!TEMP_CACHE!"
            
            :: Reescrever o cache substituindo a linha do mod atual
            for /f "usebackq tokens=1,2 delims=:" %%a in ("%CACHE_FILE%") do (
                if "%%a"=="!MOD_ID!" (
                    echo !MOD_ID!:!MOD_TIMESTAMP!>>"!TEMP_CACHE!"
                ) else (
                    echo %%a:%%b>>"!TEMP_CACHE!"
                )
            )
            
            :: Substituir o cache original pelo temporário
            move "!TEMP_CACHE!" "%CACHE_FILE%" >nul 2>&1

            :: Formatar data para o Discord (DD/MM/YYYY HH:MM)
            if !DAY_NUM! LSS 10 set "DAY_FORMATTED=0!DAY_NUM!"
            if !DAY_NUM! GEQ 10 set "DAY_FORMATTED=!DAY_NUM!"
            
            if !MONTH_NUM_NUM! LSS 10 set "MONTH_FORMATTED=0!MONTH_NUM_NUM!"
            if !MONTH_NUM_NUM! GEQ 10 set "MONTH_FORMATTED=!MONTH_NUM_NUM!"
            
            if !HOUR_NUM! LSS 10 set "HOUR_FORMATTED=0!HOUR_NUM!"
            if !HOUR_NUM! GEQ 10 set "HOUR_FORMATTED=!HOUR_NUM!"
            
            if !MINUTE_NUM! LSS 10 set "MINUTE_FORMATTED=0!MINUTE_NUM!"
            if !MINUTE_NUM! GEQ 10 set "MINUTE_FORMATTED=!MINUTE_NUM!"
            
            :: Soma 3 horas
            set /a NEW_HOUR=HOUR_FORMATTED + 4

            :: Verifica se passou de 23 e ajusta para o dia seguinte
            if !NEW_HOUR! GEQ 24 (
                set /a NEW_HOUR-=24
                set /a DAY_FORMATTED+=1

            :: Verificação simples de mudança de mês (opcional, melhora a robustez)
            :: Aqui você pode implementar a lógica para mudar de mês/ano se quiser
            )

            :: Formata a hora se tiver apenas 1 dígito
            if !NEW_HOUR! LSS 10 set NEW_HOUR=0!NEW_HOUR!

            set "FORMATTED_DATE=!DAY_FORMATTED!/!MONTH_FORMATTED!/!YEAR_NUM! !NEW_HOUR!:!MINUTE_FORMATTED!"

            :: Enviar webhook usando PowerShell diretamente (mais confiável)
            set "WEBHOOK_MESSAGE=:jigsaw: **Mod atualizado!**\n"
            set "WEBHOOK_MESSAGE=!WEBHOOK_MESSAGE!:pushpin: Nome: **!MOD_NAME!**\n"
            set "WEBHOOK_MESSAGE=!WEBHOOK_MESSAGE!:id: ID: !MOD_ID!\n"
            set "WEBHOOK_MESSAGE=!WEBHOOK_MESSAGE!:date: Atualizado em: !FORMATTED_DATE!\n"
            set "WEBHOOK_MESSAGE=!WEBHOOK_MESSAGE!:link: !MOD_URL!\n"
            set "WEBHOOK_MESSAGE=!WEBHOOK_MESSAGE!@everyone"

            curl -H "Content-Type: application/json" ^
                -X POST ^
                -d "{\"username\":\"DayZ Mod Watcher\",\"content\":\"!WEBHOOK_MESSAGE!\"}" ^
                "!WEBHOOK_URL!" >nul 2>&1 && echo [!MOD_ID!] Notificacao enviada com sucesso || echo [!MOD_ID!] Erro ao enviar notificacao

        ) else if !DIFF! EQU 0 (
            echo [!MOD_ID!] !MOD_NAME! - Sem alteracoes desde: !UPDATED_DATE!
        ) else (
            echo [!MOD_ID!] !MOD_NAME! - Data anterior mais recente que atual. Atualizando cache...
            
            :: Criar arquivo temporário para atualizar o cache
            set "TEMP_CACHE=%BASE_DIR%temp_cache.txt"
            if exist "!TEMP_CACHE!" del "!TEMP_CACHE!"
            
            :: Reescrever o cache substituindo a linha do mod atual
            for /f "usebackq tokens=1,2 delims=:" %%a in ("%CACHE_FILE%") do (
                if "%%a"=="!MOD_ID!" (
                    echo !MOD_ID!:!MOD_TIMESTAMP!>>"!TEMP_CACHE!"
                ) else (
                    echo %%a:%%b>>"!TEMP_CACHE!"
                )
            )
            
            :: Substituir o cache original pelo temporário
            move "!TEMP_CACHE!" "%CACHE_FILE%" >nul 2>&1
        )
    )

    :continue
    timeout /t 2 >nul
)

echo Aguardando 10 minutos para proxima verificacao...
echo ------------------------------------------
timeout /t 600 >nul
goto LOOP
