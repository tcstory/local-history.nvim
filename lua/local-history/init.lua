local M = {}

-- 默认配置
local default_opts = {
  backup_dir = vim.fn.stdpath("state") .. "/local-history-undo",
  silent = true,
}

-- 清理超过 N 天的旧 undofiles
local function cleanup_old_files(dir, days)
  local limit = os.time() - (days * 24 * 60 * 60)
  -- 使用系统命令快速查找并删除（在 Ubuntu 上非常快）
  local cmd = string.format("find %s -type f -atime +%d -delete", dir, days)
  vim.fn.jobstart(cmd, { detach = true })
end

function M.setup(opts)
  -- 合并用户传入的参数
  opts = vim.tbl_deep_extend("force", default_opts, opts or {})

  -- 1. 确保撤销目录存在
  if vim.fn.isdirectory(opts.backup_dir) == 0 then
    vim.fn.mkdir(opts.backup_dir, "p")
  end

  -- 2. 设置 Neovim 内置的持久化撤销引擎
  vim.opt.undofile = true
  vim.opt.undodir = opts.backup_dir

  -- 3. 创建一个简单的命令来查看历史
  -- 这里我们借用 Snacks 的功能（如果你装了的话）或者原生的 undotree
  vim.api.nvim_create_user_command("LocalHistoryCheck", function()
    local has_snacks, snacks = pcall(require, "snacks")
    if has_snacks then
      snacks.picker.undo()
    else
      print("未发现 Snacks 插件，请手动安装 snacks.nvim 以获得更好的视觉效果")
    end
  end, {})

  if not opts.silent then
    print("LocalHistory 已就绪，历史保存在: " .. opts.backup_dir)
  end

  -- 每周自动清理一次（假设你觉得 30 天的历史就够了）
  if math.random() < 0.1 then -- 10% 的概率在启动时触发，避免每次都跑
    cleanup_old_files(opts.backup_dir, 30)
  end
end

return M
