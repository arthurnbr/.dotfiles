# nvim — LazyVim, accordé pour eduvia

Une config Neovim posée sur **LazyVim** + extras pour le stack eduvia
(Rails 8 / Ruby 4, Nuxt 3 / Vue 3 / TypeScript / Tailwind / ESLint).
Stow-friendly, donc partagée entre toutes mes machines via le repo
`.dotfiles`.

---

## Démarrage

```sh
cd ~/.dotfiles
stow nvim         # crée le symlink ~/.config/nvim → ~/.dotfiles/nvim/.config/nvim
nvim              # 1er lancement : lazy.nvim clone tout (~30 s)
```

`setup-arch.sh` (et `setup.sh` sur macOS) installe déjà `neovim`,
`ripgrep`, `fd`, `lazygit` et `tree-sitter-cli`, et stow le package.

À la 1re ouverture, lance `:Mason` puis `:LazyHealth` si quelque chose
se plaint — Mason récupèrera automatiquement `ruby-lsp`, `vue-language-server`,
`typescript-language-server`, `tailwindcss-language-server`,
`eslint-lsp`, `prettier`.

---

## Les 4 trucs que je voulais absolument

### 1. Fuzzy search (le truc le plus utile, à savoir par cœur)

> Le picker est **`snacks.picker`** (LazyVim 13+, plus rapide que Telescope).

| Raccourci         | Effet                                                 |
|-------------------|-------------------------------------------------------|
| `<space><space>`  | **Smart find** — fichiers du projet (root-aware)     |
| `<space>ff`       | Find files (alias)                                    |
| `<space>/`        | Live grep — chercher du texte dans le projet         |
| `<space>fr`       | Recent files                                          |
| `<space>fb`       | Buffers ouverts                                       |
| `<space>fp`       | Switch project (jump entre repos)                     |
| `<space>fy` / `fY`| Copier le path relatif courant (avec/sans `:line`)    |
| `<space>sg`       | Grep (alias)                                          |
| `<space>sh`       | Help tags                                             |
| `<space>sk`       | Keymaps (re-trouver un raccourci si oublié)           |
| `<space>sd`       | Diagnostics (toutes les erreurs LSP du projet)        |
| `<space>sw`       | Grep le mot sous le curseur                           |
| `<space>"`        | Registres                                             |

Dans le picker : tape pour filtrer, `<Tab>` multi-sélection, `<C-q>` envoie
les résultats dans la quickfix list, `<C-v>` ouvre en vsplit, `<C-x>` en
hsplit.

### 2. `gd` qui marche

Configuré pour tout le stack eduvia via Mason :

| Stack      | LSP                                                  |
|------------|------------------------------------------------------|
| Ruby/Rails | `ruby-lsp` (omakase), formatage `standardrb`         |
| Vue        | `vue-language-server` (Volar)                        |
| TypeScript | `typescript-language-server` (avec @vue/typescript-plugin) |
| Tailwind   | `tailwindcss-language-server` (autocomplete classes) |
| ESLint     | `eslint-lsp` (LSP, pas le CLI)                       |
| JSON       | `jsonls`                                             |
| Markdown   | `marksman`                                           |

| Raccourci         | Effet                                                 |
|-------------------|-------------------------------------------------------|
| `gd`              | Aller à la définition                                 |
| `gD`              | Déclaration                                           |
| `gr`              | Toutes les références                                 |
| `gI`              | Implémentations                                       |
| `gy`              | Type definition                                       |
| `K`               | Hover doc (signature, type, JSDoc)                    |
| `<space>cr`       | Renommer le symbol partout                            |
| `<space>ca`       | Code action (quickfix, organize imports, …)           |
| `<space>cd`       | Diagnostic ligne (pretty popup)                       |
| `[d` / `]d`       | Diagnostic précédent / suivant                        |
| `<space>gd`       | Définition mais en **vsplit** (custom)                |

Si `gd` n'a qu'**un** résultat → saut direct. Plusieurs → picker pour
choisir.

### 3. Inverse de `gd` (revenir à la position précédente)

Le **jumplist** Vim — c'est la mémoire de tous tes sauts (gd, search,
buffer switch, etc.).

| Raccourci         | Effet                                                 |
|-------------------|-------------------------------------------------------|
| `<C-o>`           | **← retour** à la position précédente                |
| `<C-i>`           | **→ aller** à la suivante                             |
| `<space>bb`       | Alias mnémonique de `<C-o>` (custom)                  |
| `<space>bf`       | Alias mnémonique de `<C-i>` (custom)                  |
| `:jumps`          | Voir tout le jumplist                                 |

À retenir : `gd` puis `<C-o>` = aller-retour à la définition. Marche
aussi à travers les fichiers.

> Bonus changelist (édition uniquement, pas les sauts de lecture) :
> `g;` (précédent change), `g,` (suivant change).

### 4. Téléportation de curseur

C'est **`flash.nvim`** (déjà default LazyVim, ici tweaké pour le rainbow).

| Raccourci                  | Effet                                                 |
|----------------------------|-------------------------------------------------------|
| `s` (en normal/visual)     | Tape 2 chars → **labels** sur tous les matchs visibles, tape la lettre → téléporté |
| `S`                        | Treesitter-aware (saute à un nœud entier : fonction, tag JSX, bloc Ruby…) |
| `r` (en operator pending)  | Remote flash — `yr<motion>` yank distance sans bouger |
| `R` (en operator)          | Treesitter remote                                     |
| `<C-s>` (en search `/`)    | Convertit la recherche en flash labels                |

**Le pattern à apprendre** : `s` + 2 chars + 1 char-label → curseur
téléporté en 4 frappes, n'importe où dans la fenêtre. Plus rapide que
n'importe quel `f`/`t`/`/`.

---

## Custom keymaps (en + de LazyVim)

| Raccourci    | Effet                                                          |
|--------------|----------------------------------------------------------------|
| `<space>fy`  | Copier le path relatif (`backend/app/models/user.rb`)         |
| `<space>fY`  | Copier le path:line (`backend/app/models/user.rb:42`)         |
| `<space>gd`  | LSP definition mais en vsplit                                  |
| `<space>bb`  | `<C-o>` (jump back)                                            |
| `<space>bf`  | `<C-i>` (jump forward)                                         |
| `<space>;`   | Re-run la dernière commande `:`                                |
| `<space>tt`  | Toggle terminal (snacks)                                       |

`<space>fy/fY` est précieux pour coller des paths dans Claude Code (style
`look at backend/app/models/user.rb:42`).

---

## Workflow type sur eduvia

```sh
cd ~/Documents/eduvia
nvim                            # lazy.nvim s'auto-init au 1er coup
```

1. `<space><space>` → trouver `app/models/employee.rb`
2. `gd` sur un appel `Employee.find_by` → saut dans `lib/...`
3. `<C-o>` → retour
4. `s` + `de` → saute n'importe où à un mot commençant par `de` dans la fenêtre
5. `<space>/` → grep `current_user` à travers le repo
6. `<space>cr` → renommer une méthode partout (LSP)
7. `<space>ca` sur une erreur ESLint → quickfix auto

Lazygit : `<space>gg` ouvre lazygit en floating dans nvim. Diff/commit
sans quitter l'éditeur.

Neo-tree (file explorer) : `<space>e`. `a` pour ajouter un fichier, `d`
pour delete, `r` rename.

---

## Ce qui est désactivé volontairement

- **News popup LazyVim** au démarrage.
- **Animations de scroll** snacks (vu que tu as tmux qui gère déjà ça).
- **Inlay hints** par défaut (c'est bruyant en Vue/TS) — `<space>uh`
  pour les toggle.

---

## Mainenance

| Commande       | Effet                                                       |
|----------------|-------------------------------------------------------------|
| `:Lazy`        | UI plugins (sync, update, profile, etc.)                    |
| `:LazyHealth`  | Vérifie que tous les plugins sont OK                        |
| `:Mason`       | UI Mason — installer/mettre à jour les LSPs/formatters      |
| `:checkhealth` | Diagnostique global (treesitter, providers, etc.)           |

Le `lazy-lock.json` est dans le repo dotfiles → versions plugins
identiques sur toutes les machines. Pour bumper :

```sh
nvim +"Lazy! sync" +qa
cd ~/.dotfiles && git add nvim/.config/nvim/lazy-lock.json && git commit -m "nvim: bump plugins"
```

---

## Si je dois retoucher la config

```
~/.dotfiles/nvim/.config/nvim/
├── init.lua                    ← bootstrap (ne pas toucher)
├── lazyvim.json                ← extras LazyVim activés
├── lazy-lock.json              ← versions pinnées
├── lua/
│   ├── config/
│   │   ├── lazy.lua            ← lazy.nvim setup
│   │   ├── options.lua         ← options vim (relativenumber, scrolloff, …)
│   │   ├── keymaps.lua         ← keymaps custom
│   │   └── autocmds.lua        ← autocmds custom
│   └── plugins/
│       ├── colorscheme.lua     ← tokyonight (matche tmux/ghostty)
│       ├── eduvia.lua          ← tweaks projet (standardrb, flash labels, snacks)
│       ├── theme-omarchy.lua   ← hot-reload Omarchy si présent (optionnel)
│       ├── all-themes.lua      ← thèmes lazy-loaded au cas où
│       ├── disable-news-alert.lua
│       └── snacks-animated-scrolling-off.lua
```

Pour ajouter un plugin : crée un fichier dans `lua/plugins/` avec
`return { "owner/plugin" }`. Lazy s'occupe du reste.
