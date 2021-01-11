# ls aliases
alias l="ls"
alias ll="ls -al"

# clear alias
alias c="clear"

# Path tracking aliases
alias cd="pushd &>/dev/null"
alias back="popd &>/dev/null"

# Colorful prompt
rand=$RANDOM
number=$(( $rand % 6 ))
lightness=$(( $rand % 2 ))
# Remove black color
if [ $number -eq 0 ]; then
	lightness=1
fi
emojis=(🤔 😬 🤷‍ 🤫 👿 😒 🎁 😥 🤢 😁 😎)
emojis_len=11                             # ${#emojis[@]} doesn't detect propertly array length, can I fix this?
emoji_numb=$(( $rand % $emojis_len))
export PS1="${emojis[$emoji_numb]} ${debian_chroot:+($debian_chroot)}\[\033["$lightness";3"$number"m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ "


# Display random image when open new terminal
if [ -f ~/.bash_img ]; then
    . .bash_img $rand
fi