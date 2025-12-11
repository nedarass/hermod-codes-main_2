# Hermod Hyperloop Kontrol Sistemi - Tam Dokümantasyon

## 📋 İçindekiler
1. [Sistem Mimarisi](#sistem-mimarisi)
2. [Kurulum](#kurulum)
3. [Kullanım](#kullanım)
4. [Teknik Detaylar](#teknik-detaylar)

---

## Sistem Mimarisi

```
┌─────────────────────┐         TCP/IP          ┌──────────────────────┐
│  Raspberry Pi 5     │◄───────────────────────►│ Kontrol Bilgisayar   │
│                     │                          │                      │
│  • STM32 (USB)      │     JSON Veri Akışı     │  • Polaris Server    │
│  • Yaskawa (USB)    │                          │  • Bifrost GUI       │
│  • final_client.py  │                          │  • Port 5555         │
└─────────────────────┘                          └──────────────────────┘
```

### Veri Akışı
```
STM32 Sensörler → Raspberry Pi → Polaris Server → Bifrost GUI
                        ↓
                  Yaskawa Inverter
                  (Acil Durum Kontrol)
```

---

## 📁 Proje Yapısı

```
hermod-codes-main/
├── DOCUMENTATION.md              # Bu dosya - Tüm dokümantasyon
├── raspberry-pi/
│   ├── final_client.py          # Ana client (STM32 + Inverter)
│   └── config.json              # Yapılandırma
├── polaris/
│   ├── multi_client_server.cpp  # TCP Server (C++)
│   ├── CMakeLists.txt
│   └── build/
└── bifrost-simple/
    ├── main.cpp                 # Qt GUI uygulaması
    ├── tcp_client.h/cpp         # TCP client
    ├── MainWindow.qml           # Arayüz
    ├── CMakeLists.txt
    └── build/
```

---

## 🚀 Kurulum

### 1. Raspberry Pi Kurulumu

#### Gerekli Kütüphaneler:
```bash
# Python Serial kütüphanesi
sudo apt-get update
sudo apt-get install python3-serial
# veya
pip3 install pyserial
```

#### Yapılandırma:
`raspberry-pi/config.json` dosyasını düzenleyin:
```json
{
    "server_ip": "192.168.2.2",
    "server_port": 5555,
    "stm32_port": "/dev/ttyACM0",
    "stm32_baudrate": 115200,
    "inverter_port": "/dev/ttyUSB0",
    "inverter_baudrate": 9600
}
```

#### USB Portlarını Kontrol:
```bash
# Bağlı USB cihazları göster
ls /dev/tty*

# STM32 genellikle: /dev/ttyACM0
# Yaskawa genellikle: /dev/ttyUSB0
```

---

### 2. Polaris Server Kurulumu (Kontrol PC)

#### Linux/WSL:
```bash
cd polaris
mkdir -p build
cd build
cmake ..
make

# Çalıştır
./polaris
```

#### WSL Port Forwarding (Windows):
Server WSL'de çalışıyorsa, PowerShell'i **yönetici olarak** açın:

```powershell
# WSL IP'sini al
$wslIP = (wsl hostname -I).Trim()

# Port forwarding ekle
netsh interface portproxy add v4tov4 listenport=5555 listenaddress=0.0.0.0 connectport=5555 connectaddress=$wslIP

# Firewall kuralı
netsh advfirewall firewall add rule name="Polaris 5555" dir=in action=allow protocol=TCP localport=5555

# Kontrol
netsh interface portproxy show all
```

**Port forwarding'i kaldırmak için:**
```powershell
netsh interface portproxy delete v4tov4 listenport=5555 listenaddress=0.0.0.0
netsh advfirewall firewall delete rule name="Polaris 5555"
```

---

### 3. Bifrost GUI Kurulumu (Kontrol PC)

#### Qt6 Kurulumu (Windows):
1. [Qt Online Installer](https://www.qt.io/download) indirin
2. Hesap oluşturun (ücretsiz)
3. Custom Installation seçin:
   - ✅ Qt 6.x (en son LTS)
   - ✅ MinGW Compiler
   - ✅ Qt Creator (opsiyonel)
   - ❌ Diğer platformlar (Android, iOS)

#### Derleme:
```bash
cd bifrost-simple
mkdir -p build
cd build

# Linux
cmake ..
make
./bifrost

# Windows (MinGW)
cmake .. -G "MinGW Makefiles"
mingw32-make
.\bifrost.exe
```

---

## 🎮 Kullanım

### Tam Sistem Başlatma

#### Adım 1: Kontrol PC - Server Başlat
```bash
# WSL veya Linux Terminal
cd polaris/build
./polaris
```

Çıktı:
```
=== Hermod Polaris Multi-Client Server ===
✓ Multi-Client Server başlatıldı - Port: 5555
✓ Server hazır! Clientlar bekleniyor...
```

#### Adım 2: Kontrol PC - GUI Başlat
```bash
cd bifrost-simple/build
./bifrost  # veya bifrost.exe
```

GUI'de:
1. Server IP: `localhost` veya `127.0.0.1`
2. Port: `5555`
3. **Connect** butonuna tıklayın

#### Adım 3: Raspberry Pi - Client Başlat
```bash
cd raspberry-pi
python3 final_client.py
```

Çıktı:
```
==================================================
   FINAL STM32 + YASKAWA INVERTER CLIENT
==================================================

STM32'ye bağlanılıyor: /dev/ttyACM0...
✓ STM32 bağlandı: /dev/ttyACM0 @ 115200 baud
Inverter'a bağlanılıyor: /dev/ttyUSB0...
✓ Inverter bağlandı: /dev/ttyUSB0 @ 9600 baud
Server'a bağlanılıyor: 192.168.2.2:5555...
✓ Server'a bağlandı: 192.168.2.2:5555

==================================================
   ✓ TÜM SİSTEMLER HAZIR!
   Veri akışı başlıyor...
==================================================

[1] 📊 Sensör: Hız=120.5 Sıc=28.3°C Fren=45% Bat=48.2V
[2] 📊 Sensör: Hız=125.8 Sıc=28.5°C Fren=50% Bat=48.0V
```

---

## 🔧 Teknik Detaylar

### Veri Formatı (JSON)

#### STM32 → Raspberry Pi (Serial/USB):
```json
{
    "speed": 120.5,
    "temperature": 28.3,
    "brake_pressure": 45,
    "battery_voltage": 48.2
}
```

#### Raspberry Pi → Server (TCP):
Aynı JSON formatı, satır sonu ile (`\n`)

#### Server → GUI (TCP):
Broadcast - Tüm bağlı clientlara aynı veri

---

### Güvenlik Eşikleri

`final_client.py` içinde tanımlı:

```python
BRAKE_THRESHOLD_HIGH = 80      # %80 üzeri → ACİL FREN
BRAKE_THRESHOLD_MED = 50       # %50 üzeri → DURDUR
SPEED_LIMIT = 250              # km/h üzeri → DURDUR
TEMP_LIMIT = 40                # °C üzeri → DURDUR
BATTERY_LOW = 42.0             # V altı → UYARI
```

**Otomatik Güvenlik Tepkileri:**
- Fren > 80% → Inverter'a `BRAKE` komutu
- Fren > 50% → Inverter'a `STOP` komutu
- Hız > 250 km/h → Inverter'a `STOP` komutu
- Sıcaklık > 40°C → Inverter'a `STOP` komutu

---

### Yaskawa Inverter Komutları

`final_client.py` içinde tanımlı protokol:

```python
commands = {
    "START": b'\x02\x30\x30\x30\x31\x03',  # Motor başlat
    "STOP": b'\x02\x30\x30\x30\x32\x03',   # Motor durdur
    "BRAKE": b'\x02\x30\x30\x30\x33\x03',  # Acil fren
    "RESET": b'\x02\x30\x30\x30\x34\x03'   # Reset
}
```

**Not:** Gerçek Yaskawa inverter protokolü için datasheet'e bakın. Bu örnekler basit ASCII komutlarıdır.

---

### STM32 Kod Örneği

STM32'de JSON formatında veri gönderme:

```c
#include <stdio.h>
#include <string.h>

void send_sensor_data() {
    char buffer[256];
    
    // Sensör verilerini oku
    float speed = read_speed_sensor();
    float temperature = read_temperature_sensor();
    int brake_pressure = read_brake_sensor();
    float battery_voltage = read_battery_voltage();
    
    // JSON formatında hazırla
    sprintf(buffer, 
        "{\"speed\":%.1f,\"temperature\":%.1f,\"brake_pressure\":%d,\"battery_voltage\":%.1f}\n",
        speed, temperature, brake_pressure, battery_voltage);
    
    // USB CDC üzerinden gönder
    CDC_Transmit_FS((uint8_t*)buffer, strlen(buffer));
}

int main() {
    // Başlatma...
    
    while(1) {
        send_sensor_data();
        HAL_Delay(100);  // 10 Hz (100ms)
    }
}
```

---

### Network Yapılandırması

#### IP Adresleri:
- **Kontrol PC**: `192.168.2.2` (modem/router'dan aldığı IP)
- **Raspberry Pi**: `192.168.2.x` (aynı ağda)
- **Port**: `5555` (TCP)

#### Bağlantıyı Test Etme:

**Raspberry Pi'den:**
```bash
# Ping test
ping 192.168.2.2

# Port test (nc komutu ile)
nc -zv 192.168.2.2 5555

# Telnet ile test
telnet 192.168.2.2 5555
```

**Windows'tan:**
```powershell
# Ping test
ping 192.168.2.2

# Port test
Test-NetConnection -ComputerName 192.168.2.2 -Port 5555
```

---

## 🐛 Sorun Giderme

### Problem: "Bind hatası!" (Server başlamıyor)
**Sebep:** Port 5555 zaten kullanımda

**Çözüm:**
```bash
# Linux/WSL
sudo lsof -i :5555
# PID'yi bulup kill et
kill -9 <PID>

# Veya farklı port kullan
# multi_client_server.cpp içinde port'u değiştir
```

---

### Problem: STM32 bağlanamıyor
**Sebep:** USB port adresi yanlış veya izin sorunu

**Çözüm:**
```bash
# Portları kontrol et
ls -la /dev/tty*

# İzin ver
sudo chmod 666 /dev/ttyACM0

# Kullanıcıyı dialout grubuna ekle
sudo usermod -a -G dialout $USER
# Çıkış yap ve tekrar giriş yap
```

---

### Problem: Server'a bağlanamıyor (Raspberry Pi)
**Sebep:** Firewall veya yanlış IP

**Çözüm:**
1. IP adresini kontrol edin (`ipconfig` / `ifconfig`)
2. Firewall kuralı ekleyin (yukarıdaki WSL bölümüne bakın)
3. Aynı ağda olduğunuzdan emin olun

---

### Problem: GUI verileri göstermiyor
**Sebep:** Server'a bağlanmamış veya veri gelmiyor

**Çözüm:**
1. Server çalışıyor mu kontrol edin
2. GUI'de "Bağlan" butonuna tıkladınız mı?
3. Server konsolunda "Client bağlandı" mesajı var mı?

---

## 📊 Sistem Performansı

- **Veri Frekansı**: 10 Hz (100ms aralıklar)
- **Latency**: < 50ms (yerel ağda)
- **Bandwidth**: ~200 bytes/paket × 10 Hz = ~2 KB/s

---

## 🔐 Güvenlik Notları

1. **Acil Durdurma**: Sistem kapanırken inverter'a `STOP` komutu gönderilir
2. **Otomatik Güvenlik**: Eşik değerler aşıldığında otomatik tepki
3. **Bağlantı Kopması**: Raspberry Pi bağlantı koparsa tekrar bağlanmaya çalışır

---

## 📝 Geliştirme Notları

### Kodu Değiştirme

#### Server'da port değiştirme:
`polaris/multi_client_server.cpp` içinde:
```cpp
MultiClientServer server(5556);  // Port 5556'ya değiştir
```

#### Güvenlik eşiklerini değiştirme:
`raspberry-pi/final_client.py` içinde:
```python
SPEED_LIMIT = 300  # Artır veya azalt
TEMP_LIMIT = 45    # Artır veya azalt
```

#### Yeni sensör ekleme:
1. STM32'de JSON'a yeni field ekle
2. `final_client.py` içinde `process_sensor_data()` fonksiyonunu güncelle
3. Bifrost GUI'de yeni gösterge ekle

---

## 📞 Yardım

Sorun yaşarsanız:
1. Server konsolu loglarını kontrol edin
2. Raspberry Pi konsolu loglarını kontrol edin
3. Network bağlantısını test edin (ping, telnet)
4. USB cihazlarını kontrol edin (`ls /dev/tty*`)

---

**Son Güncelleme:** 8 Aralık 2025
**Versiyon:** 2.0 (Final)
