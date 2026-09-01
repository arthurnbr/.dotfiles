-- Auto-complétion IA via cpamc (CLIProxyAPI @ ai.eduvia.dev, Claude Opus 4.8).
--
-- Déclenchement MANUEL uniquement : <A-y> en mode insertion demande une
-- complétion, puis on l'accepte depuis le menu blink (<CR>/<Tab>) comme
-- n'importe quelle autre source. On ne branche PAS minuet sur l'auto-complétion
-- car Opus a ~3 s de latence et puise dans le quota Claude Max partagé
-- (fenêtres 5h/7j) — le déclencher à chaque frappe serait lent et coûteux.
--
-- Copilot officiel (copilot.lua) est verrouillé sur GitHub et ne peut pas taper
-- sur un endpoint custom : minuet est le seul frontend d'autocomplétion qui
-- accepte cpamc.

-- Lit CPAMC_API_KEY sans la fuiter dans l'environnement global.
-- Source de vérité : ~/.secrets/cpamc.env (Seafile, toutes machines) ;
-- repli sur l'env de l'agent OMP.
local key_cache
local function cpamc_api_key()
  if key_cache then
    return key_cache
  end
  for _, file in ipairs({
    vim.fn.expand("~/.secrets/cpamc.env"),
    vim.fn.expand("~/.omp/agent/.env"),
  }) do
    local fd = io.open(file, "r")
    if fd then
      for line in fd:lines() do
        local v = line:match("^%s*CPAMC_API_KEY%s*=%s*(.+)%s*$")
        if v then
          fd:close()
          v = v:gsub('^"(.*)"$', "%1"):gsub("^'(.*)'$", "%1")
          key_cache = v
          return v
        end
      end
      fd:close()
    end
  end
  vim.notify("minuet: CPAMC_API_KEY introuvable (~/.secrets/cpamc.env)", vim.log.levels.ERROR)
  return ""
end

return {
  {
    "milanglacier/minuet-ai.nvim",
    event = "InsertEnter",
    opts = {
      provider = "claude",
      n_completions = 2, -- moins de requêtes parallèles => moins de quota/latence
      context_window = 8000, -- contexte réduit pour garder Opus réactif
      request_timeout = 5, -- le premier token d'Opus dépasse souvent 3 s
      throttle = 1500,
      debounce = 600,
      notify = "warn",
      provider_options = {
        claude = {
          model = "claude-opus-4-8",
          end_point = "https://ai.eduvia.dev/v1/messages",
          api_key = cpamc_api_key,
          max_tokens = 512,
          optional = {},
        },
      },
    },
  },

  {
    "saghen/blink.cmp",
    optional = true,
    opts = {
      keymap = {
        -- Récupère une complétion Claude à la demande (mode insertion).
        ["<A-y>"] = {
          function(cmp)
            cmp.show({ providers = { "minuet" } })
          end,
        },
      },
      sources = {
        -- Déclaré mais ABSENT de `default` : manuel seulement, jamais auto.
        providers = {
          minuet = {
            name = "minuet",
            module = "minuet.blink",
            async = true,
            timeout_ms = 6000, -- >= request_timeout * 1000
            score_offset = 50,
          },
        },
      },
    },
  },
}
