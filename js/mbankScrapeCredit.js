/*
Disclaimers:
1. The script works for currently loaded transactions, so make sure to set the correct date range.
2. Supports only credit card history and only transactions that are already booked.
3. No data is saved by the script to third party locations
*/

class CreditHistoryScraper {

  transactions() {
    return Array.from(
      document.querySelectorAll("[data-original-title='Płatność kartą']"))
  }

  openTransactionDetails(transactionEl) {
    transactionEl.click();
  }

  saveDetailsForCSV(arr) {
    const MEMO_COL = this.getElementByXpath("//tr[th[contains(text(), 'Rodzaj operacji')]]/td").innerHTML;
    const AMOUNT_COL = this.getElementByXpath("//tr[th[contains(text(), 'Kwota w walucie rachunku')]]/td").innerHTML;
    const PAYEE_COL = this.getElementByXpath("//tr[th[contains(text(), 'Miejsce transakcji')]]/td").innerHTML;
    const DATE_COL = this.getElementByXpath("//tr[th[contains(text(), 'Data rozliczenia')]]/td").innerHTML;

    arr.push(
      [
        DATE_COL,
        MEMO_COL.replace(/,/g, ' '),
        PAYEE_COL.replace(/,/g, ' '),
        AMOUNT_COL.slice(0, -4).replace(/,/g, '.')
      ]
    );
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
    const arr = [['DATE','MEMO','PAYEE','AMOUNT']];
    // need to initialize transactions now
    const transactionsArr = this.transactions();

    for (let transactionEl of transactionsArr) {
      // 1. open each transaction to enable selectors
      this.openTransactionDetails(transactionEl);
      await this.wait(600);
      // 2. save data to arr
      this.saveDetailsForCSV(arr);
      await this.wait(1000);
    }
    await this.wait(1000);
    // 3. initialize CSV format and append content
    this.parseToCSVAndSaveFile(arr);
  }
}

const chs = new CreditHistoryScraper();
chs.start();
