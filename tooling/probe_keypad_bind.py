import socket
import time


def session(cmds, wait=0.45):
    c = socket.create_connection(("192.168.1.33", 3041), timeout=5)
    c.settimeout(1.5)
    buf = b""

    def send(cmd):
        nonlocal buf
        payload = (cmd + "\r").encode("ascii")
        c.sendall(payload)
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
    out = []
    for cmd in cmds:
        before = len(buf)
        send(cmd)
        reply = buf[before:].decode("ascii", "replace").replace("\r", " | ")
        out.append((cmd, reply))
        print(f"==> {cmd}")
        print(reply or "(no reply)")
    c.close()
    return out


print("=== who answers on stations 0,1,20 ===")
session(
    [
        "VLS# 11 0",
        "VLS# 11 1",
        "VLS# 11 20",
    ]
)

print("\n=== re-bind serial 4077006 to station 1 (like earlier fix) ===")
session(
    [
        "VSC 11 1 4077006",
        "VLS# 11 1",
        "VLB 11 1 1 1 40",
        "VSW# 11 1 1 6",
        "VGB# 11 1 1 1",
        "VSW# 11 1 8 6",
    ]
)

print("\n=== also try bind on station 0 then back to 1 ===")
session(
    [
        "VSC 11 0 4077006",
        "VLS# 11 0",
        "VSC 11 1 4077006",
        "VLS# 11 1",
    ]
)
