HEADERS = [
    'DATE', '#Opis operacji', 'MEMO', 'PAYEE', '#Numer konta', 'AMOUNT'
    ]
YNAB_HEADERS = ['DATE', 'MEMO', 'PAYEE', 'AMOUNT']
YNAB_FILENAME_PREFIX = 'YNAB_ready_'
YNAB_DELIMITER = ','

REGULARNE = 'PRZELEW REGULARNE OSZCZ'
SPLATA_KART = 'ATA KARTY KREDYT.'
KAPITALIZACJA = 'KAPITALIZACJA ODSETEK'
PODATEK_ODSETKI = 'PODATEK OD ODSETEK KAPIT'
INTERNAL_TRANSFER = 'PRZELEW WŁASNY'
MBANK_DELIMITER = ';'

# add your own for additional rules
KONTO_1 = {"id": '11111111111111111111111111', "name": 'konto1'}
KONTO_2 = {"id": '11111111111111111111111111', "name": 'konto2'}
KONTO_3 = {"id": '11111111111111111111111111', "name": 'konto3'}
KARTA = {"id": 'KARTA VISA CLASSIC CREDIT', "name": 'karta kredytowaK'}
