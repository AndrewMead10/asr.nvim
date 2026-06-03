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
      transcribe_url = "http://localhost:4343/v1/audio/transcriptions",
      api_key = "sk-your-key",
      sample_rate = 16000,
    })
  end
}
```

## Configuration

```lua
require('asr').setup({
  transcribe_url = "http://localhost:4343/v1/audio/transcriptions",
  model = "parakeet-tdt-0.6b-v2",
  api_key = "sk-your-key",
  audio_format = "wav",
  sample_rate = 16000,
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
- An ASR API key

## API Endpoint

Your transcription endpoint should:
- Accept OpenAI-compatible `POST /v1/audio/transcriptions`
- Accept `Authorization: Bearer <api_key>`
- Return plain text when `response_format=text`
