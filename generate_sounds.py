import wave
import struct

import math

def create_tone_wav(filename, frequency, duration=2, rate=44100):
    with wave.open(filename, 'w') as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(rate)
        for i in range(int(duration * rate)):
            # Sine wave
            value = int(32767.0 * math.sin(2.0 * math.pi * frequency * i / rate))
            data = struct.pack('<h', value)
            f.writeframesraw(data)

# Create audible placeholder tones
create_tone_wav('assets/sounds/siren.mp3', 880)  # A5 note
create_tone_wav('assets/sounds/whistle.mp3', 1760) # A6 note
create_tone_wav('assets/sounds/high_pitch.mp3', 3000) # High pitch
create_tone_wav('assets/sounds/beep.mp3', 440) # A4 note
