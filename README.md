# python-cell.el

MATLAB-like cells in python

## Key Bindings

`Ctrl-Return` - send contents of the current cell to an inferior python process
`Ctrl-Down` - move to the beginning of the next cell
`Ctrl-Up` - move to the beginning of the previous cell

##  Installation

If you use el-get you can use this recipe to download and install
`python-cell-mode`:

```cl
  (:name python-cell
      :description "MATLAB-like cells in python"
      :type github
      :pkgname "thisch/python-cell.el")
  ```

If not, place `python-cell.el` in your load path.

To enable `python-cell` mode in all python buffers (Emacs 24+):

```cl
  (require 'python-cell)
  (add-hook 'python-mode-hook #'python-cell-mode 1)
  ```

To temporarily activate `python-cell` mode in an open (python) buffer:

    M-x python-cell-mode

## Customization:

    M-x customize-group RET python-cell RET

## TODO

* melpa package
* add support for more programming languages
* imenu support
