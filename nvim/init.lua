-- Basic options
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.mouse = "a"
vim.opt.termguicolors = true
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true

-- Set leader key to space
vim.g.mapleader = " "

-- Setup lazy.nvim
vim.opt.rtp:prepend("~/.local/share/nvim/lazy/lazy.nvim")

require("lazy").setup({
    { "folke/tokyonight.nvim", lazy = false, priority = 1000, opts = {} },
    { "nvim-tree/nvim-tree.lua", dependencies = { "nvim-tree/nvim-web-devicons" } },
    { "nvim-lualine/lualine.nvim", dependencies = { "nvim-tree/nvim-web-devicons" } },
    { "nvim-telescope/telescope.nvim", tag = "0.1.8", dependencies = { "nvim-lua/plenary.nvim" } },
    { "nvim-treesitter/nvim-treesitter", build = ":TSUpdate" },
    { "goolord/alpha-nvim", dependencies = { "nvim-tree/nvim-web-devicons" } },
})

-- Setup nvim-tree
require("nvim-tree").setup()

-- Setup telescope with keymaps
local builtin = require("telescope.builtin")
vim.keymap.set("n", "<leader>ff", builtin.find_files, { desc = "Telescope find files" })
vim.keymap.set("n", "<leader>fg", builtin.live_grep, { desc = "Telescope live grep" })
vim.keymap.set("n", "<leader>fb", builtin.buffers, { desc = "Telescope buffers" })
vim.keymap.set("n", "<leader>fh", builtin.help_tags, { desc = "Telescope help tags" })

-- Setup Treesitter
require("nvim-treesitter.configs").setup({
    ensure_installed = { "lua", "vim", "python", "javascript", "typescript", "html", "css", "json" },
    highlight = { enable = true },
    indent = { enable = true },
})

-- Setup Lualine
require("lualine").setup({
    options = {
        theme = "tokyonight",
        component_separators = "",
        section_separators = { left = "", right = "" },
        globalstatus = true,
    },
})

-- Setup Alpha Dashboard
local status_ok, alpha = pcall(require, "alpha")
if status_ok then
    local dashboard = require("alpha.themes.dashboard")
    dashboard.section.header.val = {
        "███╗   ██╗██╗   ██╗██╗███╗   ███╗",
        "████╗  ██║██║   ██║██║████╗ ████║",
        "██╔██╗ ██║██║   ██║██║██╔████╔██║",
        "██║╚██╗██║╚██╗ ██╔╝██║██║╚██╔╝██║",
        "██║ ╚████║ ╚████╔╝ ██║██║ ╚═╝ ██║",
        "╚═╝  ╚═══╝  ╚═══╝  ╚═╝╚═╝     ╚═╝",
    }
    dashboard.section.buttons.val = {
        dashboard.button("e", "   New file", ":ene <BAR> startinsert <CR>"),
        dashboard.button("r", "   Recent files", ":Telescope oldfiles<CR>"),
        dashboard.button("t", "  󰈞 Find file", ":Telescope find_files<CR>"),
        dashboard.button("q", "  󰅖 Quit", ":qa<CR>"),
    }
    dashboard.config.layout = {
        { type = "padding", val = vim.fn.max { 2, vim.fn.floor(vim.fn.winheight(0) * 0.2) } },
        dashboard.section.header,
        { type = "padding", val = 5 },
        dashboard.section.buttons,
        { type = "padding", val = 3 },
        dashboard.section.footer,
    }
    alpha.setup(dashboard.config)
end

-- Setup tokyonight colorscheme
require("tokyonight").setup({
    style = "night", -- options: "storm", "night", "moon", "day"
    transparent = false,
    terminal_colors = true,
})

vim.cmd[[colorscheme tokyonight]]

-- Keymaps
vim.keymap.set("n", "<leader>\\", ":NvimTreeToggle<CR>", { noremap = true, silent = true })


