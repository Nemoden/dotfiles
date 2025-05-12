local M = {}

function M.pretty_print_json_range(line1, line2)
  local buf = 0
  local start_line = line1 - 1       -- 0-based inclusive
  local end_line = line2             -- 0-based exclusive

  if start_line < 0 or end_line <= start_line then
    vim.notify("Invalid selection range", vim.log.levels.ERROR)
    return
  end

  local lines = vim.api.nvim_buf_get_lines(buf, start_line, end_line, false)
  local content = table.concat(lines, "\n")

  local tmpfile_in = vim.fn.tempname()
  local tmpfile_out = vim.fn.tempname()

  local f = io.open(tmpfile_in, "w")
  if not f then
    vim.notify("Failed to write temp input file", vim.log.levels.ERROR)
    return
  end
  f:write(content)
  f:close()

  local cmd = string.format("jq . %q > %q 2>/dev/null", tmpfile_in, tmpfile_out)
  local exit_code = os.execute(cmd)
  os.remove(tmpfile_in)

  if exit_code ~= 0 then
    vim.notify("jq failed: invalid JSON?", vim.log.levels.ERROR)
    os.remove(tmpfile_out)
    return
  end

  local formatted = vim.fn.readfile(tmpfile_out)
  os.remove(tmpfile_out)

  vim.api.nvim_buf_set_lines(buf, start_line, end_line, false, formatted)
  vim.notify("Formatted selected JSON", vim.log.levels.INFO)
end

return M
