# Rokoko Smartsuit Pro II en Linux
**by Black Frame Digital** | [blackframed.com](https://blackframed.com) | [linkedin.com/in/manuvfx](https://linkedin.com/in/manuvfx)

> ☕ Si esta guía te fue útil, [invítame un café](https://Ko-fi.com/barrmanuel)

---

## ¿Qué logramos?

Hacer funcionar el **Rokoko Smartsuit Pro II** y los **Smart Gloves** completamente en **Linux** (probado en Linux Mint 22 / Ubuntu 24.04), incluyendo:

- ✅ Updates de firmware del traje y guantes via USB — automático
- ✅ Pairing WiFi desde Linux — sin Windows nativo
- ✅ Captura de movimiento en tiempo real via WiFi → Linux
- ✅ Rokoko Studio corriendo en Bottles/Wine

---

## Arquitectura

```
Traje/Guantes
    │
    ├─── USB ──► VM Windows (KVM) ──► Rokoko Studio (pairing / firmware)
    │
    └─── WiFi ──► Linux puerto UDP 14041 ──► Rokoko Studio (Bottles)
```

> **Nota importante:** Rokoko Studio no usa el WiFi de Windows para escanear redes. Le pide al traje via USB que escanee con su propio chipset y reporta las redes disponibles. Por eso funciona perfectamente desde una VM sin adaptador WiFi.

---

## Requisitos previos

### Paquetes necesarios

```bash
sudo apt install -y \
  qemu-system-x86 libvirt-daemon-system libvirt-clients \
  bridge-utils virt-manager usbredirect

sudo usermod -aG libvirt,kvm $USER
```

Después de correr `usermod`, **cierra sesión y vuelve a entrar** para que los grupos tomen efecto. Luego:

```bash
sudo systemctl enable --now libvirtd
```

### Software adicional

- **Tiny11 2311** — Windows 11 sin bloatware, ~3.7GB. Descárgalo desde [archive.org/details/tiny11-2311](https://archive.org/details/tiny11-2311). Elige la opción **ISO IMAGE**.
- **Bottles** — instálalo desde Flathub o el gestor de software de tu distro.
- **Rokoko Studio** — descarga el instalador `.exe` oficial desde [rokoko.com](https://rokoko.com).

---

## Archivos incluidos en este repositorio

Este repositorio incluye 4 archivos listos para usar. A continuación se explica qué hace cada uno, dónde va y qué debes personalizar.

---

### Archivo 1: `rokoko-usbredirect.sh`

**Qué hace:** Es el corazón del sistema. Un daemon que escucha eventos USB en tiempo real usando `udevadm`. Cuando detectas que conectas el traje o un guante por USB, lo redirige automáticamente a la VM de Windows usando `usbredirect`. Cuando lo desconectas, cierra la conexión limpiamente. Soporta el traje (`0483:a432`) y los guantes (`0483:5740`) simultáneamente en puertos separados (7700 y 7701).

**Dónde va:**
```
/usr/local/bin/rokoko-usbredirect.sh
```

**Cómo instalarlo:**
```bash
sudo cp rokoko-usbredirect.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/rokoko-usbredirect.sh
```

---

### Archivo 2: `rokoko-usbredirect.service`

**Qué hace:** Servicio systemd que arranca el daemon automáticamente cuando inicia Linux y lo reinicia si falla. Sin este archivo, tendrías que ejecutar el script manualmente cada vez.

**Dónde va:**
```
/etc/systemd/system/rokoko-usbredirect.service
```

**Cómo instalarlo:**
```bash
sudo cp rokoko-usbredirect.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable rokoko-usbredirect.service
sudo systemctl start rokoko-usbredirect.service
```

Verifica que está corriendo:
```bash
sudo systemctl status rokoko-usbredirect.service
```
Debe aparecer `Active: active (running)`.

---

### Archivo 3: `99-rokoko.rules`

**Qué hace:** Regla udev que evita que Linux tome el control del dispositivo USB del traje al conectarlo, lo que causaría conflictos con la redirección a la VM.

**Dónde va:**
```
/etc/udev/rules.d/99-rokoko.rules
```

**Cómo instalarlo:**
```bash
sudo cp 99-rokoko.rules /etc/udev/rules.d/
sudo udevadm control --reload-rules
```

---

### Archivo 4: `win11.xml`

**Qué hace:** Define la VM de Windows (Tiny11) para KVM. Incluye toda la configuración necesaria: UEFI sin Secure Boot, TPM emulado, y los dos canales TCP para USB redirect (puertos 7700 y 7701). Esta VM solo se usa para pairing WiFi y updates de firmware — no para captura.

**Antes de importar la VM, debes hacer dos cosas:**

#### Paso A — Crear el disco virtual

La VM necesita un disco donde instalará Windows. Créalo con este comando (puedes cambiar la ruta si quieres guardarlo en otro disco):

```bash
sudo qemu-img create -f qcow2 /var/lib/libvirt/images/rokoko_vm.qcow2 40G
```

#### Paso B — Editar la ruta del disco en el XML

Abre `win11.xml` con cualquier editor de texto y busca esta línea (es la línea 52 aproximadamente):

```xml
<source file='/var/lib/libvirt/images/rokoko_vm.qcow2'/>
```

Si creaste el disco en una ruta diferente en el paso anterior, cámbiala aquí para que coincida. Si usaste exactamente el mismo comando del Paso A, no necesitas cambiar nada.

#### Paso C — Verificar que OVMF está disponible

El XML usa los archivos de firmware UEFI de OVMF. Verifica que existen en tu sistema:

```bash
ls /usr/share/OVMF/OVMF_CODE_4M.fd
```

Si el archivo existe, verás su nombre de vuelta. Si da error `No existe el archivo`, instala OVMF:

```bash
sudo apt install ovmf -y
```

#### Paso D — Importar la VM

```bash
sudo virsh define win11.xml
```

Si el comando termina sin error, la VM quedó registrada. Puedes verla en virt-manager.

#### Paso E — Instalar Tiny11 en la VM

1. Abre virt-manager
2. Selecciona la VM `win11` y haz click en **Editar → Detalles**
3. En **SATA CDROM 1** haz click en **Conectar** y selecciona la ISO de Tiny11 que descargaste
4. En **Opciones de arranque** asegúrate que el CDROM esté marcado como primera opción
5. Inicia la VM e instala Windows normalmente

Una vez instalado Windows, instala las **SPICE Guest Tools** dentro de la VM para habilitar copy/paste entre Linux y Windows, y resolución automática de pantalla. Descárgalas desde dentro de la VM:
```
https://www.spice-space.org/download/windows/spice-guest-tools/spice-guest-tools-latest.exe
```

Finalmente instala **Rokoko Studio** dentro de la VM usando el instalador `.exe` oficial.

---

## Configuración de red

Para que el traje sepa a qué IP enviar los datos de movimiento, necesitas una IP fija en tu red WiFi dedicada.

### IP estática en Linux

Primero encuentra el nombre de tu conexión WiFi:
```bash
nmcli connection show
```
Verás una lista — busca la que corresponde a tu red Rokoko. Luego asigna la IP estática (reemplaza `"NombreDeTuRed"` por el nombre exacto que viste):

```bash
nmcli con mod "NombreDeTuRed" \
  ipv4.addresses 192.168.0.100/24 \
  ipv4.gateway 192.168.0.1 \
  ipv4.method manual
nmcli con up "NombreDeTuRed"
```

Verifica que quedó bien:
```bash
ip addr show | grep "inet "
```
Debes ver `192.168.0.100` en el adaptador WiFi.

### Reservar IPs en el router

Esto evita que el router cambie las IPs de tus dispositivos Rokoko entre sesiones.

1. Entra a la interfaz de tu router desde el navegador — normalmente es `http://192.168.0.1`
2. Busca la sección **Red → Servidor DHCP** o similar
3. Cambia el **Pool de direcciones** para que empiece en `192.168.0.150` (así las IPs bajas quedan reservadas para asignación manual)
4. En **Reserva de Direcciones**, agrega una entrada por cada dispositivo

Para ver las MACs de tus dispositivos Rokoko, enciéndelos y conéctalos a la red — aparecerán en la **Lista de Clientes DHCP** del router con su MAC e IP asignada.

Ejemplo de reservas:

| Dispositivo | IP Recomendada |
|---|---|
| Tu Linux | 192.168.0.100 |
| Smartsuit Pro II | 192.168.0.150 |
| Guante derecho | 192.168.0.151 |
| Guante izquierdo | 192.168.0.152 |

Guarda los cambios en el router.

---

## Pairing WiFi del traje

Este paso le dice al traje a qué red conectarse y a qué IP de Linux enviar los datos.

1. Conecta el traje por USB — el daemon lo detecta automáticamente en segundos
2. Abre Rokoko Studio en la VM de Windows
3. El traje aparecerá como conectado
4. Ve a la configuración del dispositivo y busca **WiFi Setup**
5. Selecciona tu red WiFi dedicada del dropdown — el traje escanea las redes con su propio chipset
6. Ingresa la contraseña de la red
7. En **Receiver IP** escribe la IP de tu Linux: `192.168.0.100`
8. En **Receiver port** deja `14041`
9. Click en **Apply Settings**

Para verificar que el pairing fue exitoso, desconecta el USB, enciende el traje solo con batería y corre esto en Linux:

```bash
sudo tcpdump -i wlp3s0 udp port 14041
```

Reemplaza `wlp3s0` por el nombre de tu adaptador WiFi (puedes verlo con `ip link show`). Si ves paquetes llegando desde `192.168.0.150`, el pairing funcionó.

---

## Rokoko Studio en Linux (Bottles)

Para usar Rokoko Studio directamente en Linux sin necesitar la VM:

1. Abre Bottles y crea una botella nueva:
   - Tipo: **Aplicación**
   - Ejecutor: **soda** (la versión más reciente disponible)
2. Dentro de la botella, instala el `.exe` de Rokoko Studio
3. Abre Rokoko Studio — detectará el traje por WiFi automáticamente porque los paquetes UDP ya están llegando a tu Linux en el puerto 14041

---

## Verificación del sistema completo

```bash
# VM registrada y disponible
sudo virsh list --all

# Daemon de USB redirect activo
sudo systemctl status rokoko-usbredirect.service

# Datos del traje llegando a Linux (enciende el traje con batería)
sudo tcpdump -i wlp3s0 udp port 14041

# Ver logs del daemon en tiempo real al conectar/desconectar
sudo journalctl -u rokoko-usbredirect.service -f
```

---

## Troubleshooting

**La VM no arranca:**
```bash
sudo systemctl start libvirtd
sudo virsh start win11
```

**El traje no aparece en Rokoko Studio (VM):**
```bash
# Ver qué está pasando con el daemon
sudo journalctl -u rokoko-usbredirect.service -n 30
# Verificar que el daemon está activo
sudo systemctl status rokoko-usbredirect.service
```

**No llegan paquetes UDP al hacer tcpdump:**
```bash
# Permitir el puerto en el firewall
sudo ufw allow 14041/udp
# Verificar que estás escuchando en el adaptador correcto
ip link show
```

**El update de firmware falla a mitad:**
El update hace varios ciclos de disconnect/reconnect automáticamente. El daemon los maneja sin intervención. Si falla, simplemente vuelve a intentarlo desde Rokoko Studio con el traje conectado por USB.

---

## Créditos

Desarrollado por **Manu** — VFX Supervisor, fundador de **Black Frame Digital SAS**, Bogotá, Colombia.

- 🌐 [blackframed.com](https://blackframed.com)
- 💼 [linkedin.com/in/manuvfx](https://linkedin.com/in/manuvfx)
- ☕ [Apóyame con un café](https://Ko-fi.com/barrmanuel)

---

*Solución no oficial. Rokoko no ofrece soporte para Linux. Probado en Linux Mint 22 (Ubuntu 24.04 Noble).*
