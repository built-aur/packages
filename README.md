# Build AUR

## How to use?

First, install the primary key - it can then be used to install our mirrorlist

```bash
sudo pacman-key --recv-key 02213A0493457E96
sudo pacman-key --lsign-key 02213A0493457E96
sudo pacman -U 'https://built-aur.medzik.workers.dev/built-mirrorlist.pkg.tar.xz'
```

Then add the repo to pacman.conf

### If you using x86-64

```bash
echo '
[built]
SigLevel = DatabaseOptional
Include = /etc/pacman.d/built-mirrorlist' | sudo tee --append /etc/pacman.conf
```

### If you using x86-64-v3

```bash
echo '
[built]
SigLevel = DatabaseOptional
Include = /etc/pacman.d/built-mirrorlist-x86-64-v3' | sudo tee --append /etc/pacman.conf
```
