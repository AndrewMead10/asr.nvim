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
  
  print("🎤 Starting audio recording with command: " .. cmd)
  
  audio_process = vim.fn.jobstart(cmd, {
    stderr_buffered = true,
    on_stderr = function(_, data)
      if data and #data > 0 then
        local error_text = table.concat(data, "\n")
        print("🎤 arecord stderr: " .. error_text)
      end
    end,
    on_exit = function(_, code)
      print("🎤 Audio recording process exited with code: " .. code)
      -- Code 143 is SIGTERM (15), Code 130 is SIGINT (2), Code 1 seems to be what we're getting
      if (code == 0 or code == 143 or code == 130 or code == 1) and recording == false then
        print("🎤 Recording stopped successfully, sending for transcription...")
        M.send_audio_for_transcription(temp_file)
      else
        if code ~= 0 and code ~= 143 and code ~= 130 and code ~= 1 then
          print("❌ Audio recording failed with unexpected exit code: " .. code)
        end
        if recording == true then
          print("⚠️ Recording still active, not sending for transcription")
        end
      end
      print("🎤 Cleaning up temp file: " .. temp_file)
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
  print("📡 Preparing to send audio file: " .. audio_file)
  print("📡 Endpoint URL: " .. M.config.transcribe_url)
  
  local curl_cmd = string.format(
    'curl -X POST -F "audio=@%s" %s',
    audio_file,
    M.config.transcribe_url
  )
  
  print("📡 Executing curl command: " .. curl_cmd)
  
  vim.fn.jobstart(curl_cmd, {
    stdout_buffered = true,
    stderr_buffered = true,
    on_stdout = function(_, data)
      print("📡 Received stdout data: " .. vim.inspect(data))
      if data and #data > 0 then
        local text = table.concat(data, "\n"):gsub("^%s*(.-)%s*$", "%1")
        if text ~= "" then
          print("📡 Extracted text: " .. text)
          M.insert_text(text)
        else
          print("📡 Empty text after processing")
        end
      end
    end,
    on_stderr = function(_, data)
      if data and #data > 0 then
        local error_text = table.concat(data, "\n")
        print("📡 curl stderr: " .. error_text)
      end
    end,
    on_exit = function(_, code)
      print("📡 curl process exited with code: " .. code)
      if code ~= 0 then
        print("❌ Transcription failed with exit code: " .. code)
      else
        print("✅ curl request completed successfully")
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
