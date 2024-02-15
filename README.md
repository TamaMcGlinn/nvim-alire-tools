# Ada Alire NeoVim tools

NeoVim functions you can bind for publishing Alire packages.

This is useful when modifying an alire-packaged source,
as it can automatically writes the current alire.toml file
into the alire package repo, pushes that and open a merge request
to publish that version.

If the alire project to publish has not bumped the version,
it offers to create and push a commit creating a new alire version first.

(TODO - PR welcome; then repeatedly check if the parent project is also 
an alire package, and ask if we want to publish that too.)

## Install

Use your favourite plugin manager, e.g. for Plug:

```vim
Plug 'TamaMcGlinn/nvim-alire-tools'
```

## Example bindings

```vim
lua require("alire_tools")
nnoremap <leader>ap :AlirePublish<CR>  -- publish
nnoremap <leader>aP :AlirePublish!<CR> -- publish without pushing project
```

The commands only differ when the alire.toml file still needs to be updated,
or when the commit to be published has not been pushed yet. Pushing is necessary,
otherwise the alire release will be invalid.

There is not yet an option to omit the alire-index push, since I don't see
the use-case. If you need it, look for the TODO, implement it as an option
and send me a merge request.

## Call internals

If you want to reach in to the internals to make your own tool,
here's a starting point:

```lua
local alire_tools = require'alire_tools'
local nearest_toml_file = alire_tools.find_alire_toml_file()
```
