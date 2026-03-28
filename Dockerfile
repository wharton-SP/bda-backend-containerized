FROM archlinux:latest

RUN pacman -Syu --noconfirm postgresql-libs

WORKDIR /app

COPY build/bda_api .

EXPOSE 1890

CMD ["./bda_api"]