# mbank_ynab_parser

This is a simple python script for making mBank CSV file for import in YNAB

## Assumptions & Info

- the app is assuming having multiple accounts inside YNAB - it ignores incoming internal transfers to avoid duplicate internal transactions (example: keeps A->B but ignores B<-A)
- you need to specify the account and credit card data in `constants.py` - name you would like to see in the file and the account number

## Usage

0) Create `constants.py` file from template
    `cp constants.template.py constants.py`
1) `convert_csv.py -i <path to inputfile> -o <path to outputfile> `

   Note: Will work with paths from the same directory or from fullpath
   Note: Output is optional - file will be named `YNAB_ready_inputfile.csv` if output is not provided
2) Go to YNAB
4) Import file to appropriate account

You can ask for help with:
`convert_csv.py -h`

## Planned improvements

- maybe some screaming capslocked values for fields that don't have something relevant
- maybe refactor :D
- tests

## Changelog
PR 1
- ~~better fit with "Regularne oszczędzanie"~~
- ~~better fit for transfers between owned accounts~~
- ~~direct parsing for YNAB~~

