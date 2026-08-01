#!/bin/zsh
cd "${0:A:h}"
exec ./work/qwen-tts-env/bin/python ./tts_server.py
