#!/bin/bash

# =============================================================================
# audit_trail.sh  –  Audit Trail Modifiche CSV Utenti
# Tiene traccia di ogni modifica al file users.csv confrontando
# uno snapshot precedente con lo stato attuale.
# Ad ogni esecuzione:
#   1. Confronta il CSV attuale con lo snapshot salvato
#   2. Registra le differenze (utenti aggiunti, rimossi, modificati)
#   3. Aggiorna lo snapshot
# =============================================================================

ROOT_DIR="/workspaces/progetto-Bottarelli-Di_Landro-Suardi/intranet_sim"
USERS_CSV="$ROOT_DIR/data/users.csv"
SNAPSHOT="$ROOT_DIR/data/users_snapshot.csv"
OUT_DIR="$ROOT_DIR/logs_output"
AUDIT_LOG="$OUT_DIR/audit_trail.log"

mkdir -p "$OUT_DIR"

USAGE="Uso: ./audit_trail.sh [OPZIONE]
  (nessuna)   Confronta CSV attuale con snapshot e registra le modifiche
  --init      Crea lo snapshot iniziale senza registrare modifiche
  --show      Mostra il log audit completo"

case "$1" in

    # ── INIT: crea snapshot iniziale ────────────────────────────────────────
    --init)
        if [ -f "$SNAPSHOT" ]; then
            read -rp "Snapshot già esistente. Sovrascrivere? [Y/n]: " CONFIRM
            [[ "$CONFIRM" != "Y" ]] && echo "Operazione annullata." && exit 0
        fi
        cp "$USERS_CSV" "$SNAPSHOT"
        TS=$(date '+%Y-%m-%d %H:%M:%S')
        echo "$TS | INIT | Snapshot iniziale creato." >> "$AUDIT_LOG"
        echo "[OK] Snapshot iniziale creato in $SNAPSHOT"
        exit 0
        ;;

    # ── SHOW: mostra il log audit ────────────────────────────────────────────
    --show)
        if [ ! -f "$AUDIT_LOG" ]; then
            echo "Nessun audit log trovato. Esegui prima ./audit_trail.sh --init"
            exit 0
        fi
        echo "=== AUDIT TRAIL - $AUDIT_LOG ==="
        cat "$AUDIT_LOG"
        exit 0
        ;;

    "")  ;;
    *)   echo "$USAGE"; exit 1 ;;
esac

# ── CONFRONTO ────────────────────────────────────────────────────────────────

if [ ! -f "$SNAPSHOT" ]; then
    echo "[INFO] Nessuno snapshot trovato. Creazione snapshot iniziale..."
    cp "$USERS_CSV" "$SNAPSHOT"
    TS=$(date '+%Y-%m-%d %H:%M:%S')
    echo "$TS | INIT | Snapshot iniziale creato automaticamente." >> "$AUDIT_LOG"
    echo "[OK] Snapshot creato. Riesegui lo script per rilevare modifiche future."
    exit 0
fi

TS=$(date '+%Y-%m-%d %H:%M:%S')
MODIFICHE=0

echo "[*] Audit trail - confronto CSV con snapshot..."
echo ""

# ── Utenti AGGIUNTI (presenti nel CSV attuale ma non nello snapshot) ──────────
while IFS=',' read -r id nome mail pass level ip; do
    [ "$id" == "id" ] && continue   # salta header
    if ! grep -q "^$id," "$SNAPSHOT"; then
        MSG="$TS | AGGIUNTO | ID: $id | Nome: $nome | Mail: $mail | Level: $level | IP: $ip"
        echo "  [+] UTENTE AGGIUNTO: $nome (ID: $id, mail: $mail, level: $level)"
        echo "$MSG" >> "$AUDIT_LOG"
        (( MODIFICHE++ ))
    fi
done < "$USERS_CSV"

# ── Utenti RIMOSSI (presenti nello snapshot ma non nel CSV attuale) ───────────
while IFS=',' read -r id nome mail pass level ip; do
    [ "$id" == "id" ] && continue
    if ! grep -q "^$id," "$USERS_CSV"; then
        MSG="$TS | RIMOSSO | ID: $id | Nome: $nome | Mail: $mail | Level: $level | IP: $ip"
        echo "  [-] UTENTE RIMOSSO: $nome (ID: $id, mail: $mail)"
        echo "$MSG" >> "$AUDIT_LOG"
        (( MODIFICHE++ ))
    fi
done < "$SNAPSHOT"

# ── Utenti MODIFICATI (stessa ID ma campi diversi) ────────────────────────────
while IFS=',' read -r id nome mail pass level ip; do
    [ "$id" == "id" ] && continue
    # Cerca la stessa riga nello snapshot
    OLD=$(grep "^$id," "$SNAPSHOT" 2>/dev/null)
    NEW=$(grep "^$id," "$USERS_CSV" 2>/dev/null)
    if [ -n "$OLD" ] && [ "$OLD" != "$NEW" ]; then
        OLD_LEVEL=$(echo "$OLD" | cut -d',' -f5)
        NEW_LEVEL=$(echo "$NEW" | cut -d',' -f5)
        OLD_IP=$(echo "$OLD" | cut -d',' -f6)
        NEW_IP=$(echo "$NEW" | cut -d',' -f6)
        OLD_MAIL=$(echo "$OLD" | cut -d',' -f3)
        NEW_MAIL=$(echo "$NEW" | cut -d',' -f3)

        DETTAGLI=""
        [ "$OLD_LEVEL" != "$NEW_LEVEL" ] && DETTAGLI="${DETTAGLI}level: $OLD_LEVEL -> $NEW_LEVEL | "
        [ "$OLD_IP"    != "$NEW_IP"    ] && DETTAGLI="${DETTAGLI}ip: $OLD_IP -> $NEW_IP | "
        [ "$OLD_MAIL"  != "$NEW_MAIL"  ] && DETTAGLI="${DETTAGLI}mail: $OLD_MAIL -> $NEW_MAIL | "
        # Controlla anche password (senza mostrarla)
        OLD_PASS=$(echo "$OLD" | cut -d',' -f4)
        NEW_PASS=$(echo "$NEW" | cut -d',' -f4)
        [ "$OLD_PASS"  != "$NEW_PASS"  ] && DETTAGLI="${DETTAGLI}password: modificata | "

        MSG="$TS | MODIFICATO | ID: $id | Nome: $nome | $DETTAGLI"
        echo "  [~] UTENTE MODIFICATO: $nome (ID: $id) -> ${DETTAGLI% | }"
        echo "$MSG" >> "$AUDIT_LOG"
        (( MODIFICHE++ ))
    fi
done < "$USERS_CSV"

# ── Aggiorna snapshot ─────────────────────────────────────────────────────────
cp "$USERS_CSV" "$SNAPSHOT"

echo ""
if [ "$MODIFICHE" -eq 0 ]; then
    echo "[OK] Nessuna modifica rilevata dal precedente snapshot."
    echo "$TS | NESSUNA MODIFICA | Snapshot aggiornato." >> "$AUDIT_LOG"
else
    echo "[OK] $MODIFICHE modifica/e registrate in: $AUDIT_LOG"
fi
echo "     Snapshot aggiornato: $SNAPSHOT"
