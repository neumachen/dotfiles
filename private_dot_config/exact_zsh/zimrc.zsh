# https://github.com/zimfw/zimfw/issues/528#issuecomment-2600737209
# REF: https://github.com/zimfw/zimfw/issues/528
function zmodule-custom() {
  local zcommand zname ztarget
  local -a zargs
  zcommand=${1}
  zname=custom/${zcommand}
  shift
  while (( # > 0 )); do
    case ${1} in
      --name)
        shift
        zname=${1}
        ;;
      --if)
        shift
        zargs+=(--if "(( \${+commands[${zcommand}]} )) && ${1}")
        ;;
      --if-command)
        shift
        zargs+=(--if "(( \${+commands[${zcommand}]} && \${+commands[${1}]} ))")
        ;;
      --if-ostype)
        shift
        zargs+=(--if "(( \${+commands[${zcommand}]} )) && [[ \${OSTYPE} == ${1} ]]")
        ;;
      --on-pull)
        shift
        zargs+=(--on-pull ${1})
        ;;
      -d|--disabled)
        zargs+=(--disabled)
        ;;
      -f|--fpath)
        shift
        zargs+=(--fpath ${1})
        ;;
      -a|--autoload)
        shift
        zargs+=(--autoload ${1})
        ;;
      -s|--source)
        shift
        zargs+=(--source ${1})
        ;;
      -c|--cmd)
        shift
        zargs+=(--cmd ${1})
        ;;
      --comp)
        shift
        ztarget=functions/_${1//[^[:IDENT:]]/-}
        zargs+=(--on-pull "mkdir functions")
        zargs+=(--fpath functions)
        zargs+=(--cmd "if [[ ! {}/${ztarget} -nt \${commands[${zcommand}]} ]]; then ${1} >! {}/${ztarget}; fi")
        zargs+=(--cmd "if (( \${+_comps} && ! \${+_comps[${zcommand}]} )); then autoload -Uz ${ztarget:t}; _comps[${zcommand}]=${ztarget:t}; fi")
        ;;
      --eval)
        shift
        ztarget=${1//[^[:IDENT:]]/-}.zsh
        zargs+=(--cmd "if [[ ! {}/${ztarget} -nt \${commands[${zcommand}]} ]]; then ${1} >! {}/${ztarget}; zcompile -UR {}/${ztarget}; fi")
        zargs+=(--source ${ztarget})
        ;;
      *)
        print "Unknown zmodule option ${1}"
        return 2
        ;;
    esac
    shift
  done

  zmodule custom-${zcommand} --name ${zname} --use mkdir --if-command ${zcommand} ${zargs}
}

# Load first in order for dependent qpps to detect mise managed tools
zmodule joke/zim-mise

# To avoid rewriting fzf opts load first
zmodule jeffreytse/zsh-vi-mode

# Zim modules
zmodule custom
zmodule environment
zmodule exa
zmodule fzf
zmodule git
zmodule homebrew
zmodule input
zmodule magic-enter
zmodule termtitle
zmodule utility

# Community Modules
zmodule joke/zim-chezmoi
zmodule joke/zim-github-cli
zmodule joke/zim-helm
zmodule joke/zim-istioctl
zmodule joke/zim-k9s
zmodule joke/zim-kubectl
zmodule joke/zim-minikube
zmodule joke/zim-skaffold
zmodule shanwker1223/zim-alias-finder
zmodule wfxr/forgit

# Prompt
zmodule joke/zim-starship

# Oh-My-Zsh libraries and plugins
zmodule ohmyzsh/ohmyzsh --root lib --source clipboard.zsh

# Completions
zmodule ahmetb/kubectx --fpath completion/_kubectx.zsh --fpath completion/_kubens.zsh
zmodule greymd/docker-zsh-completion --source docker-zsh-completion.plugin.zsh
zmodule eza-community/eza --root completions/zsh --fpath _eza
zmodule ohmyzsh/ohmyzsh --root plugins/rust --fpath _rustc
zmodule rust-lang/cargo --root src/etc --fpath _cargo
zmodule sharkdp/fd --root contrib/completion --fpath _fd
zmodule wfxr/forgit --root completions --fpath _git-forgit
zmodule x-motemen/ghq --root misc/zsh --fpath _ghq
zmodule zsh-users/zsh-completions --fpath src

zmodule-custom broot --source "${HOME}/.config/broot/launcher/bash/br"

zmodule-custom zoxide --eval "zoxide init --cmd cd zsh"
zmodule-custom starship --eval "starship init zsh"

# fzf-tab needs to be loaded after compinit, but before plugins which will wrap
# widgets, such as zsh-autosuggestions or fast-syntax-highlighting
zmodule Aloxaf/fzf-tab
zmodule zdharma-continuum/fast-syntax-highlighting
zmodule marlonrichert/zsh-autocomplete

# Load last
zmodule completion
