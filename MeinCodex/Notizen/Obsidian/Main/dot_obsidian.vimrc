" Obsidian Vim config — mirrors Neovim movements where they translate.
" Plugin: obsidian-vimrc-support. Loaded automatically on vault open.
" Leader = ',' (matches nvim mapleader). Localleader-style = '<Space>'.

" --- Settings ---------------------------------------------------------------
set clipboard=unnamed

" --- Insert-mode quick escape ----------------------------------------------
imap jk <Esc>

" --- Smart visual-line motion (lines wrap aggressively in Obsidian) --------
nmap j gj
nmap k gk
vmap j gj
vmap k gk
nmap <Down> gj
nmap <Up> gk
vmap <Down> gj
vmap <Up> gk

" --- Line anchors ----------------------------------------------------------
nmap gh ^
nmap gl $
vmap gh ^
vmap gl $
omap gh ^
omap gl $

" --- Visual indent keeps selection ----------------------------------------
vmap < <gv
vmap > >gv

" --- Yank to end of line (sane default) -----------------------------------
nmap Y y$

" --- Obsidian command bindings (exmap → obcommand → nmap) -----------------
" Tabs
exmap nexttab obcommand workspace:next-tab
exmap prevtab obcommand workspace:previous-tab
exmap newtab obcommand workspace:new-tab
exmap closepane obcommand workspace:close

nmap H :prevtab<CR>
nmap L :nexttab<CR>
nmap [b :prevtab<CR>
nmap ]b :nexttab<CR>

" Pane focus (Ctrl-hjkl, mirrors smart-splits)
exmap focusleft obcommand editor:focus-left
exmap focusright obcommand editor:focus-right
exmap focusup obcommand editor:focus-top
exmap focusdown obcommand editor:focus-bottom

nmap <C-h> :focusleft<CR>
nmap <C-l> :focusright<CR>
nmap <C-k> :focusup<CR>
nmap <C-j> :focusdown<CR>

" Pane splits
exmap splithoriz obcommand workspace:split-horizontal
exmap splitvert obcommand workspace:split-vertical

nmap ,wd :closepane<CR>
nmap ,w- :splithoriz<CR>
nmap ,w<Bar> :splitvert<CR>

" Tab management group (mirrors <leader><tab>... in nvim)
nmap ,<Tab><Tab> :newtab<CR>
nmap ,<Tab>] :nexttab<CR>
nmap ,<Tab>[ :prevtab<CR>
nmap ,<Tab>d :closepane<CR>

" --- Pickers / search (mirrors <leader> in snacks.lua) --------------------
exmap quickswitcher obcommand switcher:open
exmap omnisearchfile obcommand omnisearch:show-modal-infile
exmap omnisearchvault obcommand omnisearch:show-modal
exmap revealfile obcommand file-explorer:reveal-active-file

nmap ,<Space> :quickswitcher<CR>
nmap ,, :quickswitcher<CR>
nmap ,fr :quickswitcher<CR>
nmap ,/ :omnisearchfile<CR>
nmap ,sg :omnisearchvault<CR>
nmap ,e :revealfile<CR>

" --- Folding (mirrors <space><space> localleader binding) -----------------
exmap togglefold obcommand editor:toggle-fold
exmap foldall obcommand editor:fold-all
exmap unfoldall obcommand editor:unfold-all

nmap <Space><Space> :togglefold<CR>
nmap zM :foldall<CR>
nmap zR :unfoldall<CR>

" --- Link & history navigation (mirror of LSP gd / jumplist) --------------
exmap followlink obcommand editor:follow-link
exmap goback obcommand app:go-back
exmap goforward obcommand app:go-forward

nmap gd :followlink<CR>
nmap <C-o> :goback<CR>
nmap <C-i> :goforward<CR>

" --- View toggles ---------------------------------------------------------
exmap togglepreview obcommand markdown:toggle-preview
exmap togglesource obcommand editor:toggle-source
exmap toggleleftsb obcommand app:toggle-left-sidebar
exmap togglerightsb obcommand app:toggle-right-sidebar

nmap ,op :togglepreview<CR>
nmap ,os :togglesource<CR>
nmap ,tl :toggleleftsb<CR>
nmap ,tr :togglerightsb<CR>
