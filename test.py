import requests


data = (requests.get("http://localhost:5001/audio_query", params={
    "text": "デスクライト、つけておきマシタ。手元が明るいと、作業も捗りそう デスね。でも、あまり根を詰めすぎないでくだサイね？アナタの健康が一番大事なんデスから。",
})).json()
print(data)

data = (requests.post("http://localhost:5001/synthesis", json={
    "text": data["text"],
    "ident": "sekai_whisper",
    "speaker_id": 0,
    "style_id": 0,
    "sdp_ratio": 0.5,
    "length_scale": 0.5,
    "audio_query": data["audio_query"],
})).content
with open("test.wav", "wb") as f:
    f.write(data)