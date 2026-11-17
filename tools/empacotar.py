# -*- coding: utf-8 -*-
r"""Faz o pacote .tar.gz do site da Intrepid Parallel, para a porta de publicação do servidor, e escreve-o no stdout.

    python tools/empacotar.py        o site, na raiz do domínio

O .cmd de publicação liga-o ao ssh:  python tools\empacotar.py | ssh … publicar raiz

17/11/2026: o site saiu da pasta raiz\ da mBrothers para a raiz deste repositório. O pacote vai por uma LISTA do que é
do site: no primeiro nível, um nome que não esteja nem na lista nem no que fica de fora pára tudo, para nunca subir por
engano o que é só do repositório (o .git, as ferramentas, o email\ do logotipo dos emails, o 404 do GitHub).

⛔ Porque não o tar do Windows (06/11/2026): marcava as pastas «só de leitura» (o OneDrive põe esse atributo às pastas) e
   o servidor não conseguia escrever nelas; e juntava as marcas do Windows (SCHILY.fflags). Aqui as permissões são sempre
   as normais (pastas 755, ficheiros 644), sem dono, no formato GNU, sem extensões, sem ligações nem ficheiros especiais.
⛔ A porta do servidor recusa no primeiro nível os nomes mbrothers, logviewer, explorerfocus, email, raiz e saude, e o que
   comece por um ponto (ENG_COB-000082).
"""
import os
import sys
import tarfile

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LINGUAS = {"pt", "br", "es", "fr", "it", "de", "pl", "ru", "ar", "hi", "zh", "zh-tw", "ja", "ko"}
VAI = {"index.html", "legal.html", "llms.txt", "og.png", "robots.txt", "sitemap.xml", "favicon.ico", "assets", "fonts"} | LINGUAS
FICA = {".git", ".gitignore", ".gitattributes", ".claude", "tools", "i18n", "email", "icone", "404.html", "README.md"}
PROIBIDOS = {"mbrothers", "logviewer", "explorerfocus", "email", "raiz", "saude"}


def normal(ti):
    ti.uid = ti.gid = 0
    ti.uname = ti.gname = ""
    ti.mode = 0o755 if ti.isdir() else 0o644
    return ti


def juntar(tar, caminho, nome):
    ti = tar.gettarinfo(caminho, arcname=nome)
    if not (ti.isfile() or ti.isdir()):
        sys.exit("[ERRO] %s não é um ficheiro nem uma pasta normal" % caminho)
    ti = normal(ti)
    if ti.isfile():
        with open(caminho, "rb") as fh:
            tar.addfile(ti, fh)
    else:
        tar.addfile(ti)


def site(tar):
    if not os.path.isfile(os.path.join(RAIZ, "index.html")):
        sys.exit("[ERRO] falta o index.html")
    for nome in os.listdir(RAIZ):
        if nome in VAI or nome in FICA or nome.lower().endswith(".cmd"):
            continue
        sys.exit("[ERRO] «%s» no primeiro nível não está na lista do que vai nem do que fica: acrescentá-lo a uma delas" % nome)
    for nome in VAI:
        if nome.lower() in PROIBIDOS or nome.startswith("."):
            sys.exit("[ERRO] a porta recusa «%s» no primeiro nível" % nome)
    juntar(tar, RAIZ, ".")
    for pasta, pastas, ficheiros in os.walk(RAIZ):
        rel = os.path.relpath(pasta, RAIZ)
        if rel == ".":
            pastas[:] = [p for p in pastas if p in VAI]
            ficheiros = [f for f in ficheiros if f in VAI]
        pastas.sort()
        for p in pastas:
            caminho = os.path.join(pasta, p)
            if os.path.islink(caminho):
                sys.exit("[ERRO] ligação: %s" % caminho)
            juntar(tar, caminho, "./" + os.path.relpath(caminho, RAIZ).replace(os.sep, "/"))
        for f in sorted(ficheiros):
            caminho = os.path.join(pasta, f)
            juntar(tar, caminho, "./" + os.path.relpath(caminho, RAIZ).replace(os.sep, "/"))


def main():
    if len(sys.argv) != 1:
        sys.exit("uso: python tools/empacotar.py")
    if sys.stdout.isatty():
        sys.exit("[ERRO] o pacote é binário: liga-o ao ssh com |, ou manda-o para um ficheiro com >")
    with tarfile.open(fileobj=sys.stdout.buffer, mode="w|gz", format=tarfile.GNU_FORMAT) as tar:
        site(tar)
    sys.stdout.buffer.flush()


if __name__ == "__main__":
    main()
