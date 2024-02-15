command! -bang AlirePublish call luaeval("require'alire_tools'.publish(" .. <bang>0 .. ")")
