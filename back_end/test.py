import google.generativeai as genai
from dotenv import load_dotenv
import queue, sys, os
from collections import deque
from os.path import join, dirname
from dotenv import load_dotenv
import sounddevice as sd

load_dotenv(verbose=True)

dotenv_path = join(dirname(__file__), '.env')
load_dotenv(dotenv_path)

GOOGLE_API_KEY = os.environ.get("GOOGLE_API_KEY")

genai.configure(api_key=GOOGLE_API_KEY)

audio_queue = queue.Queue()
recognized_texts = deque(maxlen=10)
recognized_text = ""
summary = ""
partial_text = ""
is_recognizing = False  # 音声認識の状態を保持する変数
finishSummarize = False # 要約終了フラグ
audio_buffer = bytearray()
c_jud = True
previous_text_long = 0  # previous_text_longを初期化



def audio_callback(indata, frames, time, status):
    global audio_buffer, c_jud, audio_queue
    if status:
        print(status, file=sys.stderr)

    if c_jud:
        audio_queue.put(bytes(indata))
    else:
        c_jud = True
        audio_queue = queue.Queue()# キューもクリア
        audio_queue.put(bytes(indata)) 

with sd.RawInputStream(samplerate=16000, blocksize=16000, dtype='int16',
                        channels=1, callback=audio_callback):