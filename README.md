# python-cell.el

MATLAB-like cells in python

![Screenshot of python-cell mode in action](http://farm4.staticflickr.com/3710/9448464257_6a7b2baf2a_o_d.png)

## Key Bindings

`Ctrl-Return` - send contents of the current cell to an inferior python process

`Ctrl-Down` - move to the beginning of the next cell

`Ctrl-Up` - move to the beginning of the previous cell

##  Installation

### el-get

If you use el-get you can use this recipe to download and install
`python-cell-mode`:

```lisp
(:name python-cell
      :description "MATLAB-like cells in python"
      :type github
      :pkgname "thisch/python-cell.el")
```

### MELPA

If you're an Emacs 24 user or you have a recent version of package.el you can install python-cell-mode from the MELPA repository.

### Manual

Just drop `python-cell.el` somewhere in your load path, e.g., `~/.emacs.d/vendor`.

```lisp
(add-to-list 'load-path "~/emacs.d/vendor")
(require 'python-cell)
```

## Usage

To enable `python-cell` mode in all python buffers (Emacs 24+):

```lisp
(add-hook 'python-mode-hook #'python-cell-mode 1)
```

To temporarily activate `python-cell` mode in an open (python) buffer:

    M-x python-cell-mode

## Customization:

    M-x customize-group RET python-cell RET

## TODO

* add support for more programming languages
* imenu support
