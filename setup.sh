#!/bin/bash
# --------------------------------------------------------------
# Termux YouTube downloader – fixed version (2025-11-05)
# --------------------------------------------------------------

set -e  # stop on any error

echo "=== Updating Termux packages ==="
pkg update -y && pkg upgrade -y

echo "=== Installing Python, yt-dlp and Flask ==="
pkg install -y python
pip install --upgrade yt-dlp flask

echo "=== Creating downloads folder ==="
mkdir -p downloads

echo "=== Writing app.py ==="
cat > app.py <<'EOF'
from flask import Flask, request, send_from_directory, render_template_string
import subprocess, os, shlex

app = Flask(__name__)
DOWNLOAD_FOLDER = 'downloads'
app.config['DOWNLOAD_FOLDER'] = DOWNLOAD_FOLDER

HTML = """
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>YouTube Downloader</title>
    <style>
        body {font-family:Arial,sans-serif;max-width:600px;margin:0 auto;padding:20px;}
        h1 {text-align:center;}
        input[type=text]{padding:10px;margin:8px 0;}
        button{padding:10px;background:#4caf50;color:#fff;border:none;cursor:pointer;}
        button:hover{background:#45a049;}
        #msg{margin-top:15px;padding:10px;border:1px solid #ddd;}
    </style>
</head>
<body>
    <h1>YouTube Downloader</h1>
    <form action="/download" method="post">
        <input type="text" name="url" placeholder="https://youtube.com/watch?v=..." required>
        <button type="submit">Download</button>
    </form>
    {% if msg %}<div id="msg">{{ msg | safe }}</div>{% endif %}
</body>
</html>
"""

@app.route('/', methods=['GET'])
def index():
    return render_template_string(HTML)

@app.route('/download', methods=['POST'])
def download():
    url = request.form['url'].strip()
    try:
        # 1. Get the exact filename yt-dlp will create
        cmd_name = ['yt-dlp', '--restrict-filenames', '--get-filename', '-o', '%(title)s.%(ext)s', url]
        filename = subprocess.check_output(cmd_name, text=True).strip()

        # 2. Download (no format selection → best merged format)
        out_path = os.path.join(DOWNLOAD_FOLDER, '%(title)s.%(ext)s')
        cmd_dl   = ['yt-dlp', '--restrict-filenames', '-o', out_path, url]
        result   = subprocess.run(cmd_dl, capture_output=True, text=True)

        if result.returncode != 0:
            raise Exception(result.stderr.strip().splitlines()[-1])

        link = f'<a href="/downloads/{shlex.quote(filename)}">Download "{filename}"</a>'
        return render_template_string(HTML, msg=f"Success! {link}")

    except Exception as e:
        err = str(e).replace('\n', '<br>')
        return render_template_string(HTML, msg=f"<span style='color:red;'>Error: {err}</span>")

@app.route('/downloads/<path:filename>')
def serve_file(filename):
    return send_from_directory(DOWNLOAD_FOLDER, filename, as_attachment=True)

if __name__ == '__main__':
    print("\n=== Server starting – open http://127.0.0.1:5000 in your browser ===")
    print("   (or replace 127.0.0.1 with your phone's LAN IP to access from another device)\n")
    app.run(host='0.0.0.0', port=5000, debug=False)
EOF

echo "=== Starting Flask server ==="
python app.py