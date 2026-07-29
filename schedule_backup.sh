#!/bin/bash

SCRIPT_PATH="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
STATE_DIR="$HOME/.backup_manager"
LOG_FILE="$HOME/backup.log"
DEFAULT_BACKUP_DIR="$HOME/backups"

mkdir -p "$STATE_DIR"

validar_horario() {
    local horario="$1"

    if [[ ! "$horario" =~ ^([01][0-9]|2[0-3]):([0-5][0-9])$ ]]; then
        return 1
    fi

    return 0
}

validar_regularidade() {
    local dias="$1"

    if [[ ! "$dias" =~ ^[1-9][0-9]*$ ]]; then
        return 1
    fi

    return 0
}

registrar_log() {
    local mensagem="$1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $mensagem" >> "$LOG_FILE"
}

executar_backup() {
    local origem="$1"
    local destino="$2"
    local nome_base="$3"
    local run_id="$4"
    local tar_file

    if [ ! -e "$origem" ]; then
        echo "Erro: a origem informada nao existe."
        registrar_log "Falha no backup agendado ($run_id): origem inexistente: $origem"
        return 1
    fi

    mkdir -p "$destino"

    tar_file="$destino/${nome_base}_$(date +%Y%m%d_%H%M%S).tar.gz"
    echo "Criando backup em $tar_file..."

    if tar -czf "$tar_file" "$origem"; then
        echo "Backup concluido com sucesso!"
        registrar_log "Backup criado: $tar_file"
        return 0
    fi

    echo "Erro ao criar o backup."
    registrar_log "Falha ao criar backup: $tar_file"
    return 1
}

executar_agendamento() {
    local run_id="$1"
    local schedule_file="$STATE_DIR/${run_id}.conf"
    local last_run_file="$STATE_DIR/${run_id}.last_run"
    local hoje
    local ultimo_dia
    local diferenca

    if [ ! -f "$schedule_file" ]; then
        registrar_log "Falha no agendamento ($run_id): configuracao nao encontrada."
        exit 1
    fi

    # shellcheck disable=SC1090
    source "$schedule_file"

    hoje=$(date +%s)

    if [ -f "$last_run_file" ]; then
        ultimo_dia=$(cat "$last_run_file")
        diferenca=$(( (hoje - ultimo_dia) / 86400 ))

        if [ "$diferenca" -lt "$REGULARIDADE_DIAS" ]; then
            exit 0
        fi
    fi

    if executar_backup "$ORIGEM" "$DESTINO" "$NOME" "$run_id"; then
        date +%s > "$last_run_file"
        exit 0
    fi

    exit 1
}

mostrar_boas_vindas() {
    echo "=== Gestor de Backup ==="
    echo "Automatize e proteja seus arquivos com backups."
    echo "Este script permite fazer backup de arquivos e diretorios, e permite configurar agendamentos."
    echo "O agendamento persiste para futuras execucoes, mesmo se o computador for reiniciado."
}

coletar_dados_backup() {
    echo "Digite o diretorio ou arquivo que deseja fazer backup: Exemplo: /caminho/completo/do/diretorio"
    read -r ORIGEM

    if [ ! -e "$ORIGEM" ]; then
        echo "Erro: a origem informada nao existe."
        return 1
    fi

    echo "Digite o caminho de destino do backup [padrao: $DEFAULT_BACKUP_DIR]."
    echo "Pressione Enter para usar o padrao:"
    read -r DESTINO

    if [ -z "$DESTINO" ]; then
        DESTINO="$DEFAULT_BACKUP_DIR"
    fi

    echo "Digite o nome do arquivo de backup (sem extensao). Pressione Enter para usar o padrao:"
    read -r NOME

    if [ -z "$NOME" ]; then
        NOME="backup"
    fi

    return 0
}

fazer_backup() {
    if ! coletar_dados_backup; then
        return 1
    fi

    executar_backup "$ORIGEM" "$DESTINO" "$NOME" "manual"
}

configurar_agendamento() {
    local horario
    local regularidade
    local run_id
    local schedule_file
    local cron_cmd

    echo "Configurar agendamento de backup."
    echo "Informe a regularidade em dias:"
    read -r regularidade

    if ! validar_regularidade "$regularidade"; then
        echo "Erro: informe um numero inteiro maior que zero."
        return 1
    fi

    echo "Informe a hora desejada do backup [padrao: 02:00]."
    echo "Pressione Enter para manter o padrao ou informe HH:MM no formato 24 horas:"
    read -r horario

    if [ -z "$horario" ]; then
        horario="02:00"
    fi

    if ! validar_horario "$horario"; then
        echo "Erro: horario invalido. Use o formato HH:MM."
        return 1
    fi

    if ! coletar_dados_backup; then
        return 1
    fi

    run_id="backup_$(date +%Y%m%d%H%M%S)"
    schedule_file="$STATE_DIR/${run_id}.conf"

    cat > "$schedule_file" <<EOF
ORIGEM=$(printf '%q' "$ORIGEM")
DESTINO=$(printf '%q' "$DESTINO")
NOME=$(printf '%q' "$NOME")
REGULARIDADE_DIAS=$regularidade
HORARIO=$(printf '%q' "$horario")
EOF

    cron_cmd="${horario#*:} ${horario%:*} * * * \"$SCRIPT_PATH\" --run-scheduled \"$run_id\" >/dev/null 2>&1"
    (crontab -l 2>/dev/null | grep -Fv -- "--run-scheduled \"$run_id\""; echo "$cron_cmd") | crontab -

    echo "Backup agendado com sucesso!"
    echo "Regularidade: a cada $regularidade dia(s), sempre as $horario."
    registrar_log "Agendamento criado ($run_id): $origem -> $destino, a cada $regularidade dia(s) as $horario"
}

if [ "$1" = "--run-scheduled" ]; then
    executar_agendamento "$2"
fi

mostrar_boas_vindas

while true; do
    echo "Escolha uma opcao:"
    echo "1. Fazer backup agora"
    echo "2. Configurar agendamento"
    echo "3. Sair"
    read -r OPCAO

    case $OPCAO in
        1) fazer_backup ;;
        2) configurar_agendamento ;;
        3) echo "Saindo..."; exit 0 ;;
        *) echo "Opcao invalida." ;;
    esac
done
