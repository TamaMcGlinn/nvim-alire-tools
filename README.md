# Ada Alire NeoVim tools

NeoVim functions you can bind for publishing Alire packages.

This is useful when modifying an alire-packaged source,
as it can automatically writes the current alire.toml file
into the alire package repo, pushes that and open a MR
to publish that version.

It will then repeatedly check if the parent project is also 
an alire package, and ask if we want to publish that too.

If the alire project to publish has not bumped the version,
it offers to create and push a commit creating a new alire version first.

## Install

Use your favourite plugin manager, e.g. for Plug:

```vim
Plug 'TamaMcGlinn/nvim-alire-tools'
```

## Example bindings

```vim
lua require("alire_tools")
nnoremap <leader>ap :AlirePublish<CR>
```
