# asr.nvim

A Neovim plugin for voice recording and transcription.

## Features

- Press `<C-w>` to toggle audio recording
- Automatically sends recorded audio to a transcription endpoint
- Inserts transcribed text at cursor position
- Configurable transcription URL and audio settings

## Installation

Using [packer.nvim](https://github.com/wbthomason/packer.nvim):

```lua
use {
  'path/to/asr.nvim',
  config = function()
    require('asr').setup({
      transcribe_url = "http://your-transcription-service.com/transcribe",
      sample_rate = 16000,
    })
  end
}
```

## Configuration

```lua
require('asr').setup({
  transcribe_url = "http://localhost:8080/transcribe",  -- Your transcription endpoint
  audio_format = "wav",                                 -- Audio format
  sample_rate = 16000,                                  -- Sample rate in Hz
})
```

## Usage

1. Position cursor where you want text inserted
2. Press `<C-w>` to start recording
3. Speak your message
4. Press `<C-w>` again to stop recording and transcribe
5. Transcribed text appears at cursor position

## Requirements

- `arecord` (ALSA utils) for audio recording
- `curl` for HTTP requests
- A transcription service endpoint that accepts audio files

## API Endpoint

Your transcription endpoint should:
- Accept POST requests with audio file as form data (`audio` field)
- Return plain text transcription response
