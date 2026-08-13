---
name: seafile
description: >-
  Drive personnel d'Arthur, hébergé sur Seafile (serveur drive.nobrega.fr) : lire/écrire/
  chercher/ranger des fichiers, et opérations serveur (lister des bibliothèques, créer un
  lien de partage/téléchargement, upload distant) via l'API web Seahub. À UTILISER dès
  qu'Arthur parle de "mon drive", "ma bibliothèque", "mes fichiers", "le cloud", "Seafile",
  veut retrouver/déposer/partager un document ou synchroniser un fichier entre ses machines —
  même sans dire "Seafile". Le token vit dans ~/.secrets/seafile.env (lib `secrets`
  synchronisée partout) ; les libs de contenu se synchronisent à la demande sous ~/Documents/.
  Catalogue des libs : skill://seafile/libraries.md.
---

# Seafile — drive personnel (drive.nobrega.fr)

Deux accès complémentaires :

1. **Dossier synchronisé local** (`seaf-daemon`) — fichiers sur disque. Les **secrets** sont
   synchronisés partout (`~/.secrets`) ; les libs de **contenu** sont synchronisées **à la
   demande** sous `~/Documents/<lib>`.
2. **API web Seahub** (token) — lister/lire/télécharger/partager/upload sans synchroniser.
   Voie **par défaut** pour une lib de contenu **non** synchronisée localement.

Le **catalogue des bibliothèques** (noms, repo-id, chemins locaux, scope, description) est dans
**`skill://seafile/libraries.md`** — le lire pour savoir ce qui existe et où.

## Modèle

- **`secrets`** — petite lib dédiée, tous les tokens/`.env` à sa racine. Synchronisée sur
  **toutes** les machines, exposée à **`~/.secrets`** (symlink → `~/seafile-client/seafile/secrets`).
  C'est de là que vient `~/.secrets/seafile.env`.
- **Libs de contenu** (`Ma bibliothèque`, `Pro`, `Arthur`, `Gualter`, `Isabelle`) —
  synchronisées **à la demande** sous **`~/Documents/<lib>`**, seulement là où Arthur le veut.
- Interne au client, NE PAS toucher : `~/seafile-client/seafile-data`, `~/.ccnet`.
- Démon : `seaf-cli@<user>.service` (système) ou `seaf-cli start`. État :
  `seaf-cli list` (libs synchronisées), `pgrep -a seaf-daemon`.

## 1) Dossier synchronisé (fichiers)

Vérifier ce qui est présent, puis agir :

```bash
seaf-cli list                          # libs synchronisées localement (autoritatif)
DRIVE="$HOME/Documents/Pro"            # une lib de contenu, si synchronisée
ls -la "$DRIVE" 2>/dev/null && find "$DRIVE" -iname '*facture*2026*'
```

Avec les outils du harness : `read`/`write`/`find`/`search` directement sous `~/Documents/<lib>`
et sous `~/.secrets`.

**Lib de contenu absente** → deux options (commandes exactes dans `libraries.md`) :

- **API d'abord** (défaut) : lire/télécharger un fichier isolé sans rien synchroniser.
- **Sync complète** (seulement si Arthur le demande) :
  `seaf-cli download -l <repo-id> -s "$SEAFILE_URL" -d "$HOME/Documents" -u <compte> -T "$SEAFILE_TOKEN"`
  → checkout dans `~/Documents/<lib>`. Résoudre `<repo-id>` par **nom** via `GET /api2/repos/`.

**Sync** : écrire pose le fichier tout de suite ; upload + propagation aux autres PC en quelques
secondes. Démon arrêté → changements locaux seulement. Éditer le même fichier sur deux machines
crée `... (SFConflict <host> <date>).<ext>` — repérer, demander à Arthur lequel garder, ne jamais
en supprimer un sans confirmation. Supprimer sous une lib supprime côté serveur (corbeille
récupérable un temps) ; confirmer avant suppression de masse.

## 2) API web Seahub (token)

- Base : `https://drive.nobrega.fr`
- **Token** : `~/.secrets/seafile.env` (`SEAFILE_URL`, `SEAFILE_TOKEN`), synchronisé via la lib
  `secrets`. Format : `skill://seafile/seafile.env.example`.
- Auth : header **`Authorization: Token <token>`**. Ne JAMAIS recopier le token en clair.
- **Si `~/.secrets/seafile.env` est absent** (machine pas encore amorcée) : NE PAS deviner le
  token. Amorcer une fois hors-bande puis relancer le setup —
  `SEAFILE_URL=https://drive.nobrega.fr SEAFILE_TOKEN=<token> ./setup-arch.sh` (ou `./setup.sh`).
  Le `<token>` se génère via `POST /api2/auth-token/` (identifiants) ou dans l'UI Seahub.

```bash
set -a; . ~/.secrets/seafile.env; set +a
H="Authorization: Token $SEAFILE_TOKEN"

curl -s -H "$H" "$SEAFILE_URL/api2/account/info/"                          # compte / quota
curl -s -H "$H" "$SEAFILE_URL/api2/repos/"                                 # lister les libs (+ id)
curl -s -H "$H" "$SEAFILE_URL/api2/repos/<repo-id>/dir/?p=/Documents"      # lister un dossier
curl -s -H "$H" "$SEAFILE_URL/api2/repos/<repo-id>/file/?p=/f.pdf&reuse=1" # dl direct
curl -s -X POST -H "$H" "$SEAFILE_URL/api/v2.1/share-links/" \
  -d "repo_id=<repo-id>&path=/f.pdf"                                       # lien de partage
UP=$(curl -s -H "$H" "$SEAFILE_URL/api2/repos/<repo-id>/upload-link/" | tr -d '"')
curl -s -H "$H" -F "file=@/chemin/local.pdf" -F "parent_dir=/" "$UP"       # upload
```

## Quand utiliser quoi

- Fichier dans une lib déjà synchronisée (`~/Documents/<lib>` ou `~/.secrets`) → **dossier**.
- Lib de contenu non synchronisée, lien de partage, action serveur → **API**.
- Synchroniser une lib entière → seulement si Arthur le demande (voir `libraries.md`).

## Sécurité

Le token donne accès en lecture/écriture à tout le drive d'Arthur (compte staff). Lectures :
libres. Écritures/suppressions/partages : OK pour le flux normal ; confirmer avant suppression
de masse ou partage public de documents sensibles. Ne JAMAIS partager publiquement la lib `secrets`.
