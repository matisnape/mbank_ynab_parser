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
INTERNAL_INCOMING = 'PRZELEW WEWNĘTRZNY PRZYCHODZĄCY'

REPAYMENT = 'SPŁATA - PRZELEW WEWNĘTRZNY - DZIĘKUJEMY'
OPERATION_HEADER = '#Nr oper.'

MBANK_DELIMITER = ';'
OWNER = 'your name on you accounts'

# add your own for additional rules
KONTO_1 = {"id": '11111111111111111111111111', "name": 'konto1'}
KONTO_2 = {"id": '11111111111111111111111111', "name": 'konto2'}
KONTO_3 = {"id": '11111111111111111111111111', "name": 'konto3'}
KONTO_REGULARNE = {"id": 'PRZELEW NA TWOJE CELE', "name": 'Regularne Oszczędzanie'}
KARTA = {"id": 'KARTA VISA CLASSIC CREDIT', "name": 'karta kredytowaK'}
