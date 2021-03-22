# ls aliases
alias l="ls"
alias ll="ls -al"

# clear alias
alias c="clear"

update() {
    cd ~/Scripts && ./update.sh && cd - &>/dev/null
}

# SelEct emoji depending on last exit code
emoji() {
    [[ $? -eq 0 ]] && echo 🤔 || echo 😡
}

# Colorful prompt
prompt_color='\[\033[0;34m\]'
info_color='\[\033[01;33m\]'
if [ "$EUID" -eq 0 ]; then # Change prompt colors for root user
	prompt_color='\[\033[0;34m\]'
	info_color='\[\033[1;31m\]'
	prompt_symbol=💀
fi

PS1=$prompt_color'┌──${debian_chroot:+($debian_chroot)──}('$info_color'\u $(emoji) \h'$prompt_color')-[\[\033[0;33m\]\w'$prompt_color']\n'$prompt_color'└─'$info_color'\$\[\033[0m\] '

# Display random image when open new terminal
if [ -f ~/.bash_img ]; then
    . .bash_img $rand
fi
