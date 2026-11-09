local agent_files = { "vi-tutor.md", "vi-design.md" }

local function plugin_root()
  local file = vim.api.nvim_get_runtime_file("lua/vi-ai/init.lua", false)[1]
  return file and vim.fs.dirname(vim.fs.dirname(vim.fs.dirname(file))) or nil
end

local function link_agents()
  local root = plugin_root()
  if not root then
    return
  end
  local dir = vim.fs.joinpath(vim.env.HOME, ".config", "opencode", "agent")
  vim.fn.mkdir(dir, "p")
  for _, name in ipairs(agent_files) do
    local src = vim.fs.joinpath(root, "agents", name)
    local dst = vim.fs.joinpath(dir, name)
    if vim.fn.filereadable(src) == 1 and vim.uv.fs_readlink(dst) ~= src then
      if vim.uv.fs_lstat(dst) then
        vim.uv.fs_unlink(dst)
      end
      vim.uv.fs_symlink(src, dst)
    end
  end
end

local function ensure_opencode_on_path()
  if vim.fn.executable("opencode") == 1 then
    return
  end
  local dir = vim.fs.joinpath(vim.env.HOME, ".opencode", "bin")
  if vim.fn.executable(vim.fs.joinpath(dir, "opencode")) == 1 then
    vim.env.PATH = dir .. ":" .. vim.env.PATH
  end
end

return {
  {
    "fr4nsyz/vi-ai",
    dir = "~/Documents/vi-ai",
    main = "vi-ai",
    lazy = false,
    opts = {
      model = "nvidia/nvidia/nemotron-3.5-lightning-30b-a3b",
    },
    config = function(_, opts)
      require("vi-ai").setup(opts)
      link_agents()
      ensure_opencode_on_path()
    end,
  },
}
