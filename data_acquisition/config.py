from binance.client import Client
import pandas as pd
# configBack.py - CORRETTO



# Inizializza client
client = Client()  # ✅ AGGIUNGI QUESTA RIGA

symbol = "BTCUSDT"
tf = Client.KLINE_INTERVAL_5MINUTE
filename = "solusdt_1h.csv"
output_filename = "dataset_start_BTCUSDT.csv"
start_str = "1 Dec 2025 19:00:00" 
end_str = "7 Dec 2025 17:00:00"