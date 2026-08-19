import json
from pathlib import Path

import pandas as pd
import yfinance as yf

START = "2000-01-01"
TICKER = "^NSEI"
OUTPUT = Path("nifty50_history.json")


def main():
    data = yf.download(TICKER, start=START, auto_adjust=False, progress=False)
    if data.empty:
        raise RuntimeError("No Nifty 50 history was returned")

    close = data["Close"]
    if isinstance(close, pd.DataFrame):
        close = close.iloc[:, 0]

    history = {
        index.strftime("%Y-%m-%d"): float(value)
        for index, value in close.dropna().items()
    }
    if not history:
        raise RuntimeError("Nifty 50 history is empty after cleaning")

    OUTPUT.write_text(json.dumps(history, separators=(",", ":")), encoding="utf-8")
    print(f"Wrote {len(history)} Nifty 50 observations to {OUTPUT}")


if __name__ == "__main__":
    main()
