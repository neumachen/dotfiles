---@module 'lazy'
---@type LazySpec
return {
  'CoreyKaylor/diffbandit.nvim',
  cmd = {
    'DiffBandit',
    'DiffBanditBuffers',
    'DiffBanditFolderDiff',
    'DiffBanditGit',
    'DiffBanditGitCurrent',
    'DiffBanditCommitPanel',
    'DiffBanditGitMenu',
    'DiffBanditGitLog',
    'DiffBanditGitCommit',
    'DiffBanditGitCompare',
    'DiffBanditGitCheckout',
    'DiffBanditMerge',
  },
  keys = {
    {
      '<localleader>gD',
      '<cmd>DiffBanditGit<cr>',
      desc = 'DiffBandit: repository changes',
    },
    {
      '<localleader>gC',
      '<cmd>DiffBanditGitCurrent<cr>',
      desc = 'DiffBandit: current file',
    },
    {
      '<localleader>gP',
      '<cmd>DiffBanditCommitPanel<cr>',
      desc = 'DiffBandit: commit panel',
    },
  },
  opts = {},
}
