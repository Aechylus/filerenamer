#!/bin/bash
#messages
USAGE="Usage: filerenamer.sh [-hms] [newname file] [folder] [extension]"
INVALID_FLAG="Invalid flag! Use -h or --help for more info"

#constants
RED='\033[0;31m'
GREEN='\033[0;32m'
ORANGE='\033[0;33m'
NC='\033[0m' #no color
BOLD=$(tput bold)
NORMAL=$(tput sgr0)

#enums: "match", "sequence"

#parsing positional parameters
if [[ $1 == '-h' ]] || [[ $1 == '--help' ]]; then
    echo ${USAGE}
    echo ""
    echo "${BOLD}filerenamer.sh${NORMAL} renames every file in the specified folder with the names"
    echo "provided in the specified file. There are two modes available:"
    echo "the match-renaming mode and the sequential-renaming mode."
    echo ""
    echo "The following options are available:"
    echo ""
    echo "${BOLD}-h${NORMAL}, ${BOLD}--help${NORMAL}"
    echo -e "\t Prints a help message for this program"
    echo ""
    echo "${BOLD}-m${NORMAL}, ${BOLD}--match${NORMAL}"
    echo -e "\t Match-renaming mode: renaming the files by matching the numbers"
    echo -e "\t between the current file name and the new file name in the"
    echo -e "\t specified file."
    echo ""
    echo "${BOLD}-s${NORMAL}, ${BOLD}--sequential${NORMAL}"
    echo -e "\t Sequential-renaming mode: renaming the files based on the"
    echo -e "\t alphabetical order of the old names and the appearance sequence"
    echo -e "\t of the new names in the specified file." 
    echo ""
    exit 0
elif [[ $# -eq 3 ]]; then #without flag
    NAMEFILEPATH="$1"
    DEST="$2"
    EXT="$3"
    MODE="match" #by default
elif [[ $# -eq 4 ]]; then #with flag
    NAMEFILEPATH="$2"
    DEST="$3"
    EXT="$4"
    case "$1" in
        -m|--match)
            MODE="match"
            ;;
        -s|--sequential)
            MODE="sequence"
            ;;
        *)
            echo ${INVALID_FLAG}
            exit 1
    esac
else
    echo ${USAGE}
    exit 1
fi

#reading the new file names from the specified text file
index=0
finished=false
until ${finished}; do
    read -r newname || finished=true #to ensure last line is read
    newnames[index]="${newname}"
    index=`expr ${index} + 1`
done < "${NAMEFILEPATH}"

#reading old file names from the destination directory
cd "${DEST}"
shopt -s nullglob
oldnames=(*)

oldLength=${#oldnames[@]}
newLength=${#newnames[@]}

promptRename() {
    echo -n -e "$1 -> $2.${EXT} \t"
    PROMPT="Confirm rename (y/N): "
    read -p "${PROMPT}" -n 1 response
    echo "" #new line
    if [[ $response == 'y' ]] || [[ $response == 'Y' ]]; then
        mv "$1" "$2.${EXT}"
        if [[ $? -ne 0 ]]; then
            echo -e "${RED}ERROR${NC}: Failed to rename!"
            exit -1
        fi
        return 1
    else
        echo "Skipping $1"
        return 0
    fi
}

sequentialRename() {
    #checking for size mismatch between old files names and new file names
    if [[ ${oldLength} -ne ${newLength} ]]; then
        echo -e "${RED}ERROR${NC}: Size mismatch! (${oldLength} – ${newLength})"

        #finding the biggest array size
        if [[ ${oldLength} -ge ${newLength} ]]; then
            maxIndex=${oldLength}
        else
            maxIndex=${newLength}
        fi

        #printing the contents of both arrays
        for (( i=0; i<${maxIndex}; i++ )); do
            echo "${oldnames[i]} :–: ${newnames[i]}"
        done | column -t -s ':'
        exit 2
    fi

    #prompting the user for confirmation and then rename
    renamed=0
    for (( i=0; i<${oldLength}; i++ )); do
        promptRename "${oldnames[i]}" "${newnames[i]}"
        renamed=`expr ${renamed} + $?`
    done
    echo -e "${GREEN}Success${NC}: Renamed ${renamed} files."
}

matchRename() {
    #prompting the user for confirmation and then rename
    renamed=0
    matchFound=false
    for (( i=0; i<${oldLength}; i++ )); do
        oldNumber=$(echo ${oldnames[i]} | egrep -o "\d+")
        for (( j=0; j<${newLength}; j++ )); do
            newNumber=$(echo ${newnames[j]} | egrep -o "S\d{2}E\d{3}" | egrep -o "\d{3}")
            #TODO add code to skip if length > 1
            if [ ${oldNumber} -eq ${newNumber} ]; then
                promptRename "${oldnames[i]}" "${newnames[j]}"
                renamed=`expr ${renamed} + $?`
                matchFound=true
                break
            fi
        done
        if [[ ${matchFound} = false ]]; then
            echo -e "${ORANGE}Warning${NC}: Match not found for ${oldnames[i]}!"
        fi
        matchFound=false
    done
    echo -e "${GREEN}Success${NC}: Renamed ${renamed} files."
}

if [[ ${MODE} == "match" ]]; then
    echo -e "${ORANGE}Info${NC}: You are in \"match-renaming\" mode."
    matchRename
elif [[ ${MODE} == "sequence" ]]; then
    echo -e "${ORANGE}Info${NC}: You are in \"sequential-renaming\" mode."
    sequentialRename
else
    echo -e "${RED}ERROR${NC}: Internal error – invalid mode!"
    exit -2
fi