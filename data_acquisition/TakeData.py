# IMPORT LIBRERIE
import numpy as np
import matplotlib.pyplot as plt
import ta
from datetime import datetime, timedelta, UTC
import os
import time
from decimal import Decimal, ROUND_DOWN
from binance.client import Client
from binance.enums import SIDE_BUY, SIDE_SELL, ORDER_TYPE_MARKET
from pprint import pprint
import pandas as pd
import config
import yfinance as yf

start_str = config.start_str
end_str = config.end_str



        
def take_dataframe_crypto():
    global start_str, end_str

    try:
        df_old = pd.read_csv(config.filename, parse_dates=['Timestamp'], index_col='Timestamp')
        if not df_old.empty:
            return df_old
    except FileNotFoundError:
        pass  # File non esiste, scarica i dati
    
    # Scarica dati da Binance
    symbol = config.symbol
    tf = config.tf
    start_dt = datetime.strptime(start_str, "%d %b %Y %H:%M:%S")
    end_dt = datetime.strptime(end_str, "%d %b %Y %H:%M:%S")
    
    try:
        klines = config.client.get_historical_klines(
            symbol, tf,
            start_str=start_dt.strftime("%d %b %Y %H:%M:%S"),
            end_str=end_dt.strftime("%d %b %Y %H:%M:%S")
        )
    except Exception as e:
        print("❌ Errore scaricamento dati:", e)
        return pd.DataFrame()  # ✅ Ritorna DataFrame vuoto invece di None

    if not klines:
        print("⚠️ Nessun dato disponibile.")
        return pd.DataFrame()  # ✅ Ritorna DataFrame vuoto

    # Processa i dati...
    df_old = pd.DataFrame(klines, columns=['Timestamp', 'Open', 'High', 'Low', 'Close', 'Volume',
                                           'close_time', 'quote_av', 'trades', 'tb_base_av', 'tb_quote_av', 'ignore'])
    df_old['Timestamp'] = pd.to_datetime(df_old['Timestamp'], unit='ms')
    df_old.set_index('Timestamp', inplace=True)
    df_old.drop(['close_time', 'quote_av', 'trades', 'tb_base_av', 'tb_quote_av', 'ignore'], axis=1, inplace=True)
    df_old = df_old.astype('float64')
    df_old.replace(0, np.nan, inplace=True)
    df_old.dropna(inplace=True)
    df_old.to_csv(config.filename, index=True)
    print("✅ Dati caricati.")
    return df_old

def create_record_3OHLC(df):
    df_reset = df.reset_index()
    records = []
    
 # ✅ Parti da indice 2 (hai bisogno di i-2 valido)
    for i in range(2, len(df_reset)):
        record = {}
        
        record['Timestamp'] = df_reset.loc[i, 'Timestamp']
        
        # Loop per candela 1 (precedente) e candela 0 (corrente)
        for offset, suffix in [(1, 'prec'), (0, 'succ')]:
            idx = i - offset
            
            # Dati OHLCV
            record[f'Open_{suffix}'] = df_reset.loc[idx, 'Open']
            record[f'High_{suffix}'] = df_reset.loc[idx, 'High']
            record[f'Low_{suffix}'] = df_reset.loc[idx, 'Low']
            record[f'Close_{suffix}'] = df_reset.loc[idx, 'Close']
            record[f'Volume_{suffix}'] = df_reset.loc[idx, 'Volume']
            
            
        records.append(record)



    df_windowed = pd.DataFrame(records)

    # Rimuove eventuali colonne duplicate (stesso contenuto) nel range 8-18.
    # Questo evita di avere feature ridondanti nel dataset finale.
    cols = list(df_windowed.columns)
    dup_to_drop = []
    if len(cols) >= 18:
        target_cols = cols[7:18]  # colonne 8-18 (1-based)
        for c in target_cols:
            for prev in cols[:cols.index(c)]:
                if df_windowed[c].equals(df_windowed[prev]):
                    dup_to_drop.append(c)
                    break
    if dup_to_drop:
        df_windowed.drop(columns=dup_to_drop, inplace=True)
        print(f"⚠️ Colonne duplicate rimosse (8-18): {dup_to_drop}")

    print(f"Nuovo dataset: {len(df_windowed)} righe")
    print(f"Colonne: {df_windowed.columns.tolist()}\n")
    print("Prime 3 righe del nuovo dataset:")
    print(df_windowed.head(3))
    df_windowed.to_csv(config.output_filename, index=True)
    return df_windowed


import yfinance as yf
import pandas as pd
import numpy as np
from datetime import datetime
import yfinance as yf
import pandas as pd
import numpy as np
from datetime import datetime

def take_dataframe_forex(
    pair: str,
    start_date: str,
    end_date: str,
    interval: str = "1d",
    filename: str = None
) -> pd.DataFrame:
    """
    Scarica dati storici di una coppia Forex da Yahoo Finance.
    """
    
    # Se filename specificato, prova a caricare da file
    if filename:
        try:
            df_old = pd.read_csv(filename, parse_dates=['Timestamp'], index_col='Timestamp')
            if not df_old.empty:
                print(f"✅ Dati caricati da file: {filename}")
                return df_old
        except FileNotFoundError:
            pass
    
    ticker = f"{pair}=X"
    
    try:
        print(f"📥 Download {pair} da Yahoo Finance...")
        print(f"   Periodo: {start_date} -> {end_date}")
        print(f"   Intervallo: {interval}")
        
        ticker_obj = yf.Ticker(ticker)
        
        df = ticker_obj.history(
            start=start_date,
            end=end_date,
            interval=interval,
            auto_adjust=False,
            timeout=30
        )
        
        if df.empty:
            print(f"❌ Nessun dato disponibile per {pair}")
            return pd.DataFrame()
        
        # Gestisci multi-index
        if isinstance(df.columns, pd.MultiIndex):
            df.columns = df.columns.get_level_values(0)
        
        df.index.name = 'Timestamp'
        
        available_cols = df.columns.tolist()
        print(f"   Colonne ricevute: {available_cols}")
        
        # Seleziona colonne
        needed_cols = ['Open', 'High', 'Low', 'Close', 'Volume']
        df = df[[col for col in needed_cols if col in available_cols]]
        
        # Converti in float64
        df = df.astype('float64')
        
        # ✅ FIX: Per Forex, Volume è spesso 0 - NON rimuoverlo!
        # Sostituisci 0 con NaN SOLO nelle colonne di prezzo (non Volume)
        price_cols = ['Open', 'High', 'Low', 'Close']
        for col in price_cols:
            if col in df.columns:
                df[col].replace(0, np.nan, inplace=True)
        
        # Rimuovi righe dove i PREZZI sono NaN (non il Volume)
        df.dropna(subset=price_cols, inplace=True)
        
        # Se Volume è tutto 0, mettilo a NaN ma NON rimuovere le righe
        if 'Volume' in df.columns and (df['Volume'] == 0).all():
            print("   ⚠️ Volume non disponibile per Forex (normale)")
            df['Volume'] = np.nan
        
        if df.empty:
            print(f"❌ Nessun dato dopo pulizia")
            return pd.DataFrame()
        
        print(f"✅ Scaricate {len(df)} candele")
        print(f"   Range: {df.index.min()} -> {df.index.max()}")
        print(f"   Ultimo close: {df.iloc[-1]['Close']:.5f}")
        
        if filename:
            df.to_csv(filename, index=True)
            print(f"💾 Salvato in: {filename}")
        
        return df
        
    except Exception as e:
        print(f"❌ Errore durante download: {e}")
        import traceback
        traceback.print_exc()
        return pd.DataFrame()
        




def take_dataframe_stock(
    symbol: str,
    start_date: str,
    end_date: str,
    interval: str = "1d",
    filename: str = None
) -> pd.DataFrame:
    """
    Scarica dati storici di azioni da Yahoo Finance.
    
    Args:
        symbol: Simbolo azione ('AAPL', 'MSFT', 'TSLA', '^IXIC', etc.)
        start_date: Data inizio ('YYYY-MM-DD')
        end_date: Data fine ('YYYY-MM-DD')
        interval: Intervallo ('1m','5m','15m','1h','1d','1wk','1mo')
        filename: File CSV per cache
        
    Returns:
        DataFrame con Open, High, Low, Close, Volume
    """
    
    if filename:
        try:
            df = pd.read_csv(filename, parse_dates=['Timestamp'], index_col='Timestamp')
            if not df.empty:
                print(f"✅ Dati caricati da file: {filename}")
                return df
        except FileNotFoundError:
            pass
    
    try:
        print(f"📥 Download {symbol} da Yahoo Finance...")
        print(f"   Periodo: {start_date} -> {end_date}")
        print(f"   Intervallo: {interval}")
        
        # NON aggiungere =X (è solo per Forex)
        ticker_obj = yf.Ticker(symbol)
        
        df = ticker_obj.history(
            start=start_date,
            end=end_date,
            interval=interval,
            auto_adjust=False,
            timeout=30
        )
        
        if df.empty:
            print(f"❌ Nessun dato disponibile per {symbol}")
            return pd.DataFrame()
        
        if isinstance(df.columns, pd.MultiIndex):
            df.columns = df.columns.get_level_values(0)
        
        df.index.name = 'Timestamp'
        
        available_cols = df.columns.tolist()
        print(f"   Colonne ricevute: {available_cols}")
        
        needed_cols = ['Open', 'High', 'Low', 'Close', 'Volume']
        df = df[[col for col in needed_cols if col in available_cols]]
        
        df = df.astype('float64')
        
        # Pulisci prezzi (non Volume per azioni)
        price_cols = ['Open', 'High', 'Low', 'Close']
        for col in price_cols:
            if col in df.columns:
                df[col].replace(0, np.nan, inplace=True)
        
        df.dropna(subset=price_cols, inplace=True)
        
        # Arrotonda
        for col in price_cols:
            if col in df.columns:
                df[col] = df[col].round(2)  # 2 decimali per azioni (dollari e centesimi)
        
        if df.empty:
            print(f"❌ Nessun dato dopo pulizia")
            return pd.DataFrame()
        
        print(f"✅ {len(df)} candele scaricate")
        print(f"   Range: {df.index.min()} -> {df.index.max()}")
        print(f"   Ultimo close: ${df.iloc[-1]['Close']:.2f}")
        
        if filename:
            df.to_csv(filename, index=True)
            print(f"💾 Salvato in: {filename}")
        
        return df
        
    except Exception as e:
        print(f"❌ Errore: {e}")
        import traceback
        traceback.print_exc()
        return pd.DataFrame()