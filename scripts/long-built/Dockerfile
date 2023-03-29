FROM ghcr.io/built-aur/packages:latest

ARG PACKAGE
ENV PACKAGE=$PACKAGE

COPY scripts/long-built/build.sh /home/build/build.sh

# Expect archive with files required for building created by makepkg --allsource
COPY *.src.tar.gz /home/build/

RUN chown -R build /home/build
RUN tar xf /home/build/*.src.tar.gz -C /home/build --strip 1 && rm /home/build/*.src.tar.gz

RUN pacman -Sy archlinux-keyring

RUN pacman -Syu --noconfirm && \
    su -c "cd && makepkg --nobuild --noextract --syncdeps --noconfirm" build && \
    su -c "cd && makepkg --nobuild --noextract --syncdeps --noconfirm" build && \
    su -c "cd && makepkg --nobuild --noextract --syncdeps --noconfirm" build

RUN ls -lah /home/build

RUN echo $(date +"%s") > /etc/buildtime

USER build

ENTRYPOINT [ "/bin/bash", "/home/build/build.sh" ]
