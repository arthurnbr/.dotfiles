---
name: seafile
description: >-
  Drive personnel d'Arthur, hébergé sur Seafile (serveur drive.nobrega.fr) : lire/écrire/
  chercher/ranger des fichiers, et opérations serveur (lister des bibliothèques, créer un
  lien de partage/téléchargement, upload distant) via l'API web Seahub. À UTILISER dès
  qu'Arthur parle de "mon drive", "ma bibliothèque", "mes fichiers", "le cloud", "Seafile",
  veut retrouver/déposer/partager un document ou synchroniser un fichier entre ses machines —
  même sans dire "Seafile". Deux accès : (1) le dossier synchronisé local (fichiers), (2)
  l'API web avec le token dans ~/.secrets/seafile.env.
---

# Seafile — drive personnel (drive.nobrega.fr)

Deux façons d'agir, complémentaires :

1. **Dossier synchronisé local** (le plus simple) — un client `seaf-daemon` réplique la
   library sur disque. Opérations de fichiers normales, pas de token.
2. **API web Seahub** — pour ce que le filesystem ne fait pas : liens de partage, upload
   vers une autre machine non synchronisée, lister les libraries côté serveur. Token requis.

## 1) Dossier synchronisé (fichiers)

- Racine du drive : `~/seafile-client/seafile/Ma bibliothèque`
- Interne, NE PAS toucher : `~/seafile-client/seafile-data`, `~/.ccnet`.
- Démon : service utilisateur `seafile.service` (`seaf-daemon`). Vérifier qu'il tourne :
  `systemctl --user is-active seafile.service` et `pgrep -a seaf-daemon`.

```bash
DRIVE="$HOME/seafile-client/seafile/Ma bibliothèque"
ls -la "$DRIVE"
find "$DRIVE" -iname '*facture*2026*'
mkdir -p "$DRIVE/Documents/2026" && cp /chemin/source.pdf "$DRIVE/Documents/2026/"
```

Avec les outils du harness : `read`/`write`/`find`/`search` directement sous `$DRIVE`.

> Le nom de library peut varier ; si `Ma bibliothèque` n'existe pas, lister
> `~/seafile-client/seafile/` et prendre la bonne.

**Sync** : écrire pose le fichier sur disque tout de suite ; l'upload serveur + propagation
aux autres PC prennent quelques secondes. Si le démon est arrêté, les changements restent
locaux. Éditer le même fichier sur deux machines crée `... (SFConflict <host> <date>).<ext>` —
en cas de doute, repérer ces fichiers et demander à Arthur lequel garder, ne jamais en
supprimer un sans confirmation. Supprimer sous `$DRIVE` supprime côté serveur (corbeille
récupérable un temps) ; confirmer avant suppression de masse.

## 2) API web Seahub (token)

- Base : `https://drive.nobrega.fr`
- **Token** : fichier **`~/.secrets/seafile.env`** (variables `SEAFILE_URL`, `SEAFILE_TOKEN`),
  synchronisé entre machines via Seafile. Format : `skill://seafile/seafile.env.example`.
- Auth : header **`Authorization: Token <token>`**. Ne JAMAIS recopier le token en clair.
- **Si `~/.secrets/seafile.env` est absent** : NE PAS deviner le token. Demander à Arthur de
  le mettre en place — soit en synchronisant la library des secrets via le client Seafile
  (crée `~/.secrets`), soit en créant le fichier avec `SEAFILE_URL` + `SEAFILE_TOKEN` (le
  token Seahub se génère via `POST /api2/auth-token/` avec identifiants, ou dans l'UI).

```bash
set -a; . ~/.secrets/seafile.env; set +a
H="Authorization: Token $SEAFILE_TOKEN"

# Compte / quota
curl -s -H "$H" "$SEAFILE_URL/api2/account/info/"
# Lister les bibliothèques (récupère l'id de repo)
curl -s -H "$H" "$SEAFILE_URL/api2/repos/"
# Lister un dossier d'une library
curl -s -H "$H" "$SEAFILE_URL/api2/repos/<repo-id>/dir/?p=/Documents"
# Lien de téléchargement direct d'un fichier
curl -s -H "$H" "$SEAFILE_URL/api2/repos/<repo-id>/file/?p=/chemin/f.pdf&reuse=1"
# Créer un lien de partage public
curl -s -X POST -H "$H" "$SEAFILE_URL/api/v2.1/share-links/" \
  -d "repo_id=<repo-id>&path=/chemin/f.pdf"
# Upload : obtenir l'URL d'upload puis POST multipart
UP=$(curl -s -H "$H" "$SEAFILE_URL/api2/repos/<repo-id>/upload-link/" | tr -d '"')
curl -s -H "$H" -F "file=@/chemin/local.pdf" -F "parent_dir=/Documents" "$UP"
```

### Library connue

- `Ma bibliothèque` → repo-id `d308adb4-8695-4f6b-a4a8-79245ee3c7a7` (rw). Vérifier via
  `GET /api2/repos/` si besoin (les ids peuvent changer si la library est recréée).

## Quand utiliser quoi

- Fichier déjà synchronisé localement → **dossier** (rapide, hors-ligne).
- Lien de partage, machine non synchronisée, action serveur → **API**.

## Sécurité

Le token donne accès en lecture/écriture à tout le drive d'Arthur (compte staff). Lectures :
libres. Écritures/suppressions/partages : OK pour le flux normal ; confirmer avant
suppression de masse ou partage public de documents sensibles.
