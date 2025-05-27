from flask import Flask, render_template, request, send_file, redirect, url_for, flash
from yt_dlp import YoutubeDL
import os
import uuid
import threading
import time

app = Flask(__name__)
app.secret_key = 'sua-chave-secreta'  # necessário para flash messages

DOWNLOAD_FOLDER = 'downloads'
os.makedirs(DOWNLOAD_FOLDER, exist_ok=True)

# Dicionário para guardar o status dos downloads: filename -> 'pending'|'done'|'error'
download_status = {}

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

@app.route('/', methods=['GET', 'POST'])
def index():
    if request.method == 'POST':
        url = request.form['url']
        format_type = request.form['format']
        filename = str(uuid.uuid4())

        # Marca o download como pendente
        download_status[filename] = 'pending'

        # Dispara a thread para o download
        thread = threading.Thread(target=download_video, args=(url, format_type, filename))
        thread.start()

        flash('Download iniciado. Atualize esta página para ver quando estiver pronto.')
        return redirect(url_for('status', filename=filename, format=format_type))

    return render_template('index.html')


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
    elif stat.startswith('error') or stat == 'pending' or stat == 'unknown':
        return render_template("status.html", status=stat, filename=filename, format=format)

if __name__ == '__main__':
    app.run(debug=True)
