require("lazydev").setup({
		ft = "lua", -- Only load on lua files
		opts = {
				library = {
						-- Only load luvit types when the `vim.uv` word is found
						{ path = "${3rd}/luv/library", words = { "vim%.uv" } },
				},
		},
})

vim.lsp.config('hls', {
  cmd = { 'haskell-language-server-wrapper', '--lsp' },
})
if vim.fn.executable('haskell-language-server-wrapper') == 1 then 
  vim.lsp.enable('hls')
end


vim.lsp.config('lua_ls', {
  cmd = { vim.fn.exepath('lua-language-server') },
})
vim.lsp.enable("lua_ls")
vim.lsp.enable("nil_ls")
