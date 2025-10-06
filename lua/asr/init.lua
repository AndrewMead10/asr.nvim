local M = {}

local recording = false
local audio_process = nil
local auto_stop_timer = nil

M.config = {
  transcribe_url = "http://localhost:4343/transcribe",
  audio_format = "wav",
  sample_rate = 16000, -- Recording sample rate (configurable per device, API always expects 16000)
  audio_device = "default:CARD=Snowball", -- nil means use default device, otherwise specify like "hw:1,0"
  api_key = nil, -- API key for authentication (optional)
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

  vim.notify("🎤 Recording started (15-minute auto-stop)", "info", {
    title = "ASR",
    timeout = 2000
  })

  -- Start auto-stop timer for 15 minutes (900000 ms)
  auto_stop_timer = vim.defer_fn(function()
    if recording then
      vim.notify("⏰ Auto-stopping recording after 15 minutes", "info", {
        title = "ASR",
        timeout = 2000
      })
      M.stop_recording()
    end
  end, 900000)
  
  local temp_file = os.tmpname() .. ".wav"
  
  local cmd
  if M.config.sample_rate == 16000 then
    -- Direct recording at 16000Hz mono (if supported by device)
    if M.config.audio_device then
      cmd = string.format(
        "arecord -D %s -f S16_LE -r 16000 -c 1 %s",
        M.config.audio_device,
        temp_file
      )
    else
      cmd = string.format(
        "arecord -f S16_LE -r 16000 -c 1 %s",
        temp_file
      )
    end
  else
    -- Record at device sample rate, then convert to 16000Hz mono
    local temp_raw_file = temp_file .. ".raw"
    if M.config.audio_device then
      cmd = string.format(
        "arecord -D %s -f S16_LE -r %d -c 2 %s",
        M.config.audio_device,
        M.config.sample_rate,
        temp_raw_file
      )
    else
      cmd = string.format(
        "arecord -f S16_LE -r %d -c 2 %s",
        M.config.sample_rate,
        temp_raw_file
      )
    end
  end
  
  print("🎙️ ASR Debug - Recording command: " .. cmd)

  audio_process = vim.fn.jobstart(cmd, {
    stderr_buffered = true,
    on_stderr = function(_, data)
      if data and #data > 0 then
        local stderr_text = table.concat(data, "\n")
        print("⚠️ ASR Debug - Recording stderr: " .. stderr_text)
        vim.notify("❌ Recording error: " .. stderr_text, "error", {
          title = "ASR",
          timeout = 4000
        })
      end
    end,
    on_exit = function(_, code)
      print("📤 ASR Debug - Recording exit code: " .. code)
      -- Code 143 is SIGTERM (15), Code 130 is SIGINT (2), Code 1 seems to be what we're getting
      if (code == 0 or code == 143 or code == 130 or code == 1) and recording == false then
        if M.config.sample_rate == 16000 then
          print("📤 ASR Debug - Sending audio file: " .. temp_file)
          M.send_audio_for_transcription(temp_file)
        else
          -- Convert stereo/high-sample-rate to mono 16kHz
          local temp_raw_file = temp_file .. ".raw"
          local convert_cmd = string.format(
            "ffmpeg -y -i %s -ac 1 -ar 16000 %s && rm %s",
            temp_raw_file,
            temp_file,
            temp_raw_file
          )
          print("🔄 ASR Debug - Converting audio: " .. convert_cmd)
          vim.fn.jobstart(convert_cmd, {
            on_exit = function(_, convert_code)
              print("📤 ASR Debug - Conversion exit code: " .. convert_code)
              if convert_code == 0 then
                print("📤 ASR Debug - Sending converted audio file: " .. temp_file)
                M.send_audio_for_transcription(temp_file)
              else
                print("❌ ASR Debug - Conversion failed, removing temp files")
                vim.notify("❌ Audio conversion failed", "error", {
                  title = "ASR",
                  timeout = 4000
                })
                os.remove(temp_file)
                os.remove(temp_raw_file)
              end
            end
          })
        end
      else
        print("❌ ASR Debug - Recording failed, removing temp file")
        vim.notify("❌ Recording failed (exit code: " .. code .. ")", "error", {
          title = "ASR",
          timeout = 4000
        })
        if M.config.sample_rate ~= 16000 then
          local temp_raw_file = temp_file .. ".raw"
          os.remove(temp_raw_file)
        end
        os.remove(temp_file)
      end
    end
  })
end

function M.stop_recording()
  if not recording then
    return
  end
  
  recording = false

  vim.notify("⏹️ Recording stopped", "info", {
    title = "ASR",
    timeout = 2000
  })

  -- Cancel auto-stop timer if it exists
  if auto_stop_timer then
    auto_stop_timer:close()
    auto_stop_timer = nil
  end

  if audio_process then
    vim.fn.jobstop(audio_process)
    audio_process = nil
  end
end

function M.send_audio_for_transcription(audio_file)
  
  local curl_cmd
  if M.config.api_key then
    curl_cmd = string.format(
      'curl -X POST -H "X-API-Key: %s" -F "file=@%s" %s',
      M.config.api_key,
      audio_file,
      M.config.transcribe_url
    )
  else
    curl_cmd = string.format(
      'curl -X POST -F "file=@%s" %s',
      audio_file,
      M.config.transcribe_url
    )
  end
  
  print("🌐 ASR Debug - Transcription command: " .. curl_cmd)
  
  vim.fn.jobstart(curl_cmd, {
    stdout_buffered = true,
    stderr_buffered = true,
    on_stdout = function(_, data)
      if data and #data > 0 then
        local stdout_text = table.concat(data, "\n")
        print("💬 ASR Debug - Transcription stdout: " .. stdout_text)
        local text = stdout_text:gsub("^%s*(.-)%s*$", "%1")
        text = text:gsub('^"(.-)"$', '%1')
        if text ~= "" then
          M.insert_text(text)
        end
      end
    end,
    on_stderr = function(_, data)
      if data and #data > 0 then
        local stderr_text = table.concat(data, "\n")
        print("⚠️ ASR Debug - Transcription stderr: " .. stderr_text)
        vim.notify("❌ Transcription error: " .. stderr_text, "error", {
          title = "ASR",
          timeout = 4000
        })
      end
    end,
    on_exit = function(_, code)
      print("📤 ASR Debug - Transcription exit code: " .. code)
      if code ~= 0 then
        vim.notify("❌ Transcription failed (exit code: " .. code .. ")", "error", {
          title = "ASR",
          timeout = 4000
        })
      end
      os.remove(audio_file)
    end
  })
end

function M.insert_text(text)
  local cursor = vim.api.nvim_win_get_cursor(0)
  local row, col = cursor[1] - 1, cursor[2]
  
  local lines = vim.split(text, '\n', {plain = true})
  vim.api.nvim_buf_set_text(0, row, col, row, col, lines)
  
  local final_row = row + #lines - 1
  local final_col = #lines == 1 and col + #lines[1] or #lines[#lines]
  vim.api.nvim_win_set_cursor(0, {final_row + 1, final_col})
end

return M
