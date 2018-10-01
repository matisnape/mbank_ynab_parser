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

  getTransaction() {
    const MEMO_COL = this.getElementByXpath("//tr[th[contains(text(), 'Rodzaj operacji')]]/td").innerHTML;

    if (MEMO_COL == "PRZELEW REGULARNE OSZCZĘDZANIE") {
      return new RegularneOszczedzanie();
    }
    else if (MEMO_COL == "ZAKUP PRZY UŻYCIU KARTY") {
      return new ZakupKarta();
    }
    else if (MEMO_COL.includes("SPŁATA KARTY")) {
      return new SplataKarty();
    }
    else if (MEMO_COL == "PRZELEW WŁASNY") {
      return new PrzelewWlasny();
    }
    else if (MEMO_COL.includes("PROWIZJA")) {
      return new Prowizja();
    }
    else if (MEMO_COL.includes("MTRANSFER")) {
      return new Mtransfer;
    }
    else if (MEMO_COL.includes("BLIK - ZAKUP")) {
      return new Blik();
    }
    else if (MEMO_COL.includes("PRZYCHODZĄCY")) {
      return new PrzelewPrzychodzacy();
    }
    else if (MEMO_COL.includes("WYCHODZĄCY") && ! MEMO_COL.includes("MTRANSFER") ) {
      return new PrzelewWychodzacy();
    }
    else if (MEMO_COL.includes("MOKAZJE")) {
      return new Mokazje();
    }
    else if (MEMO_COL.includes("PODATEK")) {
      return new Podatek();
    }
    else if (MEMO_COL.includes("KAPITALIZACJA")) {
      return new Kapitalizacja();
    }
    else if (MEMO_COL.includes("WYPŁATA")) {
      return new Wyplata();
    }
    else if (MEMO_COL.includes("WPŁATA")) {
      return new Wplata();
    }
    else {
      this.n+=1;
      console.log(this.n + ". Didn't recognize: " + MEMO_COL);
      return "Undefined";
    }
  }

  saveDetailsForCSV(arr) {
    arr.push(this.getTransaction().toArray());
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
    return [
      this.date_col,
      this.memo_col.replace(/,/g, " "),
      this.payee_col.replace(/,/g, " "),
      this.amount_col.slice(0, -4).replace(/,/g, ".")
    ];
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
    return [
      this.date_col,
      "",
      this.payee_col,
      "-" + this.amount_col.slice(0, -4).replace(/,/g, ".")
    ];
  }
}

class ZakupKarta extends Transakcja {
  get payee_col() {
    return this.getElementByXpath("//tr[th[contains(text(), 'Nazwa odbiorcy')]]/td").innerHTML;
  }
  get date_col() {
    return this.getElementByXpath("//tr[th[contains(text(), 'Data rozliczenia')]]/td").innerHTML;
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
    return [
      this.date_col,
      "",
      this.payee_col,
      "-" + this.amount_col.slice(0, -4).replace(/,/g, ".")
    ];
  }
}

class PrzelewWlasny extends Transakcja {
  get odbiorca() {
    let rachunek_odbiorcy = this.getElementByXpath("//tr[th[contains(text(), 'Rachunek odbiorcy')]]/td").innerHTML;
    switch(rachunek_odbiorcy) {
      case emax:
        return "emax";
      case emaxplus:
        return "emaxplus";
      case ekonto:
        return "ekonto";
    }
    return "undefined odbiorca";
  }
  get payee_col() {
    return "Transfer: " + this.odbiorca;
  }
  get date_col() {
    return this.getElementByXpath("//tr[th[contains(text(), 'Data księgowania')]]/td").innerHTML;
  }

  toArray() {
    return [
      this.date_col,
      this.memo_col.replace(/,/g, " "),
      this.payee_col,
      "-" + this.amount_col.slice(0, -4).replace(/,/g, ".")
    ];
  }
}
class Prowizja extends Transakcja {
  get date_col() {
    return this.getElementByXpath("//tr[th[contains(text(), 'Data rozliczenia')]]/td").innerHTML;
  }

  toArray() {
    return [
      this.date_col,
      "",
      this.memo_col.replace(/,/g, " "),
      this.amount_col.slice(0, -4).replace(/,/g, ".")
    ];
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
    return [
      this.date_col,
      this.memo_col.replace(/,/g, " "),
      this.payee_col.replace(/,/g, " "),
      "-" + this.amount_col.slice(0, -4).replace(/,/g, ".")
    ];
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
  get payee_col() {
    let rachunek_odbiorcy = this.getElementByXpath("//tr[th[contains(text(), 'Nazwa odbiorcy')]]/td").innerHTML;
    if (rachunek_odbiorcy == lokaty) {
      return "Transfer to: Lokaty";
    }
    return rachunek_odbiorcy;
  }
  get memo_col() {
    return this.getElementByXpath("//tr[th[contains(text(), 'Tytuł przelewu')]]/td").innerHTML;
  }
  get rachunek_odbiorcy() {
    return this.getElementByXpath("//tr[th[contains(text(), 'Rachunek odbiorcy')]]/td").innerHTML;
  }

  toArray() {
    return [
      this.date_col,
      this.memo_col.replace(/,/g, " "),
      this.payee_col.replace(/,/g, " "),
      "-" + this.amount_col.slice(0, -4).replace(/,/g, ".")
    ];
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
    let rachunek_nadawcy = this.getElementByXpath("//tr[th[contains(text(), 'Rachunek nadawcy')]]/td").innerHTML;
    if (! [emax, ekonto, emaxplus].includes(rachunek_nadawcy) ) {
      return rachunek_nadawcy;
    }
    return console.log("Ignored incoming from own account: " + this.amount_col + " (" + this.date_col + ")");
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

  toArray() {
    return [
      this.date_col,
      this.memo_col.replace(/,/g, " "),
      this.payee_col.replace(/,/g, " "),
      "-" + this.amount_col.slice(0, -4).replace(/,/g, ".")
    ];
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



