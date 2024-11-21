#!/bin/bash

# Boas-vindas
echo "=== Gestor de Backup ==="
echo "Automatize e proteja seus arquivos com backups."
echo "Este script permite fazer backup de arquivos e diretórios, e permite configurar agendamentos."
echo " O agendamento persiste para futuras execuções, mesmo se o computador for reiniciado."


# Função para fazer backup
fazer_backup() {
    echo "Digite o diretório ou arquivo que deseja fazer backup: Exemplo: /caminho/completo/do/diretorio"
    read ORIGEM

    echo "Digite o caminho de destino do backup: Exemplo: /caminho/completo/do/diretorio"
    read DESTINO

    echo "Digite o nome do arquivo de backup (sem extensão): Exemplo: backup_20241121"
    read NOME
    if [ -z "$NOME" ]; then
        NOME="backup_$(date +%Y%m%d_%H%M%S)"
    fi

    # Compactar e salvar
    TAR_FILE="$DESTINO/$NOME.tar.gz"
    echo "Criando backup em $TAR_FILE..."
    tar -czf "$TAR_FILE" "$ORIGEM"

    if [ $? -eq 0 ]; then
        echo "Backup concluído com sucesso!"
    else
        echo "Erro ao criar o backup."
    fi
}

# Função para configurar agendamento
configurar_agendamento() {
    echo "Configurar agendamento de backup."
    echo "Digite o horário do backup (formato: HH:MM):"
    read HORARIO

    echo "Digite o dia e mês para o backup (formato: MM-DD):"
    read DIA

    echo "Digite o diretório ou arquivo que deseja fazer backup: Exemplo: /caminho/completo/do/diretorio"
    read ORIGEM

    echo "Digite o caminho de destino do backup: Exemplo: /caminho/completo/do/diretorio"
    read DESTINO

    echo "Digite o nome do arquivo de backup (opcional): Exemplo: backup_20241121"
    read NOME
    if [ -z "$NOME" ]; then
        NOME="backup_$(date +%Y%m%d)"
    fi

    # Comando do cron
    CRON_CMD="0 ${HORARIO%:*} ${DIA} * * tar -czf $DESTINO/$NOME.tar.gz $ORIGEM"
    (crontab -l 2>/dev/null; echo "$CRON_CMD") | crontab -

    echo "Backup agendado com sucesso!"
}

# Menu principal
while true; do
    echo "Escolha uma opção:"
    echo "1. Fazer backup agora"
    echo "2. Configurar agendamento"
    echo "3. Sair"
    read OPCAO

    case $OPCAO in
        1) fazer_backup ;;
        2) configurar_agendamento ;;
        3) echo "Saindo..."; exit ;;
        *) echo "Opção inválida." ;;
    esac
done
