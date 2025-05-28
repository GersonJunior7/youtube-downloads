from flask import Flask, render_template, request, send_file, redirect, url_for, flash, session
from yt_dlp import YoutubeDL
from werkzeug.security import generate_password_hash, check_password_hash
import sqlite3
import os
import uuid
import threading

app = Flask(__name__)
app.secret_key = 'sua-chave-secreta'

# Pasta de downloads
DOWNLOAD_FOLDER = 'downloads'
os.makedirs(DOWNLOAD_FOLDER, exist_ok=True)

# Status dos downloads
download_status = {}

# Conexão com o banco
def get_db_connection():
    conn = sqlite3.connect('users.db')
    conn.row_factory = sqlite3.Row
    return conn

# Download do vídeo
def download_video(url, format_type, filename):
    output_path = os.path.join(DOWNLOAD_FOLDER, f'{filename}.%(ext)s')

    ydl_opts = {'outtmpl': output_path}

    if format_type == 'mp3':
        ydl_opts.update({
            'format': 'bestaudio/best',
            'postprocessors': [{
                'key': 'FFmpegExtractAudio',
                'preferredcodec': 'mp3',
                'preferredquality': '192',
            }],
            'quiet': True,
        })
    else:
        ydl_opts.update({
            'format': 'bestvideo+bestaudio/best',
            'quiet': True,
            'merge_output_format': 'mp4',
        })

    try:
        with YoutubeDL(ydl_opts) as ydl:
            ydl.extract_info(url, download=True)
        download_status[filename] = 'done'
    except Exception as e:
        download_status[filename] = f'error: {str(e)}'

# Página inicial (requer login)
@app.route('/', methods=['GET', 'POST'])
def index():
    if 'user' not in session:
        return redirect(url_for('login'))

    if request.method == 'POST':
        url = request.form['url']
        format_type = request.form['format']
        filename = str(uuid.uuid4())

        download_status[filename] = 'pending'
        thread = threading.Thread(target=download_video, args=(url, format_type, filename))
        thread.start()

        flash('Download iniciado. Atualize esta página para ver quando estiver pronto.', 'info')
        return redirect(url_for('status', filename=filename, format=format_type))

    return render_template('index.html')

# Página de status
@app.route('/status/<filename>')
def status(filename):
    stat = download_status.get(filename, 'unknown')
    format = request.args.get('format', 'mp4')

    if stat == 'done':
        ext = 'mp3' if format == 'mp3' else 'mp4'
        file_path = os.path.join(DOWNLOAD_FOLDER, f"{filename}.{ext}")
        if os.path.exists(file_path):
            return send_file(file_path, as_attachment=True)
        else:
            return "Arquivo não encontrado.", 404
    else:
        return render_template("status.html", status=stat, filename=filename, format=format)

# Registro de usuário
@app.route('/register', methods=['GET', 'POST'])
def register():
    if request.method == 'POST':
        username = request.form['username']
        password = request.form['password']

        hashed_pw = generate_password_hash(password)

        conn = get_db_connection()
        try:
            conn.execute('INSERT INTO users (username, password) VALUES (?, ?)', (username, hashed_pw))
            conn.commit()
            flash('Registro realizado com sucesso! Faça login.', 'success')
            return redirect(url_for('login'))
        except sqlite3.IntegrityError:
            flash('Usuário já existe!', 'error')
        finally:
            conn.close()

    return render_template('register.html')

# Login de usuário
@app.route('/login', methods=['GET', 'POST'])
def login():
    if request.method == 'POST':
        username = request.form['username']
        password = request.form['password']

        conn = get_db_connection()
        user = conn.execute('SELECT * FROM users WHERE username = ?', (username,)).fetchone()
        conn.close()

        if user and check_password_hash(user['password'], password):
            session['user'] = username
            flash('Login realizado com sucesso!', 'success')
            return redirect(url_for('index'))
        else:
            flash('Usuário ou senha inválidos.', 'error')

    return render_template('login.html')

# Logout
@app.route('/logout')
def logout():
    session.pop('user', None)
    flash('Você saiu da sua conta.', 'info')
    return redirect(url_for('login'))

if __name__ == '__main__':
    app.run(debug=True)
