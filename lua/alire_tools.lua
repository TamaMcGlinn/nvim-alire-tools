-- Note these functions are duplicated in gpr_selector
-- because I don't want to make a vim library as a dependency
-- each is hardcoded to a filetype, not generic

local function split(inputstr, sep)
    if sep == nil then sep = "%s" end
    local t = {}
    for str in string.gmatch(inputstr, "([^" .. sep .. "]+)") do
        table.insert(t, str)
    end
    return t
end

local function parent_of(dir)
    if dir == "/" then return nil end
    local parent = dir:match("(.*)/")
    if parent == "" then
        return "/"
    else
        return parent
    end
end

-- search upwards to find alire.toml files and return their paths
-- 1) if the file is alire.toml, return that
-- 2) otherwise, keep going upwards until an alire.toml file was found,
local function find_alire_toml_file()
    local current_file = vim.api.nvim_buf_get_name(0)
    if current_file:find("/alire.toml$") ~= nil then return current_file end
    local dir = parent_of(current_file)
    while true do
        local alire_toml_file = dir .. "/alire.toml"
        if vim.fn.filereadable(alire_toml_file) > 0 then
          return alire_toml_file
        end
        dir = parent_of(dir)
        if dir == nil then return nil end
    end
end

local function publish()
  -- look upward from the current file for alire.toml
  local alire_toml = find_alire_toml_file()
  if alire_toml == nil then
    print("No alire.toml found upward from " .. vim.api.nvim_buf_get_name(0))
    return
  end
  -- print("Found " .. alire_toml)

  -- check git status, otherwise print and abort
  -- check the latest commit changed alire.toml, 
  --  {otherwise ask to make new version)
  -- push to github
  -- get commit hash
  -- write new toml file in
  -- ~/.config/alire/indexes/community/repo/index/[repo_id_prefix]/[repo_id]/
end

return {find_alire_toml_file = find_alire_toml_file, publish = publish}
