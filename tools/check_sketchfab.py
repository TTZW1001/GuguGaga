import urllib.request, urllib.error, json, pathlib
for uid in ['db8a037d135b41b08752ce4c57f43525', '39e36b4746ec49ad9e47a50480bcfd0c']:
    data = json.load(urllib.request.urlopen('https://api.sketchfab.com/v3/models/' + uid))
    pathlib.Path('tools/source/' + uid + '.json').write_text(json.dumps(data, indent=2), encoding='utf-8')
    try:
        response = urllib.request.urlopen('https://api.sketchfab.com/v3/models/' + uid + '/download')
        print(uid, response.status, response.read(2000))
    except urllib.error.HTTPError as error:
        print(uid, error.code, error.read(500))
