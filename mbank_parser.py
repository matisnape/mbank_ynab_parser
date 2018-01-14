import csv
import constants as c

class AccountParser:
    DATE_COL = 0
    OPIS_OPERACJI_COL = 1
    MEMO_COL = 2
    PAYEE_COL = 3
    NUMER_KONTA_COL = 4
    AMOUNT_COL = 5

    def __init__(self, input_csv):
        self.input_csv = input_csv

    def convert_csv(self, input_csv, ignore_param):

        with open(self.input_csv, 'r', encoding='cp1250') as csv_file:
            csvRows = csv_file.readlines()[38:-5]
            transactions_list = [c.YNAB_HEADERS]

            for row in csvRows:
                new_row = self.convert_row(row)

                if (ignore_param and
                    new_row[self.OPIS_OPERACJI_COL] == c.INTERNAL_INCOMING and
                    c.OWNER in new_row[self.PAYEE_COL]):
                    continue
                self.add_selected_cols_from_row_to_list(new_row, transactions_list)

            self.print_each_transaction_from(transactions_list)

            self.write_file_ynab(transactions_list, input_csv)

    def convert_row(self, row):
        new_row = row.split(';')[:-2]
        # remove Data księgowania
        new_row.pop(1)

        self.format_expense_amount(new_row)
        self.merge_accountid_with_memo(new_row)
        # REGULARNE OSZCZĘDZANIE
        self.rename_regularne_oszczedzanie(new_row, c.KONTO_REGULARNE)
        # Credit Card pay up
        self.rename_credit_payup(new_row, c.KARTA)
        # Kapitalizacja & Odsetki
        self.replace_other(new_row, c.KAPITALIZACJA)
        self.replace_other(new_row, c.PODATEK_ODSETKI)
        # if Payee empty, move Memo there
        self.populate_payee_if_empty(new_row)
        # transfer to accounts
        self.rename_internal_transfer(new_row, c.KONTO_1)
        self.rename_internal_transfer(new_row, c.KONTO_2)
        self.rename_internal_transfer(new_row, c.KONTO_3)

        return new_row

    def format_expense_amount(self, row):
        row[self.AMOUNT_COL] = row[self.AMOUNT_COL].replace(',', '.').replace(' ', '')

    def populate_payee_if_empty(self, row):
        if row[self.PAYEE_COL] == '"  "':
            row[self.PAYEE_COL] = row[self.MEMO_COL]
            row[self.MEMO_COL] = ''

    def merge_accountid_with_memo(self, row):
        if row[self.NUMER_KONTA_COL] != '':
            row[self.MEMO_COL] = row[self.MEMO_COL] + row[self.NUMER_KONTA_COL]

    def rename_internal_transfer(self, row, account):
        if c.INTERNAL_TRANSFER in row[self.OPIS_OPERACJI_COL] and (account["id"] in row[self.NUMER_KONTA_COL]):
            row[self.PAYEE_COL] = 'Transfer: {}'.format(account["name"])

    def rename_regularne_oszczedzanie(self, row, account):
        if c.KONTO_REGULARNE["id"] in row[self.OPIS_OPERACJI_COL]:
            row[self.PAYEE_COL] = 'Transfer: {}'.format(account["name"])

    def replace_other(self, row, word):
        if word in row[self.OPIS_OPERACJI_COL]:
            row[self.PAYEE_COL] = word.capitalize()

    def rename_credit_payup(self, row, card):
        if c.SPLATA_KART in row[self.OPIS_OPERACJI_COL] and card["id"] in row[self.MEMO_COL]:
            row[self.PAYEE_COL] = 'Transfer: {}'.format(card["name"])

    def write_file_ynab(self, data, new_csv):
        ynab_filename = c.YNAB_FILENAME_PREFIX + new_csv

        with open(ynab_filename, 'w', encoding='utf-8') as converted_file:
            csvWriter = csv.writer(converted_file, delimiter=c.YNAB_DELIMITER)
            for row in data:
                csvWriter.writerow(row)

    def add_selected_cols_from_row_to_list(self, row, listing):
        listing.append(
            [
                row[self.DATE_COL],
                row[self.MEMO_COL],
                row[self.PAYEE_COL],
                row[self.AMOUNT_COL]
            ]
        )


    def print_each_transaction_from(self, listing):
        for transaction in listing:
            print(transaction)
        print("Parsing complete")

class CreditCardParser(AccountParser):

    DATE_COL = 1
    MEMO_COL = 3
    PAYEE_COL = 4
    AMOUNT_COL = 7

    def __init__(self, input_csv):
        super().__init__(input_csv)

    def convert_csv(self, input_csv, ignore_param):

        with open(self.input_csv, 'r', encoding='cp1250') as csv_file:
            csvRows = csv_file.readlines()[34:-8]
            transactions_list = [c.YNAB_HEADERS]

            for row in csvRows:
                new_row = row.split(';')
                if len(new_row) == 9 and c.OPERATION_HEADER not in new_row[0]:
                    if (ignore_param and new_row[self.MEMO_COL] == c.REPAYMENT):
                        continue
                    self.format_expense_amount(new_row)
                    self.add_selected_cols_from_row_to_list(new_row, transactions_list)

            self.print_each_transaction_from(transactions_list)

            self.write_file_ynab(transactions_list, input_csv)
