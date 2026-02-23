#!/bin/bash

# =============================================================================
# backup.sh  –  Backup Automatico CSV Utenti e Whitelist
# Crea backup timestampati di users.csv e whitelist.conf.
# Mantiene solo gli ultimi MAX_BACKUP backup per non riempire il disco.
# Permette anche di ripristinare un backup precedente.
# =============================================================================

ROOT_DIR="/workspaces/progetto-Bottarelli-Di_Landro-Suardi/intranet_sim"
USERS_CSV="$ROOT_DIR/data/users.csv"
WHITELIST="$ROOT_DIR/config/whitelist.conf"
BACKUP_DIR="$ROOT_DIR/data/backups"
MAX_BACKUP=5   # numero massimo di backup da conservare per file

mkdir -p "$BACKUP_DIR"

USAGE="Uso: ./backup.sh [OPZIONE]
  (nessuna)        Esegue il backup di users.csv e whitelist.conf
  --list           Mostra i backup disponibili
  --restore [FILE] Ripristina un backup specifico (percorso completo)"

case "$1" in

    # ── LIST: mostra backup disponibili ──────────────────────────────────────
    --list)
        echo "=== Backup disponibili in $BACKUP_DIR ==="
        echo ""
        if [ -z "$(ls "$BACKUP_DIR" 2>/dev/null)" ]; then
            echo "  Nessun backup trovato."
        else
            echo "  UTENTI (users.csv):"
            ls -lh "$BACKUP_DIR"/users_*.csv 2>/dev/null \
                | awk '{printf "    %s  %s\n", $5, $9}' \
                || echo "    Nessuno."
            echo ""
            echo "  WHITELIST (whitelist.conf):"
            ls -lh "$BACKUP_DIR"/whitelist_*.conf 2>/dev/null \
                | awk '{printf "    %s  %s\n", $5, $9}' \
                || echo "    Nessuno."
        fi
        exit 0
        ;;

    # ── RESTORE: ripristina un backup ────────────────────────────────────────
    --restore)
        BACKUP_FILE="$2"
        if [ -z "$BACKUP_FILE" ]; then
            echo "Errore: specificare il file di backup da ripristinare."
            echo "Usa ./backup.sh --list per vedere i backup disponibili."
            exit 1
        fi
        if [ ! -f "$BACKUP_FILE" ]; then
            echo "Errore: file '$BACKUP_FILE' non trovato."
            exit 1
        fi

        # Determina quale file ripristinare in base al nome
        BASENAME=$(basename "$BACKUP_FILE")
        if [[ "$BASENAME" == users_* ]]; then
            DEST="$USERS_CSV"
            DEST_NAME="users.csv"
        elif [[ "$BASENAME" == whitelist_* ]]; then
            DEST="$WHITELIST"
            DEST_NAME="whitelist.conf"
        else
            echo "Errore: impossibile determinare il tipo di backup da '$BASENAME'."
            exit 1
        fi

        echo "Ripristino '$BACKUP_FILE' -> '$DEST'"
        read -rp "Confermare? [Y/n]: " CONFIRM
        if [[ "$CONFIRM" == "Y" ]]; then
            # Backup di sicurezza del file corrente prima di sovrascriverlo
            TS=$(date '+%Y%m%d_%H%M%S')
            cp "$DEST" "$BACKUP_DIR/${DEST_NAME%.*}_pre_restore_${TS}.${DEST##*.}" 2>/dev/null
            cp "$BACKUP_FILE" "$DEST"
            echo "[OK] Ripristino completato."
        else
            echo "Operazione annullata."
        fi
        exit 0
        ;;

    "")  ;;
    *)   echo "$USAGE"; exit 1 ;;
esac

# ── BACKUP ───────────────────────────────────────────────────────────────────
TS=$(date '+%Y%m%d_%H%M%S')
ERRORI=0

echo "[*] Backup automatico in corso..."
echo "    Destinazione: $BACKUP_DIR"
echo "    Timestamp: $TS"
echo ""

# Backup users.csv
if [ -f "$USERS_CSV" ]; then
    DEST_USERS="$BACKUP_DIR/users_${TS}.csv"
    cp "$USERS_CSV" "$DEST_USERS"
    SIZE=$(du -h "$DEST_USERS" | cut -f1)
    echo "  [OK] users.csv     -> users_${TS}.csv ($SIZE)"
else
    echo "  [WARN] users.csv non trovato, saltato."
    (( ERRORI++ ))
fi

# Backup whitelist.conf
if [ -f "$WHITELIST" ]; then
    DEST_WL="$BACKUP_DIR/whitelist_${TS}.conf"
    cp "$WHITELIST" "$DEST_WL"
    SIZE=$(du -h "$DEST_WL" | cut -f1)
    echo "  [OK] whitelist.conf -> whitelist_${TS}.conf ($SIZE)"
else
    echo "  [WARN] whitelist.conf non trovata, saltata."
    (( ERRORI++ ))
fi

# Pulizia: mantieni solo gli ultimi MAX_BACKUP backup per tipo
echo ""
echo "[*] Pulizia vecchi backup (max $MAX_BACKUP per file)..."

for PREFIX in users whitelist; do
    EXT="csv"; [ "$PREFIX" == "whitelist" ] && EXT="conf"
    LISTA=$(ls -t "$BACKUP_DIR"/${PREFIX}_*.${EXT} 2>/dev/null)
    TOTALE=$(echo "$LISTA" | grep -c . 2>/dev/null || echo 0)
    if (( TOTALE > MAX_BACKUP )); then
        DA_ELIMINARE=$(echo "$LISTA" | tail -n +$(( MAX_BACKUP + 1 )))
        while IFS= read -r f; do
            [ -z "$f" ] && continue
            rm -f "$f"
            echo "  [DEL] $(basename "$f")"
        done <<< "$DA_ELIMINARE"
    fi
done

echo ""
echo "[OK] Backup completato$([ $ERRORI -gt 0 ] && echo " con $ERRORI avvisi" || echo "")."
echo "     Usa './backup.sh --list' per vedere tutti i backup disponibili."
