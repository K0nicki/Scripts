#!/bin/bash
# Script contains my wishes for you

# Variables
person="You"
badMemories=("sorrow" "pain" "angry" "hate" "envy")
newMemories=("happiness" "success" "inspirations" "opportunities")
newYear=2021

# Delete someones ($1) memorial ($2)
deleteMemorial() {
    printf "$1 forget $2!\n"
}

# Push into someones ($1) life some feelings ($2)
pushMemorial() {
    printf "I wish $1 a lot of $2!\n"
}

line() {
        for i in {1..60}; do printf '-'; done
}

header() {
    line
    printf "\n\t\tHEPPY NEW YEAR !!! 💃💃💃\n\n"
}

footer() {
    printf "\n\t\t\t\t\tBest Wishes,\n\t\t\t\t\t  Konrad :)\n"
    line
    printf "\n"
}

createGreetingsCard() {

    header
    for memorial in ${badMemories[@]}; do
        printf "\t\t"
        deleteMemorial $person $memorial
    done
    printf "\n"
    for memorial in ${newMemories[@]}; do
        printf "\t\t"
        pushMemorial $person $memorial
    done
    footer
    
}

# Wishes
createGreetingsCard
