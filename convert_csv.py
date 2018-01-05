import csv
import sys
import getopt
import re
import constants

YNAB_HEADERS = constants.YNAB_HEADERS
REGULARNE = constants.REGULARNE
SPLATA_KART = constants.SPLATA_KART
KARTA = constants.KARTA
KAPITALIZACJA = constants.KAPITALIZACJA
PODATEK_ODSETKI = constants.PODATEK_ODSETKI
INTERNAL_TRANSFER = constants.INTERNAL_TRANSFER
INTERNAL_INCOMING = constants.INTERNAL_INCOMING
MBANK_DELIMITER = constants.MBANK_DELIMITER
OWNER = constants.OWNER
KONTO_1 = constants.KONTO_1
KONTO_2 = constants.KONTO_2
KONTO_3 = constants.KONTO_3

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
    convert_csv(input_file, output_file)

def convert_csv(input_csv, new_csv):
    with open(input_csv, 'r', encoding='cp1250') as csv_file:
        csvRows = csv_file.readlines()[38:-5]
        transactions_list = [YNAB_HEADERS]
        for row in csvRows:
            new_row = row.split(MBANK_DELIMITER)
            new_row = new_row[:-2]
            new_row[6] = (new_row[6][:-3] + '.' + new_row[6][-2:]).replace(' ', '')
            # remove Data księgowania
            new_row.pop(1)
            # merge Numer konta with Memo
            if new_row[4] != '':
                new_row[2] = new_row[2] + new_row[4]
            # REGULARNE OSZCZĘDZANIE
            if REGULARNE in new_row[1]:
                new_row[3] = 'Transfer: Regularne Oszczedzanie'
            # Credit Card pay up
            if SPLATA_KART in new_row[1] and KARTA in new_row[2]:
                new_row[3] = 'Transfer: Kredytowka'
            # Kapitalizacja & Odsetki
            if KAPITALIZACJA in new_row[1]:
                new_row[3] = 'Kapitalizacja'
            if PODATEK_ODSETKI in new_row[1]:
                new_row[3] = 'Odsetki'
            # if Payee empty, move Memo there
            if new_row[3] == '"  "':
                new_row[3] = new_row[2]
                new_row[2] = ''
            # make strings prettier
            for item in new_row:
                item = re.sub('["\']', '', item)
            # print(new_row)
            transactions_list.append(new_row)
        write_file(transactions_list, new_csv)
        # convert for YNAB
        ynab_transactions = []
        for row in transactions_list:
            row = [row[0], row[3], row[2], row[5]]
            ynab_transactions.append(row)
            print(row)
        write_file_ynab(ynab_transactions, new_csv)

def write_file(data, new_csv):
    YNAB_DELIMITER = ';'

    with open(new_csv, 'w', encoding='utf-8') as converted_file:
        csvWriter = csv.writer(converted_file, delimiter=YNAB_DELIMITER)
        for row in data:
            csvWriter.writerow(row)

def write_file_ynab(data, new_csv):
    YNAB_DELIMITER = ','
    YNAB_FILE = 'YNABready_' + new_csv

    with open(YNAB_FILE, 'w', encoding='utf-8') as converted_file:
        csvWriter = csv.writer(converted_file, delimiter=YNAB_DELIMITER)
        for row in data:
            csvWriter.writerow(row)

if __name__ == "__main__":
    main(sys.argv[1:])
