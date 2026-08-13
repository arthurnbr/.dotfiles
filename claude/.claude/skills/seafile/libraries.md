# Bibliothèques Seafile — manifeste

Catalogue des libraries du drive (`drive.nobrega.fr`). Sert à l'agent pour savoir
quelles libs existent, où elles se synchronisent, et si elles sont présentes localement.

- **Scope `secrets`** : lib dédiée aux tokens/`.env`, synchronisée **partout**, exposée à `~/.secrets`.
- **Scope `content`** : synchronisées **à la demande** sous `~/Documents/<lib>`. Si une lib de
  contenu n'est pas synchronisée localement → **API d'abord** (lire/télécharger un fichier isolé
  via Seahub) ; ne synchroniser la lib entière que si Arthur le demande explicitement.

Les `repo-id` ci-dessous sont des indices (ils changent si une lib est recréée). Source
autoritaire : `GET /api2/repos/` — toujours résoudre par **nom**.

| Nom | Scope | Chemin local | repo-id | Chiffrée | Description |
|-----|-------|--------------|---------|----------|-------------|
| `secrets` | secrets | `~/.secrets` (→ `~/seafile-client/seafile/secrets`) | `3a166d7e-ca5b-45e5-927b-11df15ba57ae` | non | Tous les tokens/`.env` à la racine (`seafile.env`, `dolibarr.env`, …). Synchronisée sur toutes les machines. |
| `Ma bibliothèque` | content | `~/Documents/Ma bibliothèque` | `d308adb4-8695-4f6b-a4a8-79245ee3c7a7` | non | Divers, « le reste » (~35 Go). |
| `Pro` | content | `~/Documents/Pro` | `5943e2bf-624e-440e-baef-f87e6aa7b6cb` | non | Tout ce qui concerne les entreprises d'Arthur. |
| `Arthur` | content | `~/Documents/Arthur` | `c396c49a-d29c-465d-8db5-a39203216356` | non | Documents partagés avec ses parents. |
| `Gualter` | content | `~/Documents/Gualter` | `e17a6655-15b7-481a-976c-e047e95ae7b0` | non | Library d'un parent, partagée avec Arthur. |
| `Isabelle` | content | `~/Documents/Isabelle` | `4d5277a8-04dc-4742-99b8-f4dfdaa9a002` | non | Library d'un parent, partagée avec Arthur. |

## Vérifier la présence locale

```bash
seaf-cli list                        # libs actuellement synchronisées (autoritatif)
ls -d ~/Documents/<lib> 2>/dev/null  # présence rapide d'une lib de contenu
ls ~/.secrets 2>/dev/null            # secrets
```

Si une lib du manifeste est absente et qu'Arthur en a besoin : proposer de la synchroniser
(commande ci-dessous), ou récupérer un fichier isolé via l'API sans tout synchroniser.

## Synchroniser une lib de contenu (à la demande uniquement)

```bash
set -a; . ~/.secrets/seafile.env; set +a
H="Authorization: Token $SEAFILE_TOKEN"
u=$(curl -fsS -H "$H" "$SEAFILE_URL/api2/account/info/" | jq -r .email)
id=$(curl -fsS -H "$H" "$SEAFILE_URL/api2/repos/" | jq -r '[.[]|select(.name=="Pro")][0].id')
seaf-cli download -l "$id" -s "$SEAFILE_URL" -d "$HOME/Documents" -u "$u" -T "$SEAFILE_TOKEN"
```

Remplacer `Pro` par la lib voulue → checkout dans `~/Documents/<lib>`. Pour une lib chiffrée,
ajouter `-e <mot-de-passe-lib>` (aucune ne l'est actuellement).

## Accès API sans synchroniser (lib de contenu absente)

```bash
set -a; . ~/.secrets/seafile.env; set +a
H="Authorization: Token $SEAFILE_TOKEN"
id=$(curl -fsS -H "$H" "$SEAFILE_URL/api2/repos/" | jq -r '[.[]|select(.name=="Pro")][0].id')
curl -fsS -H "$H" "$SEAFILE_URL/api2/repos/$id/dir/?p=/"                    # lister un dossier
curl -fsS -H "$H" "$SEAFILE_URL/api2/repos/$id/file/?p=/chemin/f.pdf&reuse=1"  # lien de dl direct
```
