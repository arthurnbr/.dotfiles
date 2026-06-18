---
name: dolibarr
description: >-
  Interagir avec l'ERP Dolibarr auto-hébergé de NS. CAPITAL (https://erp.nobrega.fr)
  via son API REST : devis (proposals), factures (invoices), tiers/clients/fournisseurs
  (thirdparties), contacts, paiements, banque, comptabilité + export FEC, documents/PDF,
  gestion des modules. À UTILISER dès que l'utilisateur parle de Dolibarr, "mon ERP",
  un devis, une facture, un client/fournisseur, la compta, le FEC, l'expert-comptable,
  ou veut lire/créer/modifier des données métier sur erp.nobrega.fr — même sans citer
  "Dolibarr" explicitement. La clé API (DOLAPIKEY) est dans le fichier credentials.env
  de ce skill : lis skill://dolibarr/credentials.env (ou le chemin local équivalent)
  avant tout appel.
---

# Dolibarr ERP — NS. CAPITAL (erp.nobrega.fr)

Pilotage de l'ERP par l'**API REST Dolibarr** (Restler, swagger 2.0).

## Connexion

- Base URL : `https://erp.nobrega.fr/api/index.php`
- Auth : header HTTP **`DOLAPIKEY: <clé>`** (préféré) ou query `?DOLAPIKEY=<clé>`.
- La clé est dans **`skill://dolibarr/credentials.env`** (variables `DOLIBARR_URL`, `DOLAPIKEY`).
  Lis ce fichier d'abord ; ne JAMAIS recopier la clé en clair dans un message ou un commit.
- Explorer / swagger : `GET /explorer/swagger.json?DOLAPIKEY=<clé>` (la liste complète des
  endpoints n'apparaît qu'authentifié).

⚠️ La clé appartient à l'utilisateur **SuperAdmin (admin, id=1)** → tous les droits, y compris
écriture et suppression. C'est l'instance **de production**. Confirmer avec l'utilisateur avant
tout `DELETE`, mise à jour de masse, ou changement de config (`/setup/...`, modules).

## État de l'instance (vérifié 2026-06)

- Dolibarr **23.0.2**.
- Société : **NS. CAPITAL**, SIREN `993088442`, SIRET `99308844200013`,
  TVA `FR63993088442`, Sartrouville (FR).
- Modules API actifs (tags) : `accountancy, bankaccounts, contacts, documents,
  emailtemplates, invoices, objectlinks, paiements, proposals, setup, status,
  thirdparties, users, webhook, login`.

## Exemples

curl :
```bash
KEY=$(grep -E '^DOLAPIKEY=' "$(dirname "$0")/credentials.env" | cut -d= -f2)
curl -s -H "DOLAPIKEY: $KEY" "https://erp.nobrega.fr/api/index.php/status"
# Lister 5 clients
curl -s -H "DOLAPIKEY: $KEY" "https://erp.nobrega.fr/api/index.php/thirdparties?limit=5"
# Créer une facture (brouillon) -> renvoie l'id
curl -s -X POST -H "DOLAPIKEY: $KEY" -H "Content-Type: application/json" \
  -d '{"socid":123,"type":0,"lines":[{"desc":"Presta","subprice":500,"qty":1,"tva_tx":20}]}' \
  "https://erp.nobrega.fr/api/index.php/invoices"
```

python :
```python
import json, urllib.request
B = "https://erp.nobrega.fr/api/index.php"
K = open(__file__.rsplit("/",1)[0] + "/credentials.env").read()
K = [l.split("=",1)[1].strip() for l in K.splitlines() if l.startswith("DOLAPIKEY=")][0]
def call(method, path, body=None):
    data = json.dumps(body).encode() if body is not None else None
    r = urllib.request.Request(B + path, data=data, method=method,
        headers={"DOLAPIKEY": K, "Content-Type": "application/json", "Accept": "application/json"})
    return json.load(urllib.request.urlopen(r, timeout=30))
print(call("GET", "/thirdparties?limit=3"))
```

## Carte des endpoints utiles

- **thirdparties** (tiers : clients & fournisseurs) : `GET/POST /thirdparties`,
  `GET /thirdparties/{id}`, `GET /thirdparties/email/{email}`, `PUT /thirdparties/{id}`,
  bank accounts, catégories, encours (`outstandinginvoices`).
- **proposals** (= **devis**) : `POST /proposals`, `POST /proposals/{id}/lines`,
  `POST /proposals/{id}/validate`, `/close`, `/setinvoiced`, `/settodraft`.
- **invoices** (= **factures clients**) : `POST /invoices`, `POST /invoices/{id}/lines`,
  `POST /invoices/{id}/validate`, `/settopaid` `/settounpaid` `/settodraft`,
  `POST /invoices/{id}/payments`, `POST /invoices/createfromorder/{orderid}`,
  `GET /invoices/ref/{ref}`.
- **paiements** : `GET/PUT/DELETE /paiements/{id}`.
- **bankaccounts** : comptes, lignes, soldes, virements.
- **documents** : `PUT /documents/builddoc` (génère le PDF — voir Factur-X ci-dessous),
  `POST /documents/upload`, `GET /documents/download`, `GET /documents`.
- **accountancy** : `GET /accountancy/exportdata` — **export pour l'expert-comptable**.
- **setup** : `GET /setup/company`, `GET /setup/modules`,
  `PUT /setup/modules/{modulename}/enable|disable` (activer un module via API),
  `GET /setup/dictionary/...` (TVA, pays, etc.), extrafields.
- **users**, **contacts**, **emailtemplates**, **objectlinks**, **webhook**.

Pagination/filtre : `?limit=&page=&sortfield=&sortorder=` et `sqlfilters`, ex.
`sqlfilters=(t.datec:>=:'2026-01-01')`. `properties=` restreint les champs renvoyés.

## Workflow devis → facture (par API)

1. `POST /thirdparties` (si le client n'existe pas) → `socid`.
2. `POST /proposals` `{socid,...}` puis `POST /proposals/{id}/lines` → devis brouillon.
3. `POST /proposals/{id}/validate` → devis validé (numéroté).
4. Accepté : `POST /proposals/{id}/setinvoiced` puis créer la facture
   (`POST /invoices` ou depuis la proposition).
5. `POST /invoices/{id}/validate` → facture validée + numérotée.
6. `PUT /documents/builddoc` `{modulepart:"facture", original_file:"<ref>/<ref>.pdf", doctemplate:"<modele>", langcode:"fr_FR"}` → génère le PDF.
7. Paiement : `POST /invoices/{id}/payments` puis `POST /invoices/{id}/settopaid`.

## Comptabilité / FEC (expert-comptable)

`GET /accountancy/exportdata?period=fiscalyear&format=1000` → **FEC** (format `1000`,
`1010`=FEC2, `1`=CSV configurable). `period` ∈ lastmonth, currentmonth, last3months,
last6months, currentyear, lastyear, fiscalyear, lastfiscalyear, custom (+`date_min`/`date_max`).
Clôture NS. CAPITAL : 31/12.

## ⚠️ Facturation électronique (module einvoicing) — PAS via l'API REST

Le module `einvoicing` (connexion à la Plateforme Agréée, ex-PDP) **n'expose aucun
endpoint REST**. Il fonctionne par **hooks + cron** :
- **Génération Factur-X** : automatique via le hook `afterPDFCreation` quand le PDF de la
  facture est construit (donc `PUT /documents/builddoc` déclenche la création Factur-X).
- **Émission vers la PA** : action UI / hook `doActions` sur la facture — **non pilotable
  en REST direct**.
- **Réception + statuts du cycle de vie** : tâche cron `EInvoicingDocumentSync`
  (`Document::cronSyncFlows`, horaire, **créée désactivée** → à activer dans Jobs planifiés).

Donc : créer/valider/numéroter les factures + générer le PDF/Factur-X = **API OK** ;
l'échange réel avec la PA (envoi/réception) = **UI + cron**, pas l'API.

## Sécurité

Production + clé admin. Lectures : libres. Écritures (`POST/PUT`) : OK pour le flux métier
normal. Destructif (`DELETE`, `merge`, mise à jour de masse, `/setup`, (dés)activation de
modules) : **demander confirmation** d'abord.
