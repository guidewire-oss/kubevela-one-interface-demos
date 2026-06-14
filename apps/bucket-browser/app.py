#!/usr/bin/env python3
"""
Object Store Browser — a cloud-neutral web UI for browsing a bucket's contents.

Lists the objects in a bucket and renders their contents in the browser. The bucket
can be AWS S3 or GCP Cloud Storage, selected at runtime by STORAGE_PROVIDER, via the
ObjectStore abstraction in storage.py. Every route below is identical for both clouds
— the "one interface" promise applied to the application tier. It is the read-only
browser counterpart to the product-catalog API.
"""
import os
from flask import Flask, render_template_string

from storage import build_object_store, StorageError

app = Flask(__name__)

# The object store — S3 or GCS, chosen by STORAGE_PROVIDER. Construction is cheap
# and credential-free; the cloud client is opened lazily on first use.
store = build_object_store()


LIST_TEMPLATE = '''
<!DOCTYPE html>
<html>
<head>
    <title>Object Store Browser</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background-color: #f8f9fa; }
        .container { max-width: 1000px; margin: 0 auto; }
        .bucket-info { background-color: #e3f2fd; padding: 15px; margin-bottom: 20px; border-radius: 8px; border: 1px solid #2196f3; }
        .pill { display: inline-block; padding: 2px 10px; border-radius: 12px; color: white; font-size: 0.8em; font-weight: bold; }
        .pill.aws { background-color: #ff9900; }
        .pill.gcp { background-color: #4285f4; }
        .pill.unknown { background-color: #9e9e9e; }
        .object { border: 1px solid #ddd; padding: 15px; margin: 10px 0; background: white; border-radius: 5px; box-shadow: 0 1px 3px rgba(0,0,0,0.1); }
        .object-header { display: flex; justify-content: space-between; align-items: center; }
        .object-name { font-weight: bold; font-size: 1.1em; color: #1976d2; }
        .object-meta { color: #666; font-size: 0.9em; }
        .view-button { background-color: #4caf50; color: white; padding: 8px 16px; text-decoration: none; border-radius: 4px; font-size: 0.9em; }
        .view-button:hover { background-color: #45a049; }
        .error { color: #b71c1c; background-color: #ffebee; padding: 15px; border-radius: 5px; border: 1px solid #f44336; }
    </style>
</head>
<body>
    <div class="container">
        <h1>&#129387; Object Store Browser</h1>
        <div class="bucket-info">
            <h3>Bucket information</h3>
            <p><strong>Provider:</strong> <span class="pill {{ provider }}">{{ provider|upper }}</span></p>
            <p><strong>Bucket:</strong> {{ bucket }}</p>
            <p><strong>Location:</strong> {{ location or "(unset)" }}</p>
        </div>

        {% if error %}
            <div class="error"><h3>Error</h3><p>{{ error }}</p></div>
        {% else %}
            <h3>Contents ({{ object_count }} object{{ '' if object_count == 1 else 's' }})</h3>
            {% for obj in objects %}
                <div class="object">
                    <div class="object-header">
                        <div>
                            <div class="object-name">&#128196; {{ obj.key }}</div>
                            <div class="object-meta">Size: {{ obj.size }} bytes | Modified: {{ obj.last_modified }}</div>
                        </div>
                        <a href="/view/{{ obj.key }}" class="view-button">View</a>
                    </div>
                </div>
            {% endfor %}
            {% if object_count == 0 %}
                <p><em>Bucket is empty.</em></p>
            {% endif %}
        {% endif %}
    </div>
</body>
</html>
'''

FILE_TEMPLATE = '''
<!DOCTYPE html>
<html>
<head>
    <title>{{ filename }} - Object Viewer</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background-color: #f8f9fa; }
        .container { max-width: 1000px; margin: 0 auto; }
        .nav { margin-bottom: 20px; padding: 10px; background: white; border-radius: 5px; box-shadow: 0 1px 3px rgba(0,0,0,0.1); }
        .nav a { color: #1976d2; text-decoration: none; margin-right: 20px; }
        .nav a:hover { text-decoration: underline; }
        .file-info { background-color: #e8f5e8; padding: 15px; margin-bottom: 20px; border-radius: 8px; border: 1px solid #4caf50; }
        .content-box { background: white; padding: 20px; border-radius: 8px; box-shadow: 0 1px 3px rgba(0,0,0,0.1); }
        .content { white-space: pre-wrap; font-family: 'Courier New', monospace; line-height: 1.5; }
        .json-content { background-color: #f5f5f5; padding: 15px; border-radius: 5px; }
        .error { color: #b71c1c; background-color: #ffebee; padding: 15px; border-radius: 5px; border: 1px solid #f44336; }
    </style>
</head>
<body>
    <div class="container">
        <div class="nav">
            <a href="/">&#127968; Back to bucket</a>
            <span>&#128196; Viewing: <strong>{{ filename }}</strong></span>
        </div>

        {% if error %}
            <div class="error"><h3>Error</h3><p>{{ error }}</p></div>
        {% else %}
            <div class="file-info">
                <h3>File information</h3>
                <p><strong>Key:</strong> {{ filename }}</p>
                <p><strong>Size:</strong> {{ size }} bytes</p>
                <p><strong>Content-Type:</strong> {{ content_type }}</p>
                <p><strong>Last modified:</strong> {{ last_modified }}</p>
            </div>
            <div class="content-box">
                <h3>Contents</h3>
                <div class="content {{ 'json-content' if content_type == 'application/json' }}">{{ content }}</div>
            </div>
        {% endif %}
    </div>
</body>
</html>
'''


@app.route('/health', methods=['GET'])
def health_check():
    """Liveness — process is up."""
    return {'status': 'healthy', 'service': 'bucket-browser'}, 200


@app.route('/ready', methods=['GET'])
def readiness_check():
    """Readiness — the bucket is reachable with current credentials."""
    if store.bucket_exists():
        return {'status': 'ready', 'provider': store.provider, 'bucket': store.bucket}, 200
    return {
        'status': 'not ready',
        'provider': store.provider,
        'error': f'{store.provider} bucket "{store.bucket}" not accessible '
                 '(check credentials and bucket name)',
    }, 503


@app.route('/', methods=['GET'])
def index():
    """List the bucket's objects."""
    try:
        objects = store.list_objects()
        return render_template_string(
            LIST_TEMPLATE,
            provider=store.provider, bucket=store.bucket, location=store.location,
            objects=objects, object_count=len(objects), error=None,
        )
    except StorageError as e:
        return render_template_string(
            LIST_TEMPLATE,
            provider=store.provider, bucket=store.bucket, location=store.location,
            objects=[], object_count=0, error=str(e),
        ), 502


@app.route('/view/<path:key>', methods=['GET'])
def view_object(key):
    """Render a single object's contents (decoded as UTF-8 where possible)."""
    try:
        obj = store.read_object(key)
    except StorageError as e:
        return render_template_string(
            FILE_TEMPLATE, filename=key, size=0, content_type='unknown',
            last_modified='unknown', content='', error=str(e),
        ), 502

    if obj is None:
        return render_template_string(
            FILE_TEMPLATE, filename=key, size=0, content_type='unknown',
            last_modified='unknown', content='', error='Object not found',
        ), 404

    try:
        content = obj['data'].decode('utf-8')
    except UnicodeDecodeError:
        content = f"[Binary object - {len(obj['data'])} bytes]"

    return render_template_string(
        FILE_TEMPLATE,
        filename=key, size=obj['size'], content_type=obj['content_type'],
        last_modified=obj['last_modified'], content=content, error=None,
    )


if __name__ == '__main__':
    port = int(os.environ.get('PORT', 8080))
    app.run(host='0.0.0.0', port=port, debug=False)
