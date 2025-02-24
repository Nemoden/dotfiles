return {
	"folke/todo-comments.nvim",
  dependencies = {
    "nvim-telescope/telescope.nvim",
  },
	event = "BufRead",
	config = function()
		require("todo-comments").setup({
			highlight = {
				pattern = [[.*<(KEYWORDS)\s*]], -- pattern or table of patterns, used for highlightng (vim regex)
				comments_only = true, -- uses treesitter to match keywords in comments only
				exclude = {}, -- list of file types to exclude highlighting
			},
			colors = {
				info = { "String", "#a0c980" },
			},
			search = {
				pattern = [[\b(KEYWORDS)\b]], -- match without the extra colon. You'll likely get false positives
			},
			merge_keywords = false, -- when true, custom keywords will be merged with the defaults
			keywords = {
				-- FIXME thingy 襁
				FIX = {
					icon = " ", -- icon used for the sign, and in search results
					color = "error", -- can be a hex color, or a named color (see below)
					alt = { "FIXME", "BUG", "FIXIT", "ISSUE" }, -- a set of other keywords that all map to this FIX keywords
				},
				-- TODO foobar
				TODO = { icon = " ", color = "info" },
				-- HACK why would you do this
				HACK = { icon = " ", color = "warning" },
				-- PERF please optimize me
				PERF = {
					color = "warning",
					icon = " ",
					alt = { "OPTIM", "PERFORMANCE", "OPTIMIZE" },
				},
				-- 
			},
		})
	end,
  keys = {
    {"<leader>td", mode="n", ":TodoFzfLua<cr>", desc="List todo entries"}
  },
}
