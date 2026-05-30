"""
=============================================================================
SKÚŠKA — Programovanie (varianta A) — IoT Backend: Prevodník jednotiek
=============================================================================
Tento súbor + frontend_b.html obsahujú spolu 5 ZÁMERNÝCH CHÝB.

ÚLOHA:
  1) Nájdite a OPRAVTE všetkých 5 chýb (4 v Pythone, 1 vo frontende).
     Pri každej oprave napíšte komentár:
        # OPRAVA #N: <vlastnými slovami prečo to bola chyba>

  2) DOPLŇTE endpoint /api/statistika podľa špecifikácie v zadaní.

  3) NASAĎTE aplikáciu na Azure App Service a odovzdajte URL.

Podrobné zadanie a hodnotenie sú v zadanie.docx.
=============================================================================
"""

from flask import Flask, request, jsonify, send_from_directory
import json
import os
import datetime

app = Flask(__name__)
SUBOR = "prevody.json"


def nacitaj_prevody():
    if not os.path.exists(SUBOR):
        return []
    with open(SUBOR, "r", encoding="utf-8") as f:
        return json.load(f)


def uloz_prevod(zaznam):
    prevody = nacitaj_prevody()
    prevody.append(zaznam)
    with open(SUBOR, "w", encoding="utf-8") as f:
        json.dump(prevody, f, ensure_ascii=False, indent=2)


@app.route("/api/prevod")
def prevod():
    hodnota = request.args.get("hodnota", type=float)
    typ = request.args.get("typ", "c_to_f")

    if hodnota is None:
        # OPRAVA #1: bez HTTP status kódu Flask vrátil 200, čo je nesprávne — chyba musí vrátiť 400
        return jsonify({"chyba": "Zadajte hodnotu!"}), 400

    if typ == "c_to_f":
        vysledok = (hodnota * 9 / 5) + 32
        popis = f"{hodnota} °C = {vysledok:.2f} °F"
    elif typ == "hpa_to_mmhg":
        # OPRAVA #2: vzorec bol obrátený — 1 hPa = 0.75006 mmHg, teda treba násobiť, nie deliť
        vysledok = hodnota * 0.75006
        popis = f"{hodnota} hPa = {vysledok:.2f} mmHg"
    elif typ == "ms_to_kmh":
        vysledok = hodnota * 3.6
        popis = f"{hodnota} m/s = {vysledok:.2f} km/h"
    else:
        # OPRAVA #3: neznámy typ spôsobil NameError (vysledok/popis nedefinované) a HTTP 500 — treba vrátiť 400
        return jsonify({"chyba": f"Neznámy typ prevodu: {typ}"}), 400

    zaznam = {
        "hodnota": hodnota,
        "typ": typ,
        "vysledok": round(vysledok, 2),
        "popis": popis,
        # OPRAVA #4: datetime objekt nie je JSON serializovateľný — treba ho previesť na string cez isoformat()
        "cas": datetime.datetime.now().isoformat()
    }
    uloz_prevod(zaznam)

    return jsonify(zaznam)


@app.route("/api/historia-prevodov")
def historia_prevodov():
    return jsonify(nacitaj_prevody())


# TODO: Dopíšte endpoint /api/statistika podľa špecifikácie v zadaní.


@app.route("/")
def index():
    return send_from_directory(".", "frontend_a.html")


@app.route("/historia")
def historia_page():
    return send_from_directory(".", "frontend_b.html")


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8000, debug=True)