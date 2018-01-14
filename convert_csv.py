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
    parser.add_argument(
        '-ii', '--ignore_internal',
        action='store_true',
        help='ignores inflows from internal accounts - Przelewy Wewnętrzne Przychodzące; default false'
    )
    args = parser.parse_args()
    print(args)

    input_file = args.input_file
    ignore_internal = args.ignore_internal

    if args.credit:
        mbank_parser = CreditCardParser(input_file)
        print("Parsing credit card data:")
    else:
        mbank_parser = AccountParser(input_file)
        print("Parsing account data:")

    mbank_parser.convert_csv(input_file, ignore_internal)
