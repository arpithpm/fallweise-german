#!/usr/bin/env python3
"""Local Fallweise server with optional Qwen3-TTS German speech."""
from __future__ import annotations
import hashlib, json, os, threading, time
from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler
from pathlib import Path
from urllib.parse import urlparse

ROOT = Path(__file__).resolve().parent
CACHE = ROOT / "work" / "tts-cache"
CACHE.mkdir(parents=True, exist_ok=True)
MODEL_ID = os.environ.get("FALLWEISE_TTS_MODEL", "Qwen/Qwen3-TTS-12Hz-0.6B-CustomVoice")
HOST, PORT = "127.0.0.1", int(os.environ.get("FALLWEISE_PORT", "8000"))
state = {"status": "cold", "error": None, "model": None, "device": None}
model_lock = threading.Lock()
QWEN_SPEAKERS = {"Serena", "Vivian", "Uncle_Fu", "Dylan", "Eric", "Ryan", "Aiden", "Ono_Anna", "Sohee"}
precache = {"status": "idle", "total": 0, "done": 0, "cached": 0, "failed": 0, "current": "", "errors": []}

def load_model():
    if state["model"] is not None:
        return state["model"]
    with model_lock:
        if state["model"] is not None:
            return state["model"]
        state.update(status="loading", error=None)
        try:
            import torch
            from qwen_tts import Qwen3TTSModel
            # MPS is attempted first. Set FALLWEISE_TTS_DEVICE=cpu to force CPU.
            device = os.environ.get("FALLWEISE_TTS_DEVICE") or ("mps" if torch.backends.mps.is_available() else "cpu")
            # float16 generation on MPS can produce NaN sampling probabilities.
            # float32 is more stable for this autoregressive model on Apple Silicon.
            dtype = torch.float32
            model = Qwen3TTSModel.from_pretrained(MODEL_ID, device_map=device, dtype=dtype, attn_implementation="eager")
            state.update(status="ready", model=model, device=device)
            return model
        except Exception as exc:
            state.update(status="error", error=f"{type(exc).__name__}: {exc}")
            raise

def synthesize(text: str, rate: float, speaker: str) -> Path:
    text = " ".join(text.split()).strip()
    if not text or len(text) > 400:
        raise ValueError("Text must contain 1–400 characters")
    rate = max(.65, min(1.1, float(rate)))
    speaker = speaker if speaker in QWEN_SPEAKERS else "Vivian"
    key = hashlib.sha256(f"{MODEL_ID}|{speaker}|{rate}|{text}".encode()).hexdigest()
    target = CACHE / f"{key}.wav"
    if target.exists():
        return target
    model = load_model()
    instruction = "Sprich klares, natürliches Hochdeutsch mit sorgfältiger Aussprache für Deutschlernende."
    if rate < .8:
        instruction += " Sprich langsam und mache natürliche kurze Pausen."
    elif rate >= .98:
        instruction += " Sprich in natürlichem Gesprächstempo."
    wavs, sr = model.generate_custom_voice(text=text, language="German", speaker=speaker, instruct=instruction)
    import soundfile as sf
    temp = target.with_suffix(".tmp.wav")
    sf.write(temp, wavs[0], sr)
    temp.replace(target)
    return target

def precache_worker(texts, rates, speaker):
    total=len(texts)*len(rates)
    precache.update(status="running", total=total, done=0, cached=0, failed=0, current="", errors=[])
    for rate in rates:
      for text in texts:
        precache["current"] = f"{rate:g}× · {text}"
        try:
            clean = " ".join(text.split()).strip()
            key = hashlib.sha256(f"{MODEL_ID}|{speaker}|{rate}|{clean}".encode()).hexdigest()
            target = CACHE / f"{key}.wav"
            existed = target.exists()
            synthesize(clean, rate, speaker)
            if existed: precache["cached"] += 1
        except Exception as exc:
            precache["failed"] += 1
            if len(precache["errors"]) < 20: precache["errors"].append({"text":text,"rate":rate,"error":f"{type(exc).__name__}: {exc}"})
        finally: precache["done"] += 1
    precache.update(status="complete", current="")

class Handler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(ROOT), **kwargs)
    def json(self, payload, status=200):
        body=json.dumps(payload).encode(); self.send_response(status); self.send_header("Content-Type","application/json"); self.send_header("Content-Length",str(len(body))); self.send_header("Cache-Control","no-store"); self.cors(); self.end_headers(); self.wfile.write(body)
    def cors(self):
        origin=self.headers.get("Origin","")
        if origin.startswith("http://127.0.0.1:") or origin.startswith("http://localhost:"):
            self.send_header("Access-Control-Allow-Origin",origin); self.send_header("Vary","Origin")
    def do_OPTIONS(self):
        self.send_response(204); self.cors(); self.send_header("Access-Control-Allow-Methods","GET, POST, OPTIONS"); self.send_header("Access-Control-Allow-Headers","Content-Type"); self.send_header("Access-Control-Max-Age","86400"); self.end_headers()
    def do_GET(self):
        path = urlparse(self.path).path
        if path == "/favicon.ico":
            self.send_response(204); self.end_headers(); return
        if path == "/api/tts/status":
            return self.json({"status":state["status"],"model":MODEL_ID,"device":state["device"],"error":state["error"]})
        if path == "/api/tts/precache/status": return self.json(precache)
        return super().do_GET()
    def do_POST(self):
        path=urlparse(self.path).path
        if path == "/api/tts/precache":
            try:
                length=int(self.headers.get("Content-Length","0"))
                if length > 131072: raise ValueError("Manifest too large")
                data=json.loads(self.rfile.read(length)); texts=list(dict.fromkeys(str(x) for x in data.get("texts",[]) if str(x).strip()))
                if not texts or len(texts)>1000: raise ValueError("Manifest must contain 1–1000 phrases")
                if precache["status"] == "running": return self.json(precache,409)
                speaker=str(data.get("speaker","Vivian")); speaker=speaker if speaker in QWEN_SPEAKERS else "Vivian"
                raw_rates=data.get("rates",[data.get("rate",.88)])
                rates=list(dict.fromkeys(max(.65,min(1.1,float(x))) for x in raw_rates))
                threading.Thread(target=precache_worker,args=(texts,rates,speaker),daemon=True).start()
                return self.json({"status":"started","total":len(texts)*len(rates),"speaker":speaker,"rates":rates},202)
            except ValueError as exc: return self.json({"error":str(exc)},400)
        if path != "/api/tts": return self.send_error(404)
        try:
            length=int(self.headers.get("Content-Length","0"));
            if length > 4096: raise ValueError("Request too large")
            data=json.loads(self.rfile.read(length)); path=synthesize(str(data.get("text","")),float(data.get("rate",.88)),str(data.get("speaker","Vivian")))
            body=path.read_bytes(); self.send_response(200); self.send_header("Content-Type","audio/wav"); self.send_header("Content-Length",str(len(body))); self.send_header("Cache-Control","public, max-age=31536000, immutable"); self.cors(); self.end_headers(); self.wfile.write(body)
        except ValueError as exc: self.json({"error":str(exc)},400)
        except Exception as exc: self.json({"error":"Local Qwen TTS unavailable","detail":f"{type(exc).__name__}: {exc}"},503)
    def log_message(self, fmt, *args): print(f"[{time.strftime('%H:%M:%S')}] {fmt % args}")

if __name__ == "__main__":
    print(f"Fallweise: http://{HOST}:{PORT}")
    print("Qwen loads on the first premium-voice request; browser speech remains the fallback.")
    ThreadingHTTPServer((HOST,PORT),Handler).serve_forever()
