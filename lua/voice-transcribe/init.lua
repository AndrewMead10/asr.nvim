local M = {}

local recording = false
local audio_process = nil

M.config = {
  transcribe_url = "http://localhost:4343/transcribe",
  audio_format = "wav",
  sample_rate = 16000,
}

function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})
end

function M.toggle_recording()
  if recording then
    M.stop_recording()
  else
    M.start_recording()
  end
end

function M.start_recording()
  if recording then
    return
  end
  
  recording = true
  print("🎤 Recording started...")
  
  local temp_file = os.tmpname() .. ".wav"
  
  local cmd = string.format(
    "arecord -f S16_LE -r %d -c 1 %s",
    M.config.sample_rate,
    temp_file
  )
  
  audio_process = vim.fn.jobstart(cmd, {
    on_exit = function(_, code)
      if code == 0 and recording == false then
        M.send_audio_for_transcription(temp_file)
      end
      os.remove(temp_file)
    end
  })
end

function M.stop_recording()
  if not recording then
    return
  end
  
  recording = false
  print("🎤 Recording stopped, transcribing...")
  
  if audio_process then
    vim.fn.jobstop(audio_process)
    audio_process = nil
  end
end

function M.send_audio_for_transcription(audio_file)
  local curl_cmd = string.format(
    'curl -X POST -F "audio=@%s" %s',
    audio_file,
    M.config.transcribe_url
  )
  
  vim.fn.jobstart(curl_cmd, {
    stdout_buffered = true,
    on_stdout = function(_, data)
      if data and #data > 0 then
        local text = table.concat(data, "\n"):gsub("^%s*(.-)%s*$", "%1")
        if text ~= "" then
          M.insert_text(text)
        end
      end
    end,
    on_exit = function(_, code)
      if code ~= 0 then
        print("❌ Transcription failed")
      end
    end
  })
end

function M.insert_text(text)
  local cursor = vim.api.nvim_win_get_cursor(0)
  local row, col = cursor[1] - 1, cursor[2]
  
  vim.api.nvim_buf_set_text(0, row, col, row, col, {text})
  
  local new_col = col + #text
  vim.api.nvim_win_set_cursor(0, {row + 1, new_col})
  
  print("✅ Transcribed: " .. text)
end

return M
