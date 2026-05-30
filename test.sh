#!/bin/bash
# =============================================================================
# Automatický testovací skript pre variantu A (Flask backend) — opravy chýb
# =============================================================================
# POUŽITIE:
#   1) Skopírujte študentove app.py + frontend_b.html do nového adresára
#   2) Skopírujte aj test.sh + frontend_a.html + requirements.txt do toho adresára
#   3) Spustite:   bash test.sh
#
# Skript otestuje 4 backend chyby + endpoint /api/statistika.
# Bug #5 (frontend_b.html) sa testuje vizuálne — skript pripomenie nakonci.
# =============================================================================

set -u

rm -f prevody.json

if [ ! -f "app.py" ]; then
    echo "❌ Nenašiel som app.py v aktuálnom adresári."
    exit 1
fi

echo "Spúšťam Flask server..."
python3 app.py > server.log 2>&1 &
SERVER_PID=$!

cleanup() {
    kill $SERVER_PID 2>/dev/null || true
    wait $SERVER_PID 2>/dev/null || true
    rm -f prevody.json server.log
}
trap cleanup EXIT

sleep 2

if ! kill -0 $SERVER_PID 2>/dev/null; then
    echo "❌ Server sa nespustil. Pozri server.log:"
    cat server.log
    exit 1
fi

BASE="http://localhost:8000"
OK=0
FAIL=0
BODY=0

check() {
    local label="$1"
    local expected="$2"
    local actual="$3"
    local body="$4"
    if [ "$expected" = "$actual" ]; then
        echo "  ✅ $label  (+${body} b)"
        OK=$((OK + 1))
        BODY=$(awk "BEGIN {print $BODY + $body}")
    else
        echo "  ❌ $label  (očakávané: '$expected', dostal: '$actual')"
        FAIL=$((FAIL + 1))
    fi
}

echo ""
echo "=========================================="
echo "  TESTY OPRÁV CHÝB (po 1.0 b za opravu)"
echo "=========================================="

STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$BASE/api/prevod?typ=c_to_f")
check "CHYBA #1: HTTP 400 keď chýba hodnota" "400" "$STATUS" "1.0"

RES=$(curl -s "$BASE/api/prevod?hodnota=1013&typ=hpa_to_mmhg" \
    | python3 -c "import sys,json; print(json.load(sys.stdin).get('vysledok','?'))" 2>/dev/null || echo "?")
check "CHYBA #2: hPa→mmHg vzorec (1013 → 759.81)" "759.81" "$RES" "1.0"

STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$BASE/api/prevod?hodnota=10&typ=neexistujuci_typ")
check "CHYBA #3: neznámy typ → 400 (nie 500)" "400" "$STATUS" "1.0"

CAS_TYP=$(curl -s "$BASE/api/prevod?hodnota=20&typ=c_to_f" \
    | python3 -c "import sys,json; print(type(json.load(sys.stdin).get('cas','')).__name__)" 2>/dev/null || echo "?")
check "CHYBA #4: 'cas' je serializovateľný string" "str" "$CAS_TYP" "1.0"

echo ""
echo "=========================================="
echo "  ENDPOINT /api/statistika (max 1.5 b)"
echo "=========================================="

rm -f prevody.json
curl -s "$BASE/api/prevod?hodnota=10&typ=c_to_f" > /dev/null
curl -s "$BASE/api/prevod?hodnota=20&typ=c_to_f" > /dev/null
curl -s "$BASE/api/prevod?hodnota=30&typ=c_to_f" > /dev/null
curl -s "$BASE/api/prevod?hodnota=1010&typ=hpa_to_mmhg" > /dev/null
curl -s "$BASE/api/prevod?hodnota=1020&typ=hpa_to_mmhg" > /dev/null

STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$BASE/api/statistika")
check "Endpoint existuje (HTTP 200)" "200" "$STATUS" "0.25"

STAT=$(curl -s "$BASE/api/statistika")

POCET_CF=$(echo "$STAT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('c_to_f',{}).get('pocet','?'))" 2>/dev/null || echo "?")
check "c_to_f.pocet = 3" "3" "$POCET_CF" "0.25"

PRIEMER_CF=$(echo "$STAT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('c_to_f',{}).get('priemer','?'))" 2>/dev/null || echo "?")
check "c_to_f.priemer = 20.0" "20.0" "$PRIEMER_CF" "0.25"

MIN_CF=$(echo "$STAT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('c_to_f',{}).get('min','?'))" 2>/dev/null || echo "?")
check "c_to_f.min = 10.0" "10.0" "$MIN_CF" "0.125"

MAX_CF=$(echo "$STAT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('c_to_f',{}).get('max','?'))" 2>/dev/null || echo "?")
check "c_to_f.max = 30.0" "30.0" "$MAX_CF" "0.125"

POCET_MS=$(echo "$STAT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('ms_to_kmh',{}).get('pocet','?'))" 2>/dev/null || echo "?")
check "ms_to_kmh.pocet = 0" "0" "$POCET_MS" "0.5"

echo ""
echo "=========================================="
echo "  AUTOMATICKÝ VÝSLEDOK"
echo "=========================================="
echo "  Úspešné: $OK   Neúspešné: $FAIL"
echo "  Body z automatu: $BODY / 5.5 b"
echo ""
echo "=========================================="
echo "  MANUÁLNA KONTROLA (zostávajúce body)"
echo "=========================================="
echo "  • Komentáre k 5 opravám:        5 × 0.5 b = 2.5 b"
echo "  • CHYBA #5 vo frontend_b.html (poradie <td>):  1.0 b"
echo "  • Funkčné nasadenie na Azure (otvoriť URL):    1.0 b"
echo ""
echo "  CELKOVO MOŽNÝCH: 10.0 b"
echo "=========================================="
