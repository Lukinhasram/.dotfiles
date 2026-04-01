require("lazydev").setup({
		ft = "lua", -- Only load on lua files
		opts = {
				library = {
						-- Only load luvit types when the `vim.uv` word is found
						{ path = "${3rd}/luv/library", words = { "vim%.uv" } },
				},
		},
})

require("mason").setup()

require("mason-lspconfig").setup({
		ensure_installed = { 
      "lua_ls", 
      "hls", 
    },
		automatic_installation = true,

})

