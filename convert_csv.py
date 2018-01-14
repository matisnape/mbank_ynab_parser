import sys
import argparse
from mbank_parser import AccountParser, CreditCardParser

if __name__ == "__main__":

    parser = argparse.ArgumentParser(description='Parse mBank CSV for YNAB.')
    parser.add_argument(
        dest='input_file',
        help='CSV file for parsing'
    )
    parser.add_argument(
        '-c', '--credit',
        action='store_true',
        help='optional, uses parser for credit card csv'
    )
    args = parser.parse_args()

    input_file = args.input_file

    if args.credit:
        mbank_parser = CreditCardParser(input_file)
        print("Parsing credit card data:")
    else:
        mbank_parser = AccountParser(input_file)
        print("Parsing account data:")

    ignore_internal_question = (input(
        "Ignore inflows from internal accounts - 'Przelewy Wewnętrzne Przychodzące'? Y/N: "
        )).lower()
    if ignore_internal_question == 'y':
        ignore_internal = True
    elif ignore_internal_question == 'n':
        ignore_internal = False
    else:
        print("Sorry, I haven't understood your answer. Try again, please :)")
        sys.exit()
    mbank_parser.convert_csv(input_file, ignore_internal)
