FROM medzik/archlinux:latest

COPY ssh_config /ssh_config
COPY makepkg.x86-64.conf /etc/makepkg.x86-64.conf
COPY makepkg.x86-64-v3.conf /etc/makepkg.x86-64-v3.conf

RUN pacman -Syu --noconfirm \
      jq \
      git \
      wget \
      curl  \
      rsync  \
      sshpass \
      base-devel \
      multilib-devel \
      pacman-contrib \
 && yes | pacman -Scc
