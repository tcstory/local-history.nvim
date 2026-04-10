local M = {}

-- 默认配置
local default_opts = {
  backup_dir = vim.fn.stdpath("state") .. "/local-history-undo",
  silent = true,
  interval = 5 * 60 * 1000, -- 默认 5 分钟 (毫秒)
}

-- 清理超过 N 天的旧 undofiles
local function cleanup_old_files(dir, days)
  local limit = os.time() - (days * 24 * 60 * 60)
  -- 使用系统命令快速查找并删除（在 Ubuntu 上非常快）
  local cmd = string.format("find %s -type f -atime +%d -delete", dir, days)
  vim.fn.jobstart(cmd, { detach = true })
end

local function auto_save(opts) 
  -- vim.print("LocalHistory: opts", opts)
  -- 2. 创建一个定时器来实现“时间间隔快照”
  local timer = vim.uv.new_timer()
  
  -- 每隔一段时间执行一次
  timer:start(opts.interval, opts.interval, vim.schedule_wrap(function()
    -- 获取当前所有的缓冲区
    local buffers = vim.api.nvim_list_bufs()
    for _, buf in ipairs(buffers) do
      -- 只有当缓冲区已加载、有名字、且被修改过时，才自动保存
      if vim.api.nvim_buf_is_loaded(buf) and 
         vim.api.nvim_buf_get_name(buf) ~= "" and
         vim.bo[buf].modified then
         
        -- 执行静默保存，这会在 undofile 里创建一个时间节点
        -- 使用 nested=true 是为了防止意外触发其他复杂的自动命令
        vim.api.nvim_buf_call(buf, function()
          -- 不要触发 Linting 或格式化
          vim.cmd("noautocmd silent! update")
        end)
      end
    end
    
    if not opts.silent then
      print("LocalHistory: 已创建自动时间戳快照")
    end
  end))
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

  auto_save(opts)
end

return M
