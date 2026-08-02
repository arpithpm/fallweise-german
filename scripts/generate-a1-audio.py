#!/usr/bin/env python3
"""Generate Vivian masters in batches, then derive pitch-preserving study speeds."""
from __future__ import annotations
import argparse, hashlib, json, subprocess, sys, time
from pathlib import Path

ROOT=Path(__file__).resolve().parent.parent
CACHE=ROOT/'work'/'tts-cache'
MODEL_ID='Qwen/Qwen3-TTS-12Hz-0.6B-CustomVoice'
SPEAKER='Vivian'
RATES=(1.0,.88,.72)

def key(text:str,rate:float)->Path:
    digest=hashlib.sha256(f'{MODEL_ID}|{SPEAKER}|{rate}|{text}'.encode()).hexdigest()
    return CACHE/f'{digest}.wav'

def curriculum()->list[str]:
    source="global.window=global;require('./a1-vocabulary-data.js');process.stdout.write(JSON.stringify(A1Vocabulary.items.map(x=>x.article?`${x.article} ${x.de}`:x.de)))"
    result=subprocess.run(['node','-e',source],cwd=ROOT,check=True,capture_output=True,text=True)
    return list(dict.fromkeys(json.loads(result.stdout)))

def valid(path:Path)->bool:
    return path.exists() and path.stat().st_size>1000

def main()->int:
    parser=argparse.ArgumentParser();parser.add_argument('--batch-size',type=int,default=4);args=parser.parse_args()
    import librosa, numpy as np, soundfile as sf, torch
    from qwen_tts import Qwen3TTSModel
    CACHE.mkdir(parents=True,exist_ok=True);texts=curriculum()
    missing=[text for text in texts if not valid(key(text,1.0))]
    print(f'curriculum={len(texts)} natural_missing={len(missing)} batch_size={args.batch_size}',flush=True)
    if missing:
        device='mps' if torch.backends.mps.is_available() else 'cpu'
        model=Qwen3TTSModel.from_pretrained(MODEL_ID,device_map=device,dtype=torch.float32,attn_implementation='eager')
        started=time.time();done=0
        for offset in range(0,len(missing),args.batch_size):
            batch=missing[offset:offset+args.batch_size]
            try:
                wavs,sr=model.generate_custom_voice(text=batch,language=['German']*len(batch),speaker=[SPEAKER]*len(batch))
            except Exception as exc:
                print(f'batch_failed offset={offset} error={type(exc).__name__}: {exc}; retrying singly',flush=True)
                wavs=[]
                for text in batch:
                    one,sr=model.generate_custom_voice(text=text,language='German',speaker=SPEAKER);wavs.append(one[0])
            for text,wav in zip(batch,wavs):
                target=key(text,1.0);temp=target.with_suffix('.tmp.wav');sf.write(temp,wav,sr);temp.replace(target)
            done+=len(batch);elapsed=time.time()-started;eta=(elapsed/done)*(len(missing)-done) if done else 0
            print(f'natural {done}/{len(missing)} elapsed={elapsed/60:.1f}m eta={eta/60:.1f}m current={batch[-1]}',flush=True)
        del model
    print('deriving pitch-preserving Learn and Slow files',flush=True)
    for i,text in enumerate(texts,1):
        audio,sr=sf.read(key(text,1.0),dtype='float32')
        if audio.ndim>1:audio=np.mean(audio,axis=1)
        for rate in (.88,.72):
            target=key(text,rate)
            stretched=librosa.effects.time_stretch(audio,rate=rate)
            temp=target.with_suffix('.tmp.wav');sf.write(temp,stretched,sr);temp.replace(target)
        if i%25==0 or i==len(texts):print(f'speeds {i}/{len(texts)}',flush=True)
    failed=[]
    for text in texts:
        for rate in RATES:
            if not valid(key(text,rate)):failed.append((text,rate))
    print(f'complete files={len(texts)*len(RATES)} failed={len(failed)}',flush=True)
    if failed:print(failed[:20],file=sys.stderr);return 1
    return 0

if __name__=='__main__':raise SystemExit(main())
