import csv
import sys
import getopt
import re
import constants

YNAB_HEADERS = constants.YNAB_HEADERS
YNAB_FILENAME_PREFIX = constants.YNAB_FILENAME_PREFIX
YNAB_DELIMITER = constants.YNAB_DELIMITER
MBANK_DELIMITER = constants.MBANK_DELIMITER

REGULARNE = constants.REGULARNE
SPLATA_KART = constants.SPLATA_KART
KARTA = constants.KARTA
KAPITALIZACJA = constants.KAPITALIZACJA
PODATEK_ODSETKI = constants.PODATEK_ODSETKI
INTERNAL_TRANSFER = constants.INTERNAL_TRANSFER
INTERNAL_INCOMING = constants.INTERNAL_INCOMING

KONTO_1 = constants.KONTO_1
KONTO_2 = constants.KONTO_2
KONTO_3 = constants.KONTO_3
KONTO_REGULARNE = constants.KONTO_REGULARNE

DATE_COL = 0
OPIS_OPERACJI_COL = 1
MEMO_COL = 2
PAYEE_COL = 3
NUMER_KONTA_COL = 4
AMOUNT_COL = 5
OLD_AMOUNT_COL = 6

def main(argv):
    input_file = ''
    output_file = ''
    try:
        opts, args = getopt.getopt(argv, "hi:o:", ["ifile=", "ofile="])
    except getopt.GetoptError:
        print('convert_csv.py -i <path to inputfile> -o <path to outputfile> ')
        sys.exit(2)
    for opt, arg in opts:
        if opt == '-h':
            print('convert_csv.py -i <path to inputfile> -o <path to outputfile> ')
            sys.exit()
        elif opt in ("-i", "--ifile"):
            input_file = arg
        elif opt in ("-o", "--ofile"):
            output_file = arg
    if not output_file:
        convert_csv(input_file, input_file)
    else:
        convert_csv(input_file, output_file)

def convert_csv(input_csv, new_csv):
    with open(input_csv, 'r', encoding='cp1250') as csv_file:
        csvRows = csv_file.readlines()[38:-5]
        transactions_list = [YNAB_HEADERS]

        for row in csvRows:
            new_row = convert_row(row)

            # ignore transfer from own accounts
            # TODO: add option for this in the cmd
            if new_row[OPIS_OPERACJI_COL] != INTERNAL_INCOMING:
                print(new_row)
                transactions_list.append(
                    [new_row[DATE_COL], new_row[MEMO_COL], new_row[PAYEE_COL], new_row[AMOUNT_COL]]
                )

        write_file_ynab(transactions_list, new_csv)

def convert_row(row):
    new_row = row.split(';')[:-2]
    format_expense_amount(new_row)
    # remove Data księgowania
    new_row.pop(1)
    # merge Numer konta with Memo
    merge_accountid_with_memo(new_row)
    # REGULARNE OSZCZĘDZANIE
    replace_regularne(new_row, KONTO_REGULARNE)
    # Credit Card pay up
    replace_credit_payup(new_row, KARTA)
    # Kapitalizacja & Odsetki
    replace_other(new_row, KAPITALIZACJA)
    replace_other(new_row, PODATEK_ODSETKI)
    # if Payee empty, move Memo there
    populate_payee_if_empty(new_row)
    # transfer to accounts
    replace_account(new_row, KONTO_1)
    replace_account(new_row, KONTO_2)
    replace_account(new_row, KONTO_3)

    return new_row

def format_expense_amount(row):
    row[OLD_AMOUNT_COL] = row[OLD_AMOUNT_COL].replace(',', '.').replace(' ', '')

def populate_payee_if_empty(row):
    if row[PAYEE_COL] == '"  "':
        row[PAYEE_COL] = row[MEMO_COL]
        row[MEMO_COL] = ''

def merge_accountid_with_memo(row):
    if row[NUMER_KONTA_COL] != '':
        row[MEMO_COL] = row[MEMO_COL] + row[NUMER_KONTA_COL]

def replace_account(row, account):
    if INTERNAL_TRANSFER in row[OPIS_OPERACJI_COL] and (account["id"] in row[NUMER_KONTA_COL]):
        row[PAYEE_COL] = 'Transfer: {}'.format(account["name"])

def replace_regularne(row, account):
    if KONTO_REGULARNE["id"] in row[OPIS_OPERACJI_COL]:
        row[PAYEE_COL] = 'Transfer: {}'.format(account["name"])

def replace_other(row, word):
    if word in row[OPIS_OPERACJI_COL]:
        row[PAYEE_COL] = word.capitalize()

def replace_credit_payup(row, card):
    if SPLATA_KART in row[OPIS_OPERACJI_COL] and card["id"] in row[MEMO_COL]:
        row[PAYEE_COL] = 'Transfer: {}'.format(card["name"])

def write_file_ynab(data, new_csv):
    ynab_filename = YNAB_FILENAME_PREFIX + new_csv

    with open(ynab_filename, 'w', encoding='utf-8') as converted_file:
        csvWriter = csv.writer(converted_file, delimiter=YNAB_DELIMITER)
        for row in data:
            csvWriter.writerow(row)

if __name__ == "__main__":
    main(sys.argv[1:])
