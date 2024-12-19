# ~/.bashrc: Loftwahified and Compatible with All Functionality

# Only run for interactive shells
case $- in
    *i*) ;;
      *) return;;
esac

# History settings
HISTCONTROL=ignoreboth
shopt -s histappend
HISTSIZE=1000
HISTFILESIZE=2000

# Check window size after each command
shopt -s checkwinsize

# Enable `**` globstar for recursive matches (uncomment to activate)
#shopt -s globstar

# Enable `lesspipe` for improved `less` functionality
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# Set a variable identifying the chroot environment
if [ -z "${debian_chroot:-}" ] && [ -r /etc/debian_chroot ]; then
    debian_chroot=$(cat /etc/debian_chroot)
fi

# Set a coloured prompt if supported
case "$TERM" in
    xterm-color|*-256color) color_prompt=yes;;
esac

if [ -n "$force_color_prompt" ] || [ "$color_prompt" = yes ]; then
    if [ -x /usr/bin/tput ] && tput setaf 1 >&/dev/null; then
        PS1='${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
    fi
else
    PS1='${debian_chroot:+($debian_chroot)}\u@\h:\w\$ '
fi

# Set terminal title for xterm-like terminals
case "$TERM" in
    xterm*|rxvt*)
        PS1="\[\e]0;${debian_chroot:+($debian_chroot)}\u@\h: \w\a\]$PS1"
        ;;
esac

# Enable colour support for `ls` and aliases for common commands
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'
    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi

# Additional `ls` aliases
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'

# Alert alias for long-running commands
alias alert='notify-send --urgency=low -i "$( [ $? = 0 ] && echo terminal || echo error )" "$(history | tail -n1 | sed -e '\''s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//'\'' )"'

# Source additional aliases if available
if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
fi

# Enable programmable completion features
if ! shopt -oq posix; then
    if [ -f /usr/share/bash-completion/bash_completion ]; then
        . /usr/share/bash-completion/bash_completion
    elif [ -f /etc/bash_completion ]; then
        . /etc/bash_completion
    fi
fi

# History file customisation
export HISTCONTROL=ignoredups:erasedups  # Avoid duplicate history entries
export HISTSIZE=10000                   # Increase history size
export HISTFILESIZE=20000

# Custom paths
export PATH="$HOME/.rbenv/bin:$PATH"
eval "$(rbenv init -)"
. "$HOME/.cargo/env"
export PATH="$PATH:/opt/nvim/bin"

# Integration with Rust, Bun, and Go environments
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
export GOPATH="$HOME/go"
export PATH="$PATH:/usr/local/go/bin:$GOPATH/bin"

# AWS CLI customisation
export AWS_PAGER=""

# SSH agent auto-start
if [ -z "$SSH_AUTH_SOCK" ] && [ -x "$(command -v ssh-agent)" ]; then
    eval "$(ssh-agent -s)"
fi

# Prompt customisation (Loftwah style)
PS1='\[\033[01;34m\]Loftwah \[\033[01;32m\]\w\[\033[00m\]$(__git_ps1 " (%s)") \[\033[01;31m\]➜ \[\033[00m\]'

# ASCII art (Loftwah vibes)
echo -e "\033[1;35m"
cat << 'EOF'
         _nnnn_                      
        dGGGGMMb     ,"""""""""""""".
       @p~qp~~qMb    |   Loftwah!   |
       M|@||@) M|   _;..............'
       @,----.JM| -'
      JS^\__/  qKL
     dZP        qKRb
    dZP          qKKb
   fZP            SMMb
   HZM            MMMM
   FqM            MMMM
 __| ".        |\dS"qML
 |    `.       | `' \Zq
_)      \.___.,|     .'
\____   )MMMMMM|   .'
     `-'       `--'
EOF
echo -e "\033[0m"
echo "Welcome back, Loftwah! Let's make magic happen. 🚀"
