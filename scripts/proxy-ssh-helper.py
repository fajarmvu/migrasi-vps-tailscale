#!/usr/bin/env python3
"""ProxyCommand helper: SSH melalui egress proxy HTTP (lingkungan sandbox/terbatas).
Penggunaan: proxy-ssh-helper.py <host> <port>
Membaca host/port/kredensial proxy dari env HTTPS_PROXY.
Port 3130 = relay tailnet pada runtime proxy (lihat dokumentasi Tailscale);
jangan gunakan port egress HTTPS biasa untuk alamat tailnet.
Contoh ~/.ssh/config:
    Host vps-tujuan
        HostName <IP_TAILSCALE_TUJUAN>
        User ubuntu
        ProxyCommand python3 ~/scripts/proxy-ssh-helper.py %h %p
"""
import os, socket, base64, sys
from urllib.parse import urlparse

def main():
    host, port = sys.argv[1], int(sys.argv[2])
    u = urlparse(os.environ["HTTPS_PROXY"])
    proxy = (u.hostname, 3130)  # relay tailnet; sesuaikan bila dokumentasi berubah
    auth = base64.b64encode(f"{u.username}:{u.password}".encode()).decode()
    s = socket.create_connection(proxy, timeout=20)
    s.sendall(
        f"CONNECT {host}:{port} HTTP/1.1\r\n"
        f"Host: {host}:{port}\r\n"
        f"Proxy-Authorization: Basic {auth}\r\n\r\n".encode()
    )
    resp = b""
    while b"\r\n\r\n" not in resp:
        chunk = s.recv(4096)
        if not chunk:
            sys.exit(1)
        resp += chunk
    if b" 200 " not in resp.split(b"\r\n")[0]:
        sys.exit(1)
    s.setblocking(True)
    import threading
    s_fd, in_fd, out_fd = s.fileno(), sys.stdin.fileno(), sys.stdout.fileno()
    def fwd(infd, outfd):
        try:
            while True:
                d = os.read(infd, 65536)
                if not d:
                    break
                os.write(outfd, d)
        except OSError:
            pass
    t1 = threading.Thread(target=fwd, args=(in_fd, s_fd), daemon=True)
    t2 = threading.Thread(target=fwd, args=(s_fd, out_fd), daemon=True)
    t1.start(); t2.start(); t1.join(); t2.join()

if __name__ == "__main__":
    main()
