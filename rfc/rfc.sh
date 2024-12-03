#!/usr/bin/bash

# TEXTVIEW="nvim -R"
TEXTVIEW="less"
PDFVIEW="zathura"

# arch package rfc(any)
RFC_DIR=/usr/share/doc/rfc
RFC_INDEX=$RFC_DIR/rfc-index.txt

print_help(){
    echo "usage:"
    echo "    rfc [option] <rfc-number>"
    echo "options:"
    echo "    --pdf open rfc in pdf viewer"
    echo "    -q    quick query, show only the summary"
}

print_summary(){
    # if sed takes no filename, it will read stdin
    # but we should let it fail...
    if test -z "$RFC_INDEX" 
    then
        echo "BAD RFC_INDEX"
        exit 1
    fi
    sed -n "/^$1/,/^$/p" $RFC_INDEX
}

open_pdf(){
    PDF=$RFC_DIR/pdf/rfc$1.pdf
    if [ ! -f "$PDF" ]; then
        echo "$PDF not available."
        exit 1;
    fi
    $PDFVIEW $PDF
}


open_txt(){
    TXT=$RFC_DIR/txt/rfc$1.txt
    if [ ! -f "$TXT" ]; then
        echo "$TXT not available."
        exit 1;
    fi
    $TEXTVIEW $TXT
}


re='^[0-9]+$'
# parse argumentsa
while [[ $# -gt 0 ]]; do
  case $1 in
    -q)
      if ! [[ $2 =~ $re ]] ; then
        echo "invalid input" >&2; print_help; exit 1
      fi
      print_summary $2
      exit
      ;;
    --pdf)
      if ! [[ $2 =~ $re ]] ; then
        echo "invalid input" >&2; print_help; exit 1
      fi
      open_pdf $2
      exit
      ;;
    -*|--*)
      print_help
      exit 1
      ;;
    *)
      if ! [[ $1 =~ $re ]] ; then
        echo "invalid input $2" >&2; print_help; exit 1
      fi
      open_txt $1
      exit
      ;;
  esac
done

if [ ! $# -eq 1 ]; then
    print_help
    exit 1
fi
