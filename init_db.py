import sqlite3

# Conecta ou cria o banco
conn = sqlite3.connect('users.db')
c = conn.cursor()

# Cria a tabela
c.execute('''
CREATE TABLE IF NOT EXISTS users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    username TEXT UNIQUE NOT NULL,
    password TEXT NOT NULL
)
''')

conn.commit()
conn.close()

print("Banco de dados criado com sucesso!")
