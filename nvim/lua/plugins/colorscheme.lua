require("everforest").setup({
		-- Optional: "hard", "medium", "soft",
		background = "medium",
		transparent_background_level = 0, -- 0 = none, 1 = transparent, 2 = transparent + context
		italics = true,
})

local colorscheme = "everforest"
vim.cmd('silent! colorscheme everforest')
