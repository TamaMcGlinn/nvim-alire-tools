-- Note the find_alire_toml_file function and deps are duplicated 
-- in the gpr_selector plugin
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

local function dir_name_of(full_path)
  if full_path == "/" then return "/" end
  return full_path:match(".*/([^/]+)$")
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
-- if you specify a starting dir, we ignore the current file and look in there
local function find_alire_toml_file(starting_dir)
    local dir = starting_dir
    if starting_dir == nil then
      local current_file = vim.api.nvim_buf_get_name(0)
      if current_file == "" then
        dir = vim.fn.getcwd()
      else
        if current_file:find("/alire.toml$") ~= nil then return current_file end
        dir = parent_of(current_file)
      end
    end
    while true do
        local alire_toml_file = dir .. "/alire.toml"
        if vim.fn.filereadable(alire_toml_file) > 0 then
          return alire_toml_file
        end
        dir = parent_of(dir)
        if dir == nil then return nil end
    end
end

-- execute cmd, with args passed as array
-- so that you can include spaces in arguments
-- get result including { .code .stderr .stdout }
local function cmd_arraycmd_ignore_errors(args, cwd_dir)
  local cmd_result = vim.system(args, {cwd = cwd_dir, text = true}):wait()
  return cmd_result
end

-- execute git command, get result including { .code .stderr .stdout }
local function cmd_ignore_errors(cmd, cwd_dir)
  return cmd_arraycmd_ignore_errors(vim.fn.split(cmd), cwd_dir)
end

-- execute command
-- throw error if it fails
local function cmd_arraycmd(args, cwd_dir)
  local cmd_result = cmd_arraycmd_ignore_errors(args, cwd_dir)
  local cmd = table.concat(args, " ")
  if cmd_result.code ~= 0 then
    error("Command " .. cmd .. " failed with exit code " .. cmd_result.code .. " and stderr: " .. cmd_result.stderr)
  end
  return cmd_result.stdout
end

-- execute command, throw error if it fails
local function cmd(cmd, cwd_dir)
  return cmd_arraycmd(vim.fn.split(cmd), cwd_dir)
end

-- execute git cmd with args passed as array,
-- so that you can include spaces in arguments
-- get result including { .code .stderr .stdout }
local function git_arraycmd_ignore_errors(args, repo_root)
  table.insert(args, 1, 'git')
  return cmd_arraycmd_ignore_errors(args, repo_root)
end

-- execute git command, get result including { .code .stderr .stdout }
local function git_ignore_errors(cmd, repo_root)
  return git_arraycmd_ignore_errors(vim.fn.split(cmd), repo_root)
end

-- execute git cmd with args passed as array,
-- so that you can include spaces in arguments
-- throw error if it fails
local function git_arraycmd(args, repo_root)
  local cmd = table.concat(args, " ")
  local git_result = git_arraycmd_ignore_errors(args, repo_root)
  if git_result.code ~= 0 then
    -- note git is actually run without -C [dir] but the error message specifies this
    -- so a user could try out the offending command as if run from the correct directory
    error("Command failed: 'git -C " .. repo_root .. " " .. cmd .. "' failed with exit code " .. git_result.code .. " and stderr: " .. git_result.stderr)
  end
  return git_result.stdout
end

-- execute git command, throw error if it fails
local function git(cmd, repo_root)
  return git_arraycmd(vim.fn.split(cmd), repo_root)
end

-- return true iff the HEAD commit modified alire.toml
local function latest_commit_changed_alire_toml(containing_dir)
  -- check the latest commit changed alire.toml, 
  --  (otherwise ask to make new version)
  local git_diff_tree_result = git("diff-tree --root --no-commit-id --name-only HEAD -r", containing_dir)
  local diff_files = split(git_diff_tree_result, '\n')
  for _, file in ipairs(diff_files) do
      if file == "alire.toml" then
          return true
      end
  end
  return false
end

local function commit_alire_toml_changes(new_version, repo_root)
  git("add .", repo_root)
  git_arraycmd({'commit', '-m', 'Version ' .. new_version}, repo_root)
end

-- extract the version number from an alire.toml file
local function get_version_in_toml_file(alire_toml_path)
  local file = io.open(alire_toml_path, "r")
  local version = nil
  if not file then
    error("Unable to read " .. alire_toml_path)
  end
  for line in file:lines() do
    -- line is, for example:
    -- version = "1.8.1"
    if line:match('^version = "[0-9]*%.[0-9]*%.[0-9]*"$') then
      version = vim.fn.substitute(line, 'version = "\\([0-9]*\\.[0-9]*\\.[0-9]*\\)".*', '\\1', '')
    end
  end
  file:close()
  return version
end

-- prompt for a new version based on the current one,
-- and replace the version line in containing_dir/alire.toml
local function update_alire_toml_file(containing_dir, repo_root)
  local alire_toml_path = containing_dir .. "/alire.toml"
  local new_lines = {}
  
  -- Read the contents of the file
  local file = io.open(alire_toml_path, "r")
  local version_updated = false
  if not file then
    error("Unable to read " .. alire_toml_path)
  end
  for line in file:lines() do
    -- line is, for example:
    -- version = "1.8.1"
    if line:match('^version = "[0-9]*%.[0-9]*%.[0-9]*"$') then
      if version_updated then
        file:close()
        error("Two lines match version regex in " .. alire_toml_path)
      end
      old_version = vim.fn.substitute(line, 'version = "\\([0-9]*\\.[0-9]*\\.[0-9]*\\)".*', '\\1', '')
      new_version = vim.fn.input('Version> ', old_version)
      line = 'version = "' .. new_version .. '"'
      if new_version == old_version then
        file:close()
        error("You must specify a new version number.")
      end
      version_updated = true
    end
    
    -- Add the modified line to the new_lines table
    table.insert(new_lines, line)
  end
  file:close()

  if not version_updated then
    error("No lines match version regex in " .. alire_toml_path)
  end
  
  -- Write the modified lines back to the file
  local new_file = io.open(alire_toml_path, "w")
  if new_file then
    for _, line in ipairs(new_lines) do
      new_file:write(line .. "\n")
    end
    new_file:close()
  end

  -- if the file is open, reload it
  local current_file = vim.api.nvim_buf_get_name(0)
  if current_file == alire_toml_path then
    vim.api.nvim_command('edit')
  else
    -- if the file is open, but in a different window, reload it there
    -- without switching the current window to that buffer
    local open_files = vim.fn.getbufinfo({bufloaded = 1, buflisted = 1})
    for i, file in ipairs(open_files) do
      if file.name == alire_toml_path then
        local cmd = "bufdo if expand('%:p') == '" .. alire_toml_path .. "' | :edit | endif"
        vim.api.nvim_command(cmd)
      end
    end
  end

  commit_alire_toml_changes(new_version, repo_root)
end

-- return whether HEAD is present in either origin/master or origin/main
local function head_is_pushed(repo_root)
  local remote_branches_with_HEAD = split(git("branch -r --contains HEAD", repo_root), '\n')
  for _, remote in ipairs(remote_branches_with_HEAD) do
      if remote:match("%s*origin/master%s*") or remote:match("%s*origin/main%s*") then
          return true
      end
  end
  return false
end

-- return alire community index repository path, for example:
-- ~/.config/alire/indexes/community/repo/
-- this contains index/[repo_id_prefix]/[repo_id]/[repo_id]_[version_nr].toml
local function get_alire_community_repo_path()
  local repositories = split(cmd("alr index"), '\n')
  for _, line in ipairs(repositories) do
    if line:match("^[0-9]*%s*community%s*[^%s]*%s*[^%s]*$") then
      return vim.fn.substitute(line, '^[0-9]*\\s*community\\s*\\S*\\s*', '', '')
    end
  end
  return nil
end

local function find_non_origin_remote(alire_community_repo_path)
  local remotes = split(git("remote -v", alire_community_repo_path), '\n')
  for _, line in ipairs(remotes) do
    if line:match("origin") then
      -- print("Origin is " .. line)
    else
      -- print("Non-origin remote is " .. line)
      local remote_line = split(line, '%s')
      return {name = remote_line[1], url = remote_line[2]}
    end
  end
  print("Warning: No non-origin remote found in " .. alire_community_repo_path)
  return nil
end

local function print_merge_request_link(alire_community_repo_path, alire_index_forked_remote_url)
  local alire_index_branch = git("rev-parse --abbrev-ref HEAD", alire_community_repo_path):sub(1,-2)
  local alire_index_upstream_remote = git("remote get-url origin", alire_community_repo_path):sub(1,-2)
  local alire_repo_fork = vim.fn.substitute(alire_index_forked_remote_url, '^.*github.com:\\([^/]*\\).*', '\\1', '')
  local mr_url = alire_index_upstream_remote .. "/compare/" .. alire_index_branch .. "..." .. alire_repo_fork .. ":" .. alire_index_branch
  print("Open a merge request at " .. mr_url)
end

-- publish new alire version for given alire.toml
-- TODO add verbose option that uncomments the print statements
local function publish_toml_file(alire_toml, skip_project_push)
  -- to determine git repo for given file,
  -- run git rev-parse --show-toplevel in containing dir
  local containing_dir = parent_of(alire_toml)
  local git_show_toplevel = git_ignore_errors("rev-parse --show-toplevel", containing_dir)
  if git_show_toplevel.code ~= 0 then
    print("Warning: No git repo found for " .. containing_dir .. "/alire.toml")
    return
  end
  local repo_root = git_show_toplevel.stdout:sub(1,-2)
  -- print("Git repo found: " .. repo_root)

  -- check git status, otherwise print and abort
  local git_update_result = git_ignore_errors("update-index --refresh", containing_dir)
  if git_update_result.code ~= 0 then
    print("Please commit your changes before doing `:AlirePublish`")
    return
  end

  if not latest_commit_changed_alire_toml(containing_dir) then
    print("The last commit did not update alire.toml")
    print("  > (A)bort")
    print("  > (U)pdate alire.toml")
    print("  > (P)ublish anyway")
    local choice = vim.fn.input("> ")
    if string.lower(choice) == "a" then
      return
    elseif string.lower(choice) == "u" then
      update_alire_toml_file(containing_dir, repo_root)
    elseif string.lower(choice) == "p" then
      print("This goes against convention, but okay, publishing commit without changing alire.toml file.")
    end
  end

  -- push to github
  if not skip_project_push and not head_is_pushed(repo_root) then
    git("push", repo_root)
  end

  -- get commit hash
  local commit_hash = git("rev-parse HEAD", repo_root):sub(1,-2)
  -- print("commit hash to publish: " .. commit_hash)

  -- write new toml file in community index
  local repo_id = dir_name_of(repo_root)
  -- optionally strip "_1.8.1_commith4sh" postfix
  repo_id = vim.fn.substitute(repo_id, "_[0-9]*\\.[0-9]*\\.[0-9]*_[a-z0-9]*$", "", "")
  local repo_id_prefix = repo_id:sub(1, 2)

  -- this contains index/[repo_id_prefix]/[repo_id]/[repo_id]_[version_nr].toml
  local alire_community_repo_path = get_alire_community_repo_path()
  -- print("Alire community repo found at " .. alire_community_repo_path)

  local repo_publish_location = alire_community_repo_path .. "/index/" .. repo_id_prefix .. "/" .. repo_id
  local new_version = get_version_in_toml_file(alire_toml)
  local new_version_toml_path = repo_publish_location .. "/" .. repo_id .. "-" .. new_version .. ".toml"
  if vim.fn.filereadable(new_version_toml_path) > 0 then
    -- print("Version " .. new_version .. " already published in " .. new_version_toml_path)
  else
    -- print("Needs publishing in " .. new_version_toml_path)

    -- read alire.toml file
    local alire_toml_file = io.open(alire_toml, "r")
    if not alire_toml_file then
      error("Unable to read " .. alire_toml)
    end
    local alire_release_contents = {}
    for line in alire_toml_file:lines() do
      table.insert(alire_release_contents, line)
    end
    alire_toml_file:close()
    table.insert(alire_release_contents, "")
    table.insert(alire_release_contents, "[origin]")
    table.insert(alire_release_contents, 'commit = "' .. commit_hash .. '"')
    -- note this only works if remote is called origin and points to GitHub!
    local repo_remote = git("remote get-url origin", repo_root):sub(1,-2)
    repo_remote = vim.fn.substitute(repo_remote, 'git@github.com:', 'git+https://github.com/', '')
    table.insert(alire_release_contents, 'url = "' .. repo_remote .. '"')
    table.insert(alire_release_contents, "")

    -- ensure dir repo_publish_location exists
    vim.fn.mkdir(repo_publish_location, 'p')

    -- write out release file
    local new_file = io.open(new_version_toml_path, "w")
    if not new_file then
      error("Unable to write to " .. new_version_toml_path)
    end
    for _, line in ipairs(alire_release_contents) do
      new_file:write(line .. "\n")
    end
    new_file:close()
    local alire_index_commit_msg = repo_id .. ' ' .. new_version
    -- print("Committing in " .. alire_community_repo_path .. " with message: " .. alire_index_commit_msg)
    git("add .", alire_community_repo_path)
    git_arraycmd({'commit', '-m', repo_id .. ' ' .. new_version}, alire_community_repo_path)
    -- TODO maybe an option to not push to release repo?
    local alire_index_forked_remote = find_non_origin_remote(alire_community_repo_path)
    if alire_index_forked_remote then
      git("push " .. alire_index_forked_remote.name, alire_community_repo_path)
      print_merge_request_link(alire_community_repo_path, alire_index_forked_remote.url)
    end
  end
end

local function publish(skip_project_push)
  -- look upward from the current file for alire.toml
  local alire_toml = find_alire_toml_file()
  if alire_toml == nil then
    print("Warning: No alire.toml found above " .. vim.api.nvim_buf_get_name(0))
    return
  end
  publish_toml_file(alire_toml, skip_project_push==1)
end

return {find_alire_toml_file = find_alire_toml_file, publish_toml_file = publish_toml_file, publish = publish, update_alire_toml_file = update_alire_toml_file, publish_toml_file = publish_toml_file, get_version_in_toml_file = get_version_in_toml_file}
