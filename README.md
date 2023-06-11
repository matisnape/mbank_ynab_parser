# mbank_ynab_parser

This repo contains 2 scripts for processing an mBank CSV file into a file supported by YNAB - in Elixir and in Python

## Elixir

### Assumptions & Info

- the script was written for Elixir 1.14, but there's nothing complicated in it not to work in other versions
- the script is assuming you have multiple accounts inside YNAB and it's meant to be used with any of them (maybe apart from credit card statements) - there should not be any duplicate transactions in case you import files for transactions between them. It's mostly YNAB doing its job with matching, but it's worth to mention.
- the script was not tested with credit card statements - mBank's transactions list for them is very limited so personally I scrape them via Javascript script in browser

Acknowledgements:
- Encoding inspired by [this thread](https://elixirforum.com/t/sharing-with-the-community-text-transcoding-libraries/17962)
- Script structure I learned from [this lovely repo](https://github.com/wojtekmach/mix_install_examples/)

### Usage

0) Define a function `accounts` in `MbankParser` module for mapping accounts in transactions
1) `elixir mbank_parser.exs <path to inputfile>`
2) A new file will be written to the same location as the input file
3) Go to YNAB
4) Import file to appropriate account

## Python

### Assumptions & Info

Deprecation warning: the script works as of 06.2023, but it's kinda not very readable so I'm not going to support it

- the script is written for Python 3, although it should work under 2 as well
- the script is assuming having multiple accounts inside YNAB - you're prompted to decide about ignoring internal incoming transfers to avoid duplicate transactions (example for True: keeps A->B but ignores B<-A)
- you need to specify the account and credit card data in `constants.py` - name you would like to see in the file and the account number

### Usage

0) Create `constants.py` file from template
    `cp constants.template.py constants.py`
1) `python3 convert_csv.py <path to inputfile>`

available options:

`-h` - help
`-c` - for parsing credit card csv
`-ii` - for ignoring internal transactions

   Note: Will work with paths from the same directory or from fullpath
   Note: Output file will be named `YNAB_ready_inputfile.csv`

2) Go to YNAB
3) Import file to appropriate account

### Planned improvements
- maybe some screaming capslocked values for fields that don't have something relevant
- tests
- support for files from directory different than the one of the script

### Changelog
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

#### Acknowledgements
This script is inspired by https://github.com/aniav/ynab-csv

#### Reporting Issues
If you have any other issues or suggestions, go to https://github.com/matisnape/mbank_ynab_parser/issues and create an issue if one doesn't already exist. If the issue has to do with your csv file, please create a new gist (https://gist.github.com/) with the content of the CSV file and share the link in the issue. If you tweak the CSV file before sharing, just make sure whatever version you end up sharing still causes the problem you describe.

#### Contribute
- Fork and clone the project
- Make your changes locally and test them to make sure they work
- Commit those changes and push to your forked repository
- Make a new pull request

