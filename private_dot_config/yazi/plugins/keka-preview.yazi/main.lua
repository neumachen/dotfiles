--- @since 26.1.22
-- Yazi previewer that lists archive contents via Keka's bundled 7zz.
-- `keka 7zz l -ba <archive>` produces a clean tabular listing for every
-- format keka/unar handles (zip, 7z, rar, tar, gz, tgz, bz2, xz, zst, ...).

local M = {}

function M:peek(job)
  local child, code = Command('keka')
    :arg({ '7zz', 'l', '-ba', tostring(job.file.url) })
    :stdout(Command.PIPED)
    :stderr(Command.PIPED)
    :spawn()

  if not child then
    return ya.preview_widget(
      job,
      ui.Text(string.format('Failed to spawn `keka 7zz` (%s)', tostring(code)))
        :area(job.area)
    )
  end

  local i, lines = 0, {}
  local limit = job.skip + job.area.h
  while i < limit do
    local line, event = child:read_line()
    if event ~= 0 then break end
    i = i + 1
    if i > job.skip then lines[#lines + 1] = (line:gsub('\r?\n$', '')) end
  end
  child:start_kill()

  if #lines == 0 then lines[1] = '(empty archive listing)' end

  ya.preview_widget(job, ui.Text(table.concat(lines, '\n')):area(job.area))
end

function M:seek(job)
  local h = job.area.h
  local step = math.floor(job.units * h / 10)
  ya.emit('peek', {
    math.max(0, job.skip + step),
    only_if = job.file.url,
  })
end

return M
