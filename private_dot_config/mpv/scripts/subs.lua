local msg = require 'mp.msg'
local utils = require 'mp.utils'

local sub_dirs = {'Subs', 'subs','sub', 'Subs', 'Subtitles', 'subtitles'}
local sub_lang = 'English'

local function find_and_add()
  local path = mp.get_property('path', '')
  local dir, _fn = utils.split_path(path)

  for i, sub_dir in ipairs(sub_dirs) do
    local sd = utils.join_path(dir, sub_dir)

    local list = utils.readdir(sd, 'files')
    if not list then
      return
    end
    if #list == 0 then
      local fn_no_ext = mp.get_property('filename/no-ext')
      sd = utils.join_path(sd, fn_no_ext)
      list = utils.readdir(sd, 'files')
      if not list or #list == 0 then
        return
      end
    end

    table.sort(list)
    for i = 1,#list do
      local sub = string.match(list[i], '^(.+' .. sub_lang .. '.+)$')
      if sub then
        mp.commandv('sub-add', utils.join_path(sd, sub), 'select')
      end
    end
  end
end

mp.register_event('file-loaded', find_and_add)
