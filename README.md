## Set up

```bash
cd ~/.config
git init
git remote add origin https://github.com/angkitkhadka/dotfiles.git
git fetch origin
git checkout -f -B master origin/master
git clone https://github.com/tmux-plugins/tpm ~/.config/tmux/plugins/tpm

# prefix + I to install plugins
```
