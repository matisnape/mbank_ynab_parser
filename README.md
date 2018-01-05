# mbank_ynab_parser

This is a simple python script for making mBank CSV file usable with this parser https://aniav.github.io/ynab-csv/

Yep, you're reading right - this is parser for parser :D

## Usage

1) `convert_csv.py -i <path to inputfile> -o <path to outputfile> `
    
   Will work with paths from the same directory or from fullpath
2) Go to https://aniav.github.io/ynab-csv/ and upload generated file
3) Download the YNAB-ready file
4) Import to YNAB

You can ask for help with:
`convert_csv.py -h`

## Planned improvements

1) better fit with "Regularne oszczędzanie"
2) better fit for transfers between owned accounts
3) maybe some screaming capslocked values for fields that don't have something relevant
4) maybe refactor :D
