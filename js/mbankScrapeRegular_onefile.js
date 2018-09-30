/*
Disclaimers:
1. The script works for currently loaded transactions, so make sure to set the correct date range.
2. Supports only regular account history and only transactions that are already booked.
3. No data is saved by the script to third party locations
*/

const i = document.createElement("iframe");
i.style.display = "none";
document.body.appendChild(i);
window.console = i.contentWindow.console;

const emax = "";
const emaxplus = "";
const ekonto = "";
const lokaty = "";

class AccountHistoryScraper {
  constructor() {
    this.n = 0;
  }

  transactions() {
    return Array.from(
      document.querySelectorAll("span.content-list-type-icon:not([data-original-title='Nierozliczone'])"));
  }

  openTransactionDetails(transactionEl) {
    transactionEl.click();
  }

  saveDetailsForCSV(arr) {
    const MEMO_COL = this.getElementByXpath("//tr[th[contains(text(), 'Rodzaj operacji')]]/td").innerHTML;
    if (MEMO_COL == "PRZELEW REGULARNE OSZCZĘDZANIE") {
      arr.push(
        [
          regularne.toArray()
        ]
      );
    }
    else if (MEMO_COL == "ZAKUP PRZY UŻYCIU KARTY") {
      arr.push(
        [
          karta.toArray()
        ]
      );
    }
    else if (MEMO_COL.includes("SPŁATA KARTY")) {
      arr.push(
        [
          splatakarty.toArray()
        ]
      );
    }
    else if (MEMO_COL == "PRZELEW WŁASNY") {
      let account;
      switch(przelewwlasny.odbiorca) {
        case emax:
          account = "emax";
          break;
        case emaxplus:
          account = "emaxplus";
          break;
        case ekonto:
          account = "ekonto";
          break;
      }
      arr.push(
        [
          przelewwlasny.toArray(account)
        ]
      );
    }
    else if (MEMO_COL.includes("PROWIZJA")) {
      arr.push(
        [
          prowizja.toArray()
        ]
      );
    }
    else if (MEMO_COL.includes("MTRANSFER")) {
      arr.push(
        [
          mtransfer.toArray()
        ]
      );
    }
    else if (MEMO_COL.includes("BLIK - ZAKUP")) {
      arr.push(
        [
          blik.toArray()
        ]
      );
    }
    else if (MEMO_COL.includes("PRZYCHODZĄCY")) {
      // ignore incoming from own accounts
      if (! [emax, ekonto, emaxplus].includes(incoming.nadawca) ) {
        arr.push(
          [
            incoming.toArray()
          ]
        );
      } else {
        console.log("Ignored incoming from own account: " + incoming.amount_col + " (" + incoming.date_col + ")");
      }
    }
    else if (MEMO_COL.includes("WYCHODZĄCY") && ! MEMO_COL.includes("MTRANSFER") ) {
      if (outgoing.rachunek_odbiorcy == lokaty) {
        outgoing.payee_col = "Transfer to: Lokaty";
      }
      arr.push(
        [
          outgoing.toArray()
        ]
      );
    }
    else if (MEMO_COL.includes("MOKAZJE")) {
      arr.push(
        [
          mokazje.toArray()
        ]
      );
    }
    else if (MEMO_COL.includes("PODATEK")) {
      arr.push(
        [
          podatek.date_col,
          podatek.memo_col.replace(/,/g, " "),
          podatek.payee_col.replace(/,/g, " "),
          "-" + podatek.amount_col.slice(0, -4).replace(/,/g, ".")
        ]
      );
    }
    else if (MEMO_COL.includes("KAPITALIZACJA")) {
      arr.push(
        [
          kapitalizacja.date_col,
          kapitalizacja.memo_col.replace(/,/g, " "),
          kapitalizacja.payee_col,
          kapitalizacja.amount_col.slice(0, -4).replace(/,/g, ".")
        ]
      );
    }
    else if (MEMO_COL.includes("WYPŁATA")) {
      arr.push(
        [
          wyplata.date_col,
          wyplata.memo_col.replace(/,/g, " "),
          wyplata.payee_col,
          wyplata.amount_col.slice(0, -4).replace(/,/g, ".")
        ]
      );
    }
    else if (MEMO_COL.includes("WPŁATA")) {
      arr.push(
        [
          wplata.date_col,
          wplata.memo_col.replace(/,/g, " "),
          wplata.payee_col,
          wplata.amount_col.slice(0, -4).replace(/,/g, ".")
        ]
      );
    }
    else {
      this.n+=1;
      console.log(this.n + ". Didn't recognize: " + MEMO_COL);
    }
  }

  parseToCSVAndSaveFile(arr) {
    let csvContent = "data:text/csv;charset=utf-8,";
    arr.forEach(function(rowArray){
      let row = rowArray.join(",");
      csvContent += row + "\r\n";
    });
    let encodedUri = encodeURI(csvContent);
    const link = document.createElement("a");
    link.setAttribute("href", encodedUri);
    link.setAttribute("download", "YNAB_ready" + Date.now() + ".csv");
    link.click();
  }

  wait(ms) {
    return new Promise((resolve) => setTimeout(resolve, ms));
  }

  getElementByXpath(path) {
    return document.evaluate(path, document, null, XPathResult.FIRST_ORDERED_NODE_TYPE, null).singleNodeValue;
  }

  async start() {
    const arr = [["DATE","MEMO","PAYEE","AMOUNT"]];
    // need to initialize transactions now
    const transactionsArr = this.transactions();

    for (let transactionEl of transactionsArr) {
      // 1. open each transaction to enable selectors
      this.openTransactionDetails(transactionEl);
      await this.wait(5000);
      // 2. save data to arr
      this.saveDetailsForCSV(arr);
      await this.wait(1200);
    }
    await this.wait(1200);
    // 3. initialize CSV format and append content
    this.parseToCSVAndSaveFile(arr);
    console.log("Number of rows in CSV: " + (arr.length - 1));
  }
}

class Transakcja {
  get date_col() {
    return this.getElementByXpath("//tr[th[contains(text(), 'Data operacji')]]/td").innerHTML;
  }
  get amount_col() {
    return this.getElementByXpath("//tr[th[contains(text(), 'Kwota w walucie rachunku') or contains(text(), 'Kwota operacji')]]/td").innerHTML;
  }
  get memo_col() {
    return this.getElementByXpath("//tr[th[contains(text(), 'Rodzaj operacji')]]/td").innerHTML;
  }
  get payee_col() {
    return this.getElementByXpath("//tr[th[contains(text(), 'Nazwa odbiorcy')]]/td").innerHTML;
  }

  getElementByXpath(path) {
    return document.evaluate(path, document, null, XPathResult.FIRST_ORDERED_NODE_TYPE, null).singleNodeValue;
  }

  toArray() {
    this.date_col,
    this.memo_col.replace(/,/g, " "),
    this.payee_col.replace(/,/g, " "),
    this.amount_col.slice(0, -4).replace(/,/g, ".");
  }
}

class RegularneOszczedzanie extends Transakcja {
  get payee_col() {
    return "Transfer: Regularne Oszczedzanie";
  }
  get date_col() {
    return this.getElementByXpath("//tr[th[contains(text(), 'Data księgowania')]]/td").innerHTML;
  }

  toArray() {
    this.date_col,
    "",
    this.payee_col,
    "-" + this.amount_col.slice(0, -4).replace(/,/g, ".");
  }
}

class ZakupKarta extends Transakcja {
  get payee_col() {
    return this.getElementByXpath("//tr[th[contains(text(), 'Nazwa odbiorcy')]]/td").innerHTML;
  }
  get date_col() {
    return this.getElementByXpath("//tr[th[contains(text(), 'Data rozliczenia')]]/td").innerHTML;
  }

  toArray() {
    this.date_col,
    this.memo_col.replace(/,/g, " "),
    this.payee_col.replace(/,/g, " "),
    this.amount_col.slice(0, -4).replace(/,/g, ".");
  }
}

class SplataKarty extends Transakcja {
  get payee_col() {
    return "Payment: kredytówka";
  }
  get date_col() {
    return this.getElementByXpath("//tr[th[contains(text(), 'Data księgowania')]]/td").innerHTML;
  }

  toArray() {
    this.date_col,
    "",
    this.payee_col,
    "-" + this.amount_col.slice(0, -4).replace(/,/g, ".");
  }
}

class PrzelewWlasny extends Transakcja {
  get odbiorca() {
    return this.getElementByXpath("//tr[th[contains(text(), 'Rachunek odbiorcy')]]/td").innerHTML;
  }
  payee_col(account) {
    return "Transfer: " + account;
  }
  get date_col() {
    return this.getElementByXpath("//tr[th[contains(text(), 'Data księgowania')]]/td").innerHTML;
  }

  toArray(account) {
    this.date_col,
    this.memo_col.replace(/,/g, " "),
    this.payee_col(account),
    "-" + this.amount_col.slice(0, -4).replace(/,/g, ".");
  }
}
class Prowizja extends Transakcja {
  get date_col() {
    return this.getElementByXpath("//tr[th[contains(text(), 'Data rozliczenia')]]/td").innerHTML;
  }

  toArray() {
    this.date_col,
    "",
    this.memo_col.replace(/,/g, " "),
    this.amount_col.slice(0, -4).replace(/,/g, ".");
  }
}
class Mtransfer extends Transakcja {
  get date_col() {
    return this.getElementByXpath("//tr[th[contains(text(), 'Data księgowania')]]/td").innerHTML;
  }
  get payee_col() {
    return this.getElementByXpath("//tr[th[contains(text(), 'Nazwa odbiorcy')]]/td").innerHTML;
  }
  get memo_col() {
    return this.getElementByXpath("//tr[th[contains(text(), 'Tytuł przelewu')]]/td").innerHTML;
  }

  toArray() {
    this.date_col,
    this.memo_col.replace(/,/g, " "),
    this.payee_col.replace(/,/g, " "),
    "-" + this.amount_col.slice(0, -4).replace(/,/g, ".");
  }
}
class Blik extends Transakcja {
  get payee_col() {
    return this.getElementByXpath("//tr[th[contains(text(), 'Nazwa sklepu internetowego')]]/td").innerHTML;
  }
  get memo_col() {
    return "Blik: " + this.getElementByXpath("//tr[th[contains(text(), 'Nr operacji BLIK')]]/td").innerHTML;
  }
}
class PrzelewWychodzacy extends Transakcja {
  get date_col() {
    return this.getElementByXpath("//tr[th[contains(text(), 'Data księgowania')]]/td").innerHTML;
  }
  payee_col() {
    return this.getElementByXpath("//tr[th[contains(text(), 'Nazwa odbiorcy')]]/td").innerHTML;
  }
  get memo_col() {
    return this.getElementByXpath("//tr[th[contains(text(), 'Tytuł przelewu')]]/td").innerHTML;
  }
  get rachunek_odbiorcy() {
    return this.getElementByXpath("//tr[th[contains(text(), 'Rachunek odbiorcy')]]/td").innerHTML;
  }

  toArray() {
    this.date_col,
    this.memo_col.replace(/,/g, " "),
    this.payee_col().replace(/,/g, " "),
    "-" + this.amount_col.slice(0, -4).replace(/,/g, ".");
  }
}
class PrzelewPrzychodzacy extends Transakcja {
  get payee_col() {
    return this.getElementByXpath("//tr[th[contains(text(), 'Nazwa nadawcy')]]/td").innerHTML;
  }
  get memo_col() {
    return this.getElementByXpath("//tr[th[contains(text(), 'Tytuł przelewu')]]/td").innerHTML;
  }
  get nadawca() {
    return this.getElementByXpath("//tr[th[contains(text(), 'Rachunek nadawcy')]]/td").innerHTML;
  }
}
class Mokazje extends Transakcja {
  get payee_col() {
    return "Mokazje";
  }
  get memo_col() {
    return this.getElementByXpath("//tr[th[contains(text(), 'Tytuł transakcji')]]/td").innerHTML;
  }
}
class Podatek extends Transakcja {
  get payee_col() {
    return "Podatek od odsetek";
  }
}
class Kapitalizacja extends Transakcja {
  get payee_col() {
    return "Kapitalizacja odsetek";
  }
}
class Wyplata extends Transakcja {
  get payee_col() {
    return "Transfer: Gotówka";
  }
}
class Wplata extends Transakcja {
  get date_col() {
    return this.getElementByXpath("//tr[th[contains(text(), 'Data księgowania')]]/td").innerHTML;
  }
  get payee_col() {
    return "Transfer: Gotówka";
  }
}

  const karta = new ZakupKarta();
  const regularne = new RegularneOszczedzanie();
  const splatakarty = new SplataKarty();
  const przelewwlasny = new PrzelewWlasny();
  const prowizja = new Prowizja();
  const mtransfer = new Mtransfer();
  const blik = new Blik();
  const incoming = new PrzelewPrzychodzacy();
  const outgoing = new PrzelewWychodzacy();
  const mokazje = new Mokazje();
  const podatek = new Podatek();
  const kapitalizacja = new Kapitalizacja();
  const wplata = new Wplata();
  const wyplata = new Wyplata();
  const ahs = new AccountHistoryScraper();
  ahs.start();

// WYPŁATA W BANKOMACIE
// WPŁATA WE WPŁATOMACIE
// PRZELEW WŁASNY
// ZAKUP PRZY UŻYCIU KARTY
// RĘCZNA SPŁATA KARTY KREDYT.
// PROWIZJA
// PRZELEW MTRANSFER WYCHODZACY
// BLIK
// PRZELEW WEWNĘTRZNY PRZYCHODZĄCY
// PRZELEW ZEWNĘTRZNY PRZYCHODZĄCY
// PRZELEW WEWNĘTRZNY WYCHODZĄCY
// PRZELEW ZEWNĘTRZNY WYCHODZĄCY
// MOKAZJE UZNANIE
// PODATEK OD ODSETEK KAPITAŁOWYCH
// KAPITALIZACJA ODSETEK



