# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This repository contains parsers for converting Polish bank CSV files (mBank and ING) into YNAB-compatible format. The main implementation is in Elixir with legacy Python support.

## Commands

### Setup (First Time)
1. **Initial configuration**: `elixir setup.exs` (interactive wizard)
2. **Manual setup**: `cp config.template.json config.json` (then edit config.json)

### Elixir Scripts
- **Primary parser (supports mBank and ING)**: `elixir bank_parser.exs <path_to_csv_file>`
- **Deprecated mBank-only parser**: `elixir mbank_parser.exs <path_to_csv_file>`

### Python (deprecated)
- **Setup**: `cp constants.template.py constants.py` (then edit constants.py)
- **Run parser**: `python3 convert_csv.py <path_to_csv_file>`
- **Options**: `-c` for credit card files, `-ii` to ignore internal transactions

## Architecture

### Core Components

**BankParser** (`bank_parser.exs`) - Main parser module:
- Detects bank type automatically (mBank or ING) from file headers
- Handles encoding conversion from Windows-1250 to UTF-8 using `:iconv`
- Processes different CSV formats and metadata structures per bank
- Maps internal account transfers using configurable account definitions
- Outputs CSV files prefixed with `eYNAB_ready_`

**Key Processing Steps**:
1. Bank detection from file headers
2. Metadata removal (different row counts per bank)
3. Transaction parsing and field mapping
4. Internal transfer recognition and account mapping
5. YNAB format conversion

### Account Configuration

**Current (JSON-based)**:
- Configuration stored in `config.json` (created from `config.template.json`)
- Supports account mapping for internal transfers
- Interactive setup wizard available via `elixir setup.exs`
- Validation ensures all required fields are present
- Settings include output prefix and balance column inclusion

**Configuration structure**:
```json
{
  "accounts": [
    {
      "id": "account_identifier_from_csv",
      "name": "YNAB Account Name",
      "description": "Optional description"
    }
  ],
  "settings": {
    "output_prefix": "eYNAB_ready_",
    "include_balance": true,
    "date_format": "YYYY-MM-DD"
  }
}
```

**Legacy (hardcoded)**:
- Deprecated: mbank_parser.exs uses hardcoded `accounts/0` function

### File Structure

- `bank_parser.exs` - Current multi-bank parser (uses config.json)
- `setup.exs` - Interactive configuration wizard
- `config.template.json` - Configuration template
- `mbank_parser.exs` - Deprecated mBank-only parser  
- `convert_csv.py` - Deprecated Python implementation
- `constants.template.py` - Template for Python account configuration

### Dependencies

**Elixir**: Uses `Mix.install` for dependency management
- `:csv` for CSV processing
- `:iconv` for Windows-1250 to UTF-8 encoding conversion
- `:jason` for JSON configuration parsing

**Python**: Standard library with custom parser classes in `mbank_parser.py`