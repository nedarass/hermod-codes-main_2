#!/usr/bin/env python3
"""
Final STM32 + Yaskawa Inverter Client
- STM32'den USB üzerinden sensör verisi okur (JSON formatında)
- Yaskawa inverter'ı USB/Serial üzerinden kontrol eder
- Polaris server'a TCP ile veri gönderir
- Server tüm bağlı clientlara (GUI dahil) broadcast eder
"""

import serial
import socket
import json
import time
import sys

# ============ KONFİGÜRASYON ============
SERVER_IP = '192.168.2.2'      # Bilgisayarınızın IP'si
SERVER_PORT = 5555             # Polaris server portu

STM32_PORT = '/dev/ttyACM0'    # STM32 USB portu
STM32_BAUDRATE = 115200        # STM32 baud rate

INVERTER_PORT = '/dev/ttyUSB0' # Yaskawa inverter portu
INVERTER_BAUDRATE = 9600       # Yaskawa baud rate

# Güvenlik eşikleri
BRAKE_THRESHOLD_HIGH = 80      # %80 üzeri fren → acil fren
BRAKE_THRESHOLD_MED = 50       # %50 üzeri fren → durdur
SPEED_LIMIT = 250              # km/h üzeri → durdur
TEMP_LIMIT = 40                # °C üzeri → durdur
BATTERY_LOW = 42.0             # V altı → uyarı

class FinalClient:
    def __init__(self):
        self.stm32 = None
        self.inverter = None
        self.sock = None
        self.running = False
        
    def connect_stm32(self):
        """STM32'ye USB üzerinden bağlan"""
        print(f"STM32'ye bağlanılıyor: {STM32_PORT}...")
        try:
            self.stm32 = serial.Serial(
                port=STM32_PORT,
                baudrate=STM32_BAUDRATE,
                timeout=1,
                bytesize=serial.EIGHTBITS,
                parity=serial.PARITY_NONE,
                stopbits=serial.STOPBITS_ONE
            )
            print(f"✓ STM32 bağlandı: {STM32_PORT} @ {STM32_BAUDRATE} baud")
            time.sleep(2)  # STM32 reset için bekle
            
            # İlk dummy okuma (buffer temizliği)
            if self.stm32.in_waiting > 0:
                self.stm32.read(self.stm32.in_waiting)
            
            return True
        except serial.SerialException as e:
            print(f"✗ STM32 bağlantı hatası: {e}")
            print("  Kontrol: USB kablo takılı mı? STM32 çalışıyor mu?")
            print("  Port doğru mu? (ls /dev/tty* ile kontrol edin)")
            return False
    
    def connect_inverter(self):
        """Yaskawa inverter'a bağlan"""
        print(f"Inverter'a bağlanılıyor: {INVERTER_PORT}...")
        try:
            self.inverter = serial.Serial(
                port=INVERTER_PORT,
                baudrate=INVERTER_BAUDRATE,
                timeout=1,
                bytesize=serial.EIGHTBITS,
                parity=serial.PARITY_EVEN,
                stopbits=serial.STOPBITS_ONE
            )
            print(f"✓ Inverter bağlandı: {INVERTER_PORT} @ {INVERTER_BAUDRATE} baud")
            time.sleep(0.5)
            return True
        except serial.SerialException as e:
            print(f"✗ Inverter bağlantı hatası: {e}")
            print("  Kontrol: Yaskawa inverter takılı mı?")
            return False
    
    def connect_server(self):
        """Polaris server'a TCP ile bağlan"""
        print(f"Server'a bağlanılıyor: {SERVER_IP}:{SERVER_PORT}...")
        try:
            self.sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            self.sock.connect((SERVER_IP, SERVER_PORT))
            print(f"✓ Server'a bağlandı: {SERVER_IP}:{SERVER_PORT}")
            return True
        except Exception as e:
            print(f"✗ Server bağlantı hatası: {e}")
            print(f"  Kontrol: Server çalışıyor mu? IP doğru mu? ({SERVER_IP})")
            return False
    
    def read_stm32_data(self):
        """
        STM32'den sensör verisi oku (JSON formatında)
        Beklenen format: {"speed":120.5,"temperature":28.3,"brake_pressure":45,"battery_voltage":48.2}
        """
        try:
            if self.stm32 and self.stm32.in_waiting > 0:
                line = self.stm32.readline().decode('utf-8', errors='ignore').strip()
                
                if line:
                    try:
                        data = json.loads(line)
                        return data
                    except json.JSONDecodeError:
                        print(f"⚠ JSON parse hatası: {line[:50]}...")
                        return None
        except Exception as e:
            print(f"✗ STM32 okuma hatası: {e}")
        
        return None
    
    def send_inverter_command(self, command):
        """
        Yaskawa inverter'a komut gönder
        Protokol: Yaskawa Modbus/RS485 veya özel protokol
        """
        try:
            if not self.inverter:
                return False
            
            # Yaskawa protokolüne göre komut paketi oluştur
            # Bu örnekte basit ASCII komutlar kullanılıyor
            # Gerçek Yaskawa protokolü için datasheet'e bakın
            
            commands = {
                "START": b'\x02\x30\x30\x30\x31\x03',  # Örnek: Motor başlat
                "STOP": b'\x02\x30\x30\x30\x32\x03',   # Motor durdur
                "BRAKE": b'\x02\x30\x30\x30\x33\x03',  # Acil fren
                "RESET": b'\x02\x30\x30\x30\x34\x03'   # Reset
            }
            
            if command in commands:
                self.inverter.write(commands[command])
                self.inverter.flush()
                print(f"→ Inverter komutu gönderildi: {command}")
                
                # Yanıt bekle (opsiyonel)
                time.sleep(0.1)
                if self.inverter.in_waiting > 0:
                    response = self.inverter.read(self.inverter.in_waiting)
                    print(f"← Inverter yanıtı: {response.hex()}")
                
                return True
            else:
                print(f"⚠ Bilinmeyen komut: {command}")
                return False
                
        except Exception as e:
            print(f"✗ Inverter komut hatası: {e}")
            return False
    
    def process_sensor_data(self, data):
        """
        Sensör verisini değerlendir ve gerekirse inverter'ı kontrol et
        Güvenlik kontrolü ve otomatik acil durdurma
        """
        
        # Fren basıncı kontrolü
        if 'brake_pressure' in data:
            brake = data['brake_pressure']
            
            if brake > BRAKE_THRESHOLD_HIGH:
                print(f"🚨 ACİL FREN! Fren basıncı çok yüksek: {brake}%")
                self.send_inverter_command("BRAKE")
                
            elif brake > BRAKE_THRESHOLD_MED:
                print(f"⚠ DURDUR! Orta seviye fren: {brake}%")
                self.send_inverter_command("STOP")
        
        # Hız kontrolü
        if 'speed' in data:
            speed = data['speed']
            
            if speed > SPEED_LIMIT:
                print(f"🚨 HIZ LİMİTİ AŞILDI! Hız: {speed} km/h (Limit: {SPEED_LIMIT})")
                self.send_inverter_command("STOP")
        
        # Sıcaklık kontrolü
        if 'temperature' in data:
            temp = data['temperature']
            
            if temp > TEMP_LIMIT:
                print(f"🚨 AŞIRI ISINMA! Sıcaklık: {temp}°C (Limit: {TEMP_LIMIT})")
                self.send_inverter_command("STOP")
        
        # Batarya voltaj kontrolü
        if 'battery_voltage' in data:
            voltage = data['battery_voltage']
            
            if voltage < BATTERY_LOW:
                print(f"⚠ DÜŞÜK BATARYA! Voltaj: {voltage}V")
    
    def send_to_server(self, data):
        """Veriyi Polaris server'a gönder (broadcast için)"""
        try:
            if self.sock:
                # JSON formatında gönder, satır sonu ekle
                message = json.dumps(data) + "\n"
                self.sock.sendall(message.encode('utf-8'))
                return True
        except Exception as e:
            print(f"✗ Server gönderme hatası: {e}")
            return False
    
    def run(self):
        """Ana döngü - sistem çalıştırma"""
        
        print("\n" + "="*50)
        print("   FINAL STM32 + YASKAWA INVERTER CLIENT")
        print("="*50 + "\n")
        
        # Bağlantıları kur
        if not self.connect_stm32():
            print("\n✗ STM32 bağlantısı başarısız. Çıkılıyor...")
            return
        
        if not self.connect_inverter():
            print("\n✗ Inverter bağlantısı başarısız. Çıkılıyor...")
            return
        
        if not self.connect_server():
            print("\n✗ Server bağlantısı başarısız. Çıkılıyor...")
            return
        
        self.running = True
        print("\n" + "="*50)
        print("   ✓ TÜM SİSTEMLER HAZIR!")
        print("   Veri akışı başlıyor...")
        print("="*50 + "\n")
        
        packet_count = 0
        last_status_time = time.time()
        
        try:
            while self.running:
                # STM32'den sensör verisi oku
                sensor_data = self.read_stm32_data()
                
                if sensor_data:
                    packet_count += 1
                    
                    # Veriyi ekrana yazdır
                    print(f"[{packet_count}] 📊 Sensör: ", end="")
                    print(f"Hız={sensor_data.get('speed', 0):.1f} ", end="")
                    print(f"Sıc={sensor_data.get('temperature', 0):.1f}°C ", end="")
                    print(f"Fren={sensor_data.get('brake_pressure', 0)}% ", end="")
                    print(f"Bat={sensor_data.get('battery_voltage', 0):.1f}V")
                    
                    # Güvenlik kontrolü yap
                    self.process_sensor_data(sensor_data)
                    
                    # Server'a gönder (GUI'ye broadcast edilecek)
                    if not self.send_to_server(sensor_data):
                        print("⚠ Server bağlantısı koptu, yeniden bağlanılıyor...")
                        if not self.connect_server():
                            print("✗ Server'a tekrar bağlanılamadı!")
                            break
                
                # Periyodik durum raporu (10 saniyede bir)
                if time.time() - last_status_time > 10:
                    print(f"\n📊 Durum: {packet_count} paket gönderildi")
                    last_status_time = time.time()
                
                time.sleep(0.1)  # 10 Hz okuma hızı
                
        except KeyboardInterrupt:
            print("\n\n⚠ Kullanıcı tarafından durduruldu (Ctrl+C)")
        except Exception as e:
            print(f"\n✗ Beklenmeyen hata: {e}")
        finally:
            self.cleanup()
    
    def cleanup(self):
        """Bağlantıları temizle ve kapat"""
        print("\nBağlantılar kapatılıyor...")
        
        if self.stm32:
            self.stm32.close()
            print("✓ STM32 bağlantısı kapatıldı")
        
        if self.inverter:
            # Güvenlik için son komut: STOP
            try:
                self.send_inverter_command("STOP")
            except:
                pass
            self.inverter.close()
            print("✓ Inverter bağlantısı kapatıldı")
        
        if self.sock:
            self.sock.close()
            print("✓ Server bağlantısı kapatıldı")
        
        print("\n✓ Sistem güvenli şekilde kapatıldı\n")


def main():
    """Program başlangıcı"""
    
    # Parametreleri göster
    print("\nKonfigürasyon:")
    print(f"  Server     : {SERVER_IP}:{SERVER_PORT}")
    print(f"  STM32      : {STM32_PORT} @ {STM32_BAUDRATE} baud")
    print(f"  Inverter   : {INVERTER_PORT} @ {INVERTER_BAUDRATE} baud")
    print(f"  Güvenlik   : Fren>{BRAKE_THRESHOLD_HIGH}%, Hız>{SPEED_LIMIT}km/h, Sıc>{TEMP_LIMIT}°C")
    print()
    
    client = FinalClient()
    client.run()


if __name__ == "__main__":
    main()
