#!/bin/bash

# =============================================================================
# log_rotation.sh  –  Rotazione e Archiviazione Log
# Archivia le righe più vecchie di SOGLIA_GIORNI giorni rispetto alla
# data più RECENTE presente nel log stesso (non la data di sistema).
# Formato log: DATA|ORA|IP|CODICE_ERRORE|PID
#
# Uso:
#   ./log_rotation.sh          -> archivia le righe vecchie
#   ./log_rotation.sh --undo   -> ripristina l'ultimo archivio nel log
# =============================================================================

ROOT_DIR="/workspaces/progetto-Bottarelli-Di_Landro-Suardi/intranet_sim"
LOG_FILE="$ROOT_DIR/logs/access.log"
ARCHIVE_DIR="$ROOT_DIR/logs/archive"
SOGLIA_GIORNI=30

mkdir -p "$ARCHIVE_DIR"

# ── UNDO: ripristina l'ultimo archivio nel log ────────────────────────────────
if [[ "$1" == "--undo" ]]; then
    echo "[*] Undo Log Rotation..."
    echo ""

    # Trova l'archivio più recente
    LAST_ARCHIVE=$(ls -t "$ARCHIVE_DIR"/access_*.log 2>/dev/null | head -1)

    if [ -z "$LAST_ARCHIVE" ]; then
        echo "[ERROR] Nessun archivio trovato in $ARCHIVE_DIR"
        exit 1
    fi

    echo "    Archivio da ripristinare : $LAST_ARCHIVE"
    echo "    Log attivo               : $LOG_FILE"
    echo ""

    RIGHE_ARCH=$(wc -l < "$LAST_ARCHIVE")
    RIGHE_LOG=$(wc -l < "$LOG_FILE")

    # Unisce archivio + log attivo e riordina cronologicamente
    cat "$LAST_ARCHIVE" "$LOG_FILE" | sort > "${LOG_FILE}.tmp" \
        && mv "${LOG_FILE}.tmp" "$LOG_FILE"

    RIGHE_DOPO=$(wc -l < "$LOG_FILE")

    # Rimuove l'archivio ripristinato
    rm -f "$LAST_ARCHIVE"

    echo "  Righe dall'archivio : $RIGHE_ARCH"
    echo "  Righe nel log prima : $RIGHE_LOG"
    echo "  Righe nel log dopo  : $RIGHE_DOPO"
    echo ""
    echo "[OK] Undo completato. Log ripristinato e riordinato cronologicamente."
    echo "     Archivio rimosso: $(basename "$LAST_ARCHIVE")"
    exit 0
fi

# ── ROTAZIONE NORMALE ────────────────────────────────────────────────────────

LATEST=$(awk -F"|" '{print $1}' "$LOG_FILE" | sort | tail -1)

if [ -z "$LATEST" ]; then
    echo "[ERROR] Log vuoto o non trovato: $LOG_FILE"
    exit 1
fi

# Calcola la data soglia 
CUTOFF=$(date -d "$LATEST -${SOGLIA_GIORNI} days" '+%Y-%m-%d' 2>/dev/null \
         || date -v-${SOGLIA_GIORNI}d -jf "%Y-%m-%d" "$LATEST" '+%Y-%m-%d')

echo "[*] Log Rotation (modalità simulata)"
echo "    Data più recente nel log : $LATEST"
echo "    Soglia archiviazione     : $CUTOFF (righe prima di questa data)"
echo ""

OLD_COUNT=$(awk -F"|" -v c="$CUTOFF" '$1 < c' "$LOG_FILE" | wc -l)
NEW_COUNT=$(awk -F"|" -v c="$CUTOFF" '$1 >= c' "$LOG_FILE" | wc -l)

if [[ "$OLD_COUNT" -eq 0 ]]; then
    echo "[INFO] Nessuna riga da archiviare."
    echo "       Tutte le righe sono nei ${SOGLIA_GIORNI} giorni precedenti a $LATEST."
    exit 0
fi

echo "  Righe da archiviare  : $OLD_COUNT"
echo "  Righe da mantenere   : $NEW_COUNT"
echo ""

# Nome archivio basato sul range di date che contiene
OLDEST=$(awk -F"|" -v c="$CUTOFF" '$1 < c {print $1}' "$LOG_FILE" | sort | head -1)
NEWEST_OLD=$(awk -F"|" -v c="$CUTOFF" '$1 < c {print $1}' "$LOG_FILE" | sort | tail -1)
ARCHIVE_PATH="$ARCHIVE_DIR/access_${OLDEST}_to_${NEWEST_OLD}.log"

# Estrae le righe vecchie nell'archivio
awk -F"|" -v c="$CUTOFF" '$1 < c' "$LOG_FILE" > "$ARCHIVE_PATH"
echo "  Archivio creato : $ARCHIVE_PATH"

# Tiene nel log attivo solo le righe recenti
awk -F"|" -v c="$CUTOFF" '$1 >= c' "$LOG_FILE" > "${LOG_FILE}.tmp" \
    && mv "${LOG_FILE}.tmp" "$LOG_FILE"

echo ""
echo "[OK] Rotazione completata."
echo "     Log attivo ora contiene $NEW_COUNT righe."
echo "     Archivi in: $ARCHIVE_DIR"
echo "     Per annullare: ./log_rotation.sh --undo"
ls -lh "$ARCHIVE_DIR/"