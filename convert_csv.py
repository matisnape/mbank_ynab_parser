import csv
import sys
import getopt

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
    headers = [
        '#Data operacji', '#Opis operacji', '#Tytuł', '#Nadawca/Odbiorca', '#Numer konta', '#Kwota'
    ]

    with open(input_csv, 'r', encoding='cp1250') as csv_file:
        csvRows = csv_file.readlines()[38:-5]
        transactions_list = []
        for row in csvRows:
            new_row = row.split(';')
            new_row = new_row[:-2]
            new_row[6] = (new_row[6][:-3] + '.' + new_row[6][-2:]).replace(' ', '')
            new_row.pop(1)
            transactions_list.append(new_row)
        transactions_list.insert(0, headers)
        write_file(transactions_list, new_csv)

def write_file(data, new_csv):
    with open(new_csv, 'w', encoding='cp1250') as converted_file:
        csvWriter = csv.writer(converted_file, delimiter=';')
        for row in data:
            csvWriter.writerow(row)

if __name__ == "__main__":
    main(sys.argv[1:])
