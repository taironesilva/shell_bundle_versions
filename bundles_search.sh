#!/bin/bash

# ==============================
# Declaração das URLs
# ==============================
URL_HOMOLOGACAO="https://exemplo.com/homologacao/bundles.json"
URL_DESENVOLVIMENTO="https://exemplo.com/desenvolvimento/bundles.json"

# ==============================
# 1 - Perguntar ambiente
# ==============================
while true; do
    read -p "Qual o ambiente (H - Homologação / D - Desenvolvimento)? " ambiente
    if [[ "$ambiente" == "H" || "$ambiente" == "D" ]]; then
        break
    else
        echo "Resposta inválida. Digite apenas H ou D."
    fi
done

# ==============================
# 2 - Perguntar nome do componente (pode ser parte do nome)
# ==============================
read -p "Informe parte do nome do componente: " componente

# ==============================
# 3 - Perguntar versão do componente (opcional)
# ==============================
read -p "Informe a versão do componente (ou deixe em branco para listar todas): " versao

# ==============================
# 4 - Remover bundles.json se existir
# ==============================
[ -f bundles.json ] && rm -f bundles.json

# ==============================
# 5 - Definir URL de acordo com o ambiente
# ==============================
if [[ "$ambiente" == "H" ]]; then
    URL="$URL_HOMOLOGACAO"
else
    URL="$URL_DESENVOLVIMENTO"
fi

# ==============================
# 6 - Baixar novo bundles.json
# ==============================
wget -q -O bundles.json "$URL"

# Verificar se o download foi bem-sucedido
if [ $? -ne 0 ] || [ ! -s bundles.json ]; then
    echo "Erro: não foi possível baixar o arquivo bundles.json da URL $URL"
    exit 1
fi

# ==============================
# Função para formatar data (macOS)
# ==============================
formatar_data() {
    raw="$1"
    date -j -f "%Y-%m-%dT%H:%M:%SZ" "$raw" +"%d/%m/%Y %H:%M:%S"
}

# ==============================
# 7 - Buscar componentes
# ==============================
if [ -z "$versao" ]; then
    # Sem versão: listar todas as versões encontradas
    jq -r --arg comp "$componente" '
      .[]? | select(.file | test($comp)) |
      [.file, .size, .arrivedAt] | @tsv
    ' bundles.json | sort -t'-' -k2,2V | while IFS=$'\t' read file size arrived; do
        plataforma=$(echo "$file" | cut -d'/' -f1)
        nome=$(basename "$file" .zip)
        versao_extraida=$(echo "$nome" | rev | cut -d'-' -f1 | rev)
        data_formatada=$(formatar_data "$arrived")

        echo "Plataforma: $plataforma"
        echo "Componente: $nome"
        echo "Versão: $versao_extraida"
        echo "Data: $data_formatada"
        echo "-----------------------------------"
    done
else
    # Com versão: buscar apenas a versão informada, estritamente
    jq -r --arg comp "$componente" --arg ver "$versao" '
      .[]? | select(.file | test($comp) and (.file | test(".*-" + $ver + "\\.zip$"))) |
      [.file, .size, .arrivedAt] | @tsv
    ' bundles.json | while IFS=$'\t' read file size arrived; do
        plataforma=$(echo "$file" | cut -d'/' -f1)
        nome=$(basename "$file" .zip)
        data_formatada=$(formatar_data "$arrived")

        echo "Plataforma: $plataforma"
        echo "Componente: $nome"
        echo "Versão: $versao"
        echo "Data: $data_formatada"
        echo "-----------------------------------"
    done
fi
