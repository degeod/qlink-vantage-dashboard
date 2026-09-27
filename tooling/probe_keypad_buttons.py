import socket
import time


def run(cmds, wait=0.3):
    c = socket.create_connection(("192.168.1.33", 3041), timeout=4)
    c.settimeout(1.0)
    buf = b""

    def send(cmd):
        nonlocal buf
        c.sendall((cmd + "\r").encode("ascii"))
        time.sleep(wait)
        try:
            while True:
                chunk = c.recv(4096)
                if not chunk:
                    break
                buf += chunk
        except socket.timeout:
            pass

    send("VOS 0 1")
    for cmd in cmds:
        before = len(buf)
        send(cmd)
        reply = buf[before:].decode("ascii", "replace").replace("\r", " | ")
        print(f"==> {cmd}")
        print(reply or "(no reply)")
    c.close()


print("=== all switches 0-9 on station 1 ===")
run([f"VSW# 11 1 {n} 6" for n in range(0, 10)])
