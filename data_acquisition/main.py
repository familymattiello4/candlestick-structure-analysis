import numpy as np
import pandas as pd
import TakeData
import config
from TakeData import take_dataframe_forex, take_dataframe_crypto, take_dataframe_stock



# mainBack.py - AGGIUNGI CONTROLLI
df_all = take_dataframe_crypto()
#df_all = take_dataframe_forex('GBPUSD', '2025-10-05', '2025-10-20', '15m').round(5)
#df_all = take_dataframe_stock('AAPL', '2025-12-05', '2025-12-20', '15m').round(5)
#df_all = take_dataframe_stock('^NDX', '2026-01-05', '2026-01-06', '1m').round(5)

# ✅ AGGIUNGI QUESTO CONTROLLO
if df_all is None or df_all.empty:
    print("❌ Impossibile caricare i dati. Uscita.")
    exit(1)

records = TakeData.create_record_3OHLC(df_all)

# ✅ AGGIUNGI QUESTO CONTROLLO
if records.empty:
    print("❌ Nessun record generato. Uscita.")
    exit(1)






