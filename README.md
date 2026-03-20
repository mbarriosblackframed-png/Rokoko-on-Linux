# Rokoko Smartsuit Pro II on Linux — Complete Guide
**by Black Frame Digital** | [blackframed.com](https://blackframed.com) | [linkedin.com/in/manuvfx](https://linkedin.com/in/manuvfx)

> ☕ If this guide helped you, [buy me a coffee](Ko-fi.com/barrmanuel)

---

## What we achieved

Full support for the **Rokoko Smartsuit Pro II** and **Smart Gloves** on **Linux** (tested on Linux Mint 22 / Ubuntu 24.04), including:

- ✅ Automatic firmware updates for suit and gloves via USB
- ✅ WiFi pairing from Linux — no native Windows required
- ✅ Real-time motion capture via WiFi → Linux
- ✅ Rokoko Studio running in Bottles/Wine

---

## Architecture

```
Suit/Gloves
    │
    ├─── USB ──► Windows VM (KVM) ──► Rokoko Studio (pairing / firmware)
    │
    └─── WiFi ──► Linux UDP port 14041 ──► Rokoko Studio (Bottles)
```

> **Important note:** Rokoko Studio does not use the Windows WiFi adapter to scan networks. Instead, it asks the suit via USB to scan using its own onboard WiFi chipset and report available networks. This is why it works perfectly from a VM with no WiFi adapter.

---

## Prerequisites

### Required packages

```bash
sudo apt install -y \
  qemu-system-x86 libvirt-daemon-system libvirt-clients \
  bridge-utils virt-manager usbredirect

sudo usermod -aG libvirt,kvm $USER
```

After running `usermod`, **log out and log back in** for the group changes to take effect. Then:

```bash
sudo systemctl enable --now libvirtd
```

### Additional software

- **Tiny11 2311** — Windows 11 without bloatware, ~3.7GB. Download from [archive.org/details/tiny11-2311](https://archive.org/details/tiny11-2311). Choose the **ISO IMAGE** option.
- **Bottles** — install from Flathub or your distro's software manager.
- **Rokoko Studio** — download the official `.exe` installer from [rokoko.com](https://rokoko.com).

---

## Files included in this repository

This repository includes 4 ready-to-use files. Below you'll find what each one does, where it goes, and what you need to customize.

---

### File 1: `rokoko-usbredirect.sh`

**What it does:** The heart of the system. A daemon that listens to USB events in real time using `udevadm`. When you plug in the suit or a glove, it automatically redirects the device to the Windows VM using `usbredirect`. When you unplug it, it closes the connection cleanly. Supports both the suit (`0483:a432`) and gloves (`0483:5740`) simultaneously on separate ports (7700 and 7701).

**Where it goes:**
```
/usr/local/bin/rokoko-usbredirect.sh
```

**How to install:**
```bash
sudo cp rokoko-usbredirect.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/rokoko-usbredirect.sh
```

---

### File 2: `rokoko-usbredirect.service`

**What it does:** A systemd service that starts the daemon automatically when Linux boots and restarts it if it crashes. Without this file, you would need to run the script manually every time.

**Where it goes:**
```
/etc/systemd/system/rokoko-usbredirect.service
```

**How to install:**
```bash
sudo cp rokoko-usbredirect.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable rokoko-usbredirect.service
sudo systemctl start rokoko-usbredirect.service
```

Verify it's running:
```bash
sudo systemctl status rokoko-usbredirect.service
```
You should see `Active: active (running)`.

---

### File 3: `99-rokoko.rules`

**What it does:** A udev rule that prevents Linux from taking control of the suit's USB device when it's plugged in, which would otherwise conflict with the VM redirection.

**Where it goes:**
```
/etc/udev/rules.d/99-rokoko.rules
```

**How to install:**
```bash
sudo cp 99-rokoko.rules /etc/udev/rules.d/
sudo udevadm control --reload-rules
```

---

### File 4: `win11.xml`

**What it does:** Defines the Windows (Tiny11) VM for KVM. Includes all necessary configuration: UEFI without Secure Boot, emulated TPM, and two TCP channels for USB redirect (ports 7700 and 7701). This VM is only used for WiFi pairing and firmware updates — not for motion capture.

**Before importing the VM, complete these steps:**

#### Step A — Create the virtual disk

The VM needs a disk to install Windows on. Create it with this command (you can change the path if you want to store it on a different drive):

```bash
sudo qemu-img create -f qcow2 /var/lib/libvirt/images/rokoko_vm.qcow2 40G
```

#### Step B — Edit the disk path in the XML

Open `win11.xml` with any text editor and find this line (around line 52):

```xml
<source file='/var/lib/libvirt/images/rokoko_vm.qcow2'/>
```

If you created the disk at a different path in Step A, update this line to match. If you used the exact same command from Step A, no changes are needed.

#### Step C — Verify OVMF is available

The XML uses OVMF UEFI firmware files. Check they exist on your system:

```bash
ls /usr/share/OVMF/OVMF_CODE_4M.fd
```

If the file exists, you'll see its name printed back. If you get a "No such file" error, install OVMF:

```bash
sudo apt install ovmf -y
```

#### Step D — Import the VM

```bash
sudo virsh define win11.xml
```

If the command completes without errors, the VM is registered. You can see it in virt-manager.

#### Step E — Install Tiny11 in the VM

1. Open virt-manager
2. Select the `win11` VM and click **Edit → Details**
3. Under **SATA CDROM 1**, click **Connect** and select the Tiny11 ISO you downloaded
4. Under **Boot Options**, make sure the CDROM is set as the first boot device
5. Start the VM and install Windows normally

Once Windows is installed, install **SPICE Guest Tools** inside the VM to enable copy/paste between Linux and Windows, and automatic screen resolution. Download them from inside the VM:
```
https://www.spice-space.org/download/windows/spice-guest-tools/spice-guest-tools-latest.exe
```

Finally, install **Rokoko Studio** inside the VM using the official `.exe` installer.

---

## Network configuration

For the suit to know which IP to send motion data to, you need a fixed IP on your dedicated WiFi network.

### Static IP on Linux

First, find the name of your WiFi connection:
```bash
nmcli connection show
```
You'll see a list — find the one that matches your Rokoko network. Then assign the static IP (replace `"YourNetworkName"` with the exact name you saw):

```bash
nmcli con mod "YourNetworkName" \
  ipv4.addresses 192.168.0.100/24 \
  ipv4.gateway 192.168.0.1 \
  ipv4.method manual
nmcli con up "YourNetworkName"
```

Verify it worked:
```bash
ip addr show | grep "inet "
```
You should see `192.168.0.100` on your WiFi adapter.

### Reserve IPs in your router

This prevents the router from changing the IP addresses of your Rokoko devices between sessions.

1. Open your router's web interface — usually at `http://192.168.0.1`
2. Find the **Network → DHCP Server** section or similar
3. Change the **Address Pool** to start at `192.168.0.150` so the lower IPs are reserved for static assignment
4. Under **Address Reservation**, add one entry per device

To find the MAC addresses of your Rokoko devices, turn them on and connect them to the network — they'll appear in the router's **DHCP Client List** with their MAC and assigned IP.

Recommended reservations:

| Device | Recommended IP |
|---|---|
| Your Linux PC | 192.168.0.100 |
| Smartsuit Pro II | 192.168.0.150 |
| Right glove | 192.168.0.151 |
| Left glove | 192.168.0.152 |

Save the changes in your router.

---

## WiFi pairing the suit

This step tells the suit which network to connect to and which Linux IP to send data to.

1. Plug the suit in via USB — the daemon detects it automatically within seconds
2. Open Rokoko Studio in the Windows VM
3. The suit will appear as connected
4. Go to device settings and find **WiFi Setup**
5. Select your dedicated WiFi network from the dropdown — the suit scans networks using its own chipset
6. Enter the network password
7. In **Receiver IP**, type your Linux IP: `192.168.0.100`
8. In **Receiver port**, leave `14041`
9. Click **Apply Settings**

To verify the pairing worked, unplug the USB, turn on the suit on battery only, and run this on Linux:

```bash
sudo tcpdump -i wlp3s0 udp port 14041
```

Replace `wlp3s0` with your WiFi adapter name (you can find it with `ip link show`). If you see packets arriving from `192.168.0.150`, the pairing was successful.

---

## Rokoko Studio on Linux (Bottles)

To use Rokoko Studio directly on Linux without needing the VM:

1. Open Bottles and create a new bottle:
   - Type: **Application**
   - Runner: **soda** (latest available version)
2. Inside the bottle, install the Rokoko Studio `.exe`
3. Open Rokoko Studio — it will detect the suit via WiFi automatically because UDP packets are already arriving at your Linux machine on port 14041

---

## Full system verification

```bash
# VM registered and available
sudo virsh list --all

# USB redirect daemon active
sudo systemctl status rokoko-usbredirect.service

# Suit data arriving at Linux (turn on suit on battery)
sudo tcpdump -i wlp3s0 udp port 14041

# Watch daemon logs in real time when plugging/unplugging
sudo journalctl -u rokoko-usbredirect.service -f
```

---

## Troubleshooting

**VM won't start:**
```bash
sudo systemctl start libvirtd
sudo virsh start win11
```

**Suit doesn't appear in Rokoko Studio (VM):**
```bash
# Check what's happening with the daemon
sudo journalctl -u rokoko-usbredirect.service -n 30
# Verify daemon is active
sudo systemctl status rokoko-usbredirect.service
```

**No UDP packets arriving when running tcpdump:**
```bash
# Allow port through firewall
sudo ufw allow 14041/udp
# Verify you're listening on the right adapter
ip link show
```

**Firmware update fails midway:**
The update process triggers several automatic disconnect/reconnect cycles. The daemon handles these without any manual intervention. If it fails, simply try again from Rokoko Studio with the suit connected via USB.

---

## Credits

Developed by **Manu** — VFX Supervisor, founder of **Black Frame Digital SAS**, Bogotá, Colombia.

- 🌐 [blackframed.com](https://blackframed.com)
- 💼 [linkedin.com/in/manuvfx](https://linkedin.com/in/manuvfx)
- ☕ [Buy me a coffee](Ko-fi.com/barrmanuel)

---

*Unofficial solution. Rokoko does not offer Linux support. Tested on Linux Mint 22 (Ubuntu 24.04 Noble).*
