local M = {}

local recording = false
local audio_process = nil

M.config = {
  transcribe_url = "http://localhost:4343/transcribe",
  audio_format = "wav",
  sample_rate = 16000,
  audio_device = "default:CARD=Snowball", -- nil means use default device, otherwise specify like "hw:1,0"
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
  
  local temp_file = os.tmpname() .. ".wav"
  
  local cmd
  if M.config.audio_device then
    cmd = string.format(
      "arecord -D %s -f S16_LE -r %d -c 1 %s",
      M.config.audio_device,
      M.config.sample_rate,
      temp_file
    )
  else
    cmd = string.format(
      "arecord -f S16_LE -r %d -c 1 %s",
      M.config.sample_rate,
      temp_file
    )
  end
  
  audio_process = vim.fn.jobstart(cmd, {
    stderr_buffered = true,
    on_stderr = function(_, data)
    end,
    on_exit = function(_, code)
      -- Code 143 is SIGTERM (15), Code 130 is SIGINT (2), Code 1 seems to be what we're getting
      if (code == 0 or code == 143 or code == 130 or code == 1) and recording == false then
        M.send_audio_for_transcription(temp_file)
      else
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
  
  if audio_process then
    vim.fn.jobstop(audio_process)
    audio_process = nil
  end
end

function M.send_audio_for_transcription(audio_file)
  
  local curl_cmd = string.format(
    'curl -X POST -F "file=@%s" %s',
    audio_file,
    M.config.transcribe_url
  )
  
  vim.fn.jobstart(curl_cmd, {
    stdout_buffered = true,
    stderr_buffered = true,
    on_stdout = function(_, data)
      if data and #data > 0 then
        local text = table.concat(data, "\n"):gsub("^%s*(.-)%s*$", "%1")
        text = text:gsub('^"(.-)"$', '%1')
        if text ~= "" then
          M.insert_text(text)
        end
      end
    end,
    on_stderr = function(_, data)
    end,
    on_exit = function(_, code)
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
