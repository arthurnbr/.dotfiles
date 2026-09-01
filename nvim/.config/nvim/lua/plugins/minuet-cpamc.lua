-- Auto-complétion IA « ghost-text » façon Copilot, via cpamc/eduvia.
--
-- Provider eduvia (`https://ai.eduvia.dev/v1`, API OpenAI-compatible, Bearer)
-- avec **Claude Haiku 4.5** — modèle rapide (~2 s), adapté au ghost-text auto,
-- contrairement à Opus (~3 s, quota Claude Max) qui est trop lent pour ça.
--
-- Ghost-text auto : la suggestion s'affiche en gris pendant que tu tapes.
--   <A-A>  accepter toute la suggestion
--   <A-a>  accepter une ligne
--   <A-]> / <A-[>  suggestion suivante / précédente (ou invocation manuelle)
--   <A-e>  rejeter
--
-- Copilot officiel (copilot.lua) est verrouillé sur GitHub et ne peut pas taper
-- sur un endpoint custom : minuet est le seul frontend qui accepte cpamc/eduvia.

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
      provider = "openai_compatible",
      n_completions = 1, -- une seule suggestion ghost-text à la fois
      context_window = 12000,
      request_timeout = 4,
      throttle = 1000, -- espace les requêtes (quota + coût)
      debounce = 500, -- attend une pause de frappe avant de requêter
      notify = "warn",
      provider_options = {
        openai_compatible = {
          name = "eduvia",
          end_point = "https://ai.eduvia.dev/v1/chat/completions",
          model = "claude-haiku-4-5-20251001",
          api_key = cpamc_api_key,
          optional = {
            max_tokens = 256,
          },
          -- cpamc (CLIProxyAPI) IGNORE le champ `system` : les consignes de
          -- minuet (pas de fences markdown, pas de prose) sont perdues. On les
          -- réinjecte donc en tête du message `user` (chat_input.template), qui
          -- lui est bien transmis — sinon Haiku entoure le code de ``` et ajoute
          -- des explications, ce qui casse le ghost-text.
          chat_input = {
            template = "You are a code completion engine. Output ONLY the raw"
              .. " code completion after <cursorPosition>. NO markdown fences,"
              .. " NO ``` , NO explanations, NO prose. Keep the user's"
              .. " indentation. Separate multiple options with <endCompletion>.\n\n"
              .. "{{{language}}}\n{{{tab}}}\n<contextAfterCursor>\n{{{context_after_cursor}}}"
              .. "\n<contextBeforeCursor>\n{{{context_before_cursor}}}<cursorPosition>",
          },
        },
      },
      virtualtext = {
        -- Ghost-text automatique pour tous les langages.
        auto_trigger_ft = { "*" },
        keymap = {
          accept = "<A-A>",
          accept_line = "<A-a>",
          accept_n_lines = "<A-z>",
          next = "<A-]>",
          prev = "<A-[>",
          dismiss = "<A-e>",
        },
      },
    },
  },
}
