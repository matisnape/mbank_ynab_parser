# mbank_ynab_parser

This is a simple python script for making mBank CSV file for import in YNAB

## Assumptions & Info

- the script is written for Python 3, although it should work under 2 as well
- the script is assuming having multiple accounts inside YNAB - you're prompted to decide about ignoring internal incoming transfers to avoid duplicate transactions (example for True: keeps A->B but ignores B<-A)
- you need to specify the account and credit card data in `constants.py` - name you would like to see in the file and the account number

## Usage

0) Create `constants.py` file from template
    `cp constants.template.py constants.py`
1) `convert_csv.py <path to inputfile>`

available options:

`-h` - help

`-c` - for parsing credit card csv

`-ii` - for ignoring internal transactions

   Note: Will work with paths from the same directory or from fullpath
   Note: Output file will be named `YNAB_ready_inputfile.csv`
2) Go to YNAB
3) Import file to appropriate account

## Planned improvements
- maybe some screaming capslocked values for fields that don't have something relevant
- tests

## Changelog
PR 3
- support for credit card statements
- introduced classes for account & credit card
- replaced getopt with argparse for command line arguments
- cleanup in command line arguments

PR 2
- refactored some stuff
- removed output file option (just generating the new file based on the input)
- prompting user for decision about ignoring internal incoming transactions

PR 1
- better fit with "Regularne oszczędzanie"
- better fit for transfers between owned accounts
- direct parsing for YNAB

### Acknowledgements
This script is inspired by https://github.com/aniav/ynab-csv

### Reporting Issues
If you have any other issues or suggestions, go to https://github.com/matisnape/mbank_ynab_parser/issues and create an issue if one doesn't already exist. If the issue has to do with your csv file, please create a new gist (https://gist.github.com/) with the content of the CSV file and share the link in the issue. If you tweak the CSV file before sharing, just make sure whatever version you end up sharing still causes the problem you describe.

### Contribute
- Fork and clone the project
- Make your changes locally and test them to make sure they work
- Commit those changes and push to your forked repository
- Make a new pull request

