#!/usr/bin/env python3
"""
Final STM32 + Yaskawa Inverter Client (Raspberry Pi)
- STM32'den (Sensörler: Enkoder, MPU9250, Omron) veriyi JSON alır.
- Interface'den (Bifrost) gelen komutları (Slider, Buton) dinler.
- Yaskawa Inverter'ı sürer.
"""

import serial
import socket
import json
import time
import sys
import threading

# ============ KONFİGÜRASYON ============
SERVER_IP = '192.168.2.3'      # Polaris Server IP'si
SERVER_PORT = 5555             # Polaris Server Portu

STM32_PORT = '/dev/ttyACM0'    # STM32 USB portu
STM32_BAUDRATE = 115200        # STM32 baud rate

INVERTER_PORT = '/dev/ttyUSB0' # RS485 Dönüştürücü portu
INVERTER_BAUDRATE = 9600       # Yaskawa baud rate (H5-02)
INVERTER_SLAVE_ID = 1          # Yaskawa Slave Address (H5-01)

# --- FİZİKSEL DÖNÜŞÜMLER ---
# Varsayım: 60 Hz frekans = 500 km/h tekerlek hızı
MAX_SYSTEM_SPEED_KMH = 500.0   
MAX_INVERTER_FREQ_HZ = 60.0

# Güvenlik Eşikleri
SAFETY_TEMP_LIMIT = 60.0       # Araç Motoru Max Sıcaklık
SAFETY_BATTERY_LIMIT = 50.0    # [YENİ] Batarya Max Sıcaklık
SAFETY_BRAKE_PRESSURE = 85     # Fren Basıncı Limiti
SPEED_LIMIT_THRESHOLD = 250    # Yazılımsal acil durdurma limiti

class FinalClient:
    def __init__(self):
        self.stm32 = None
        self.inverter = None
        self.sock = None
        self.running = False
        
        # Başlangıçta hız limiti en yüksekte başlar.
        self.current_speed_limit_kmh = MAX_SYSTEM_SPEED_KMH 
        
    def connect_stm32(self):
        print(f"STM32'ye bağlanılıyor: {STM32_PORT}...")
        try:
            self.stm32 = serial.Serial(port=STM32_PORT, baudrate=STM32_BAUDRATE, timeout=1)
            print(f"✓ STM32 bağlandı")
            time.sleep(2)
            if self.stm32.in_waiting > 0: self.stm32.read(self.stm32.in_waiting)
            return True
        except Exception as e:
            print(f"✗ STM32 hatası: {e}")
            return False
    
    def connect_inverter(self):
        print(f"Inverter'a bağlanılıyor: {INVERTER_PORT}...")
        try:
            self.inverter = serial.Serial(
                port=INVERTER_PORT,
                baudrate=INVERTER_BAUDRATE,
                timeout=0.1,
                parity=serial.PARITY_EVEN,
                stopbits=serial.STOPBITS_ONE
            )
            print(f"✓ Inverter bağlandı")
            return True
        except Exception as e:
            print(f"✗ Inverter hatası: {e}")
            return False
    
    def connect_server(self):
        print(f"Server'a bağlanılıyor: {SERVER_IP}:{SERVER_PORT}...")
        try:
            self.sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            self.sock.connect((SERVER_IP, SERVER_PORT))
            print(f"✓ Server'a bağlandı")
            return True
        except Exception as e:
            print(f"✗ Server hatası: {e}")
            return False
    
    def read_stm32_data(self):
        try:
            if self.stm32 and self.stm32.in_waiting > 0:
                line = self.stm32.readline().decode('utf-8', errors='ignore').strip()
                if line:
                    return json.loads(line)
        except: pass
        return None
    
    def calculate_crc(self, data):
        """Modbus RTU CRC-16 Hesaplama"""
        crc = 0xFFFF
        for pos in data:
            crc ^= pos 
            for i in range(8):
                if (crc & 1) != 0:
                    crc >>= 1
                    crc ^= 0xA001
                else:
                    crc >>= 1
        return bytes([crc & 0xFF, (crc >> 8) & 0xFF])

    def send_inverter_command(self, command, value=0):
        try:
            if not self.inverter: return False
            
            REG_OPERATION = 0x0001
            REG_FREQUENCY = 0x0002
            REG_DECEL_TIME = 0x0202
            REG_TORQUE = 0x000C # Bazı modellerde tork/akım limiti
            
            packet = None

            # 1. MOTOR GÜCÜ (START / STOP)
            if command == "motor_power" or command == "START" or command == "STOP":
                is_start = False
                if command == "START": is_start = True
                elif command == "STOP": is_start = False
                elif command == "motor_power": is_start = (int(value) == 1)

                data_byte = 0x01 if is_start else 0x00
                base = bytes([INVERTER_SLAVE_ID, 0x06, (REG_OPERATION >> 8), (REG_OPERATION & 0xFF), 0x00, data_byte])
                packet = base + self.calculate_crc(base)
                print(f">>> MOTOR DURUMU: {'AÇIK' if is_start else 'KAPALI'}")

            # 2. SPEED LIMIT (HIZ LİMİTİ GÜNCELLEME)
            elif command == "speed_limit":
                self.current_speed_limit_kmh = float(value)
                print(f">>> SİSTEM HIZ LİMİTİ GÜNCELLENDİ: {self.current_speed_limit_kmh} km/h")
                return True 

            # 3. FREKANS AYARI (GAZ PEDALI)
            elif command == "set_frequency":
                requested_hz = float(value)
                
                # --- HIZ LİMİTİ HESABI ---
                limit_hz = (self.current_speed_limit_kmh / MAX_SYSTEM_SPEED_KMH) * MAX_INVERTER_FREQ_HZ
                
                # İstenen frekans ile limiti kıyaslıyoruz
                final_hz = min(requested_hz, limit_hz)
                
                if final_hz < requested_hz:
                    print(f"⚠ UYARI: Hız Limiti Devrede! ({requested_hz} Hz -> {final_hz:.1f} Hz indirildi)")
                
                # Yaskawa'ya gönder (0.01 Hz hassasiyet)
                yaskawa_val = int(final_hz * 100)
                
                base = bytes([INVERTER_SLAVE_ID, 0x06, (REG_FREQUENCY >> 8), (REG_FREQUENCY & 0xFF), 
                              (yaskawa_val >> 8) & 0xFF, yaskawa_val & 0xFF])
                packet = base + self.calculate_crc(base)
                print(f">>> Frekans Gönderildi: {final_hz:.2f} Hz")

            # 4. AŞAMALI FREN (Brake Slider -> Yavaşlama Süresi)
            elif command == "brake" or command == "brake_level":
                brake_val = float(value)
                
                if brake_val <= 0:
                    decel_time_sec = 10.0 # Normal duruş
                else:
                    # Fren arttıkça süre azalır (%100 -> 0.1sn)
                    decel_time_sec = 10.0 - (brake_val / 100.0 * 9.9)
                    if decel_time_sec < 0.1: decel_time_sec = 0.1

                reg_val = int(decel_time_sec * 10) 
                
                # Süreyi Ayarla
                base = bytes([INVERTER_SLAVE_ID, 0x06, (REG_DECEL_TIME >> 8), (REG_DECEL_TIME & 0xFF), 
                              (reg_val >> 8) & 0xFF, reg_val & 0xFF])
                packet_time = base + self.calculate_crc(base)
                self.inverter.write(packet_time)
                time.sleep(0.02)
                
                # Motoru Durdur (STOP)
                stop_base = bytes([INVERTER_SLAVE_ID, 0x06, (REG_OPERATION >> 8), (REG_OPERATION & 0xFF), 0x00, 0x00])
                packet = stop_base + self.calculate_crc(stop_base)
                print(f">>> FREN UYGULANIYOR: %{brake_val} (Süre: {decel_time_sec:.1f}s)")

            # GÖNDERİM
            if packet:
                self.inverter.write(packet)
                return True

        except Exception as e:
            print(f"✗ Inverter komut hatası: {e}")
            return False

    def process_sensor_data(self, data):
        """Sensör verilerini güvenlik limitlerine göre kontrol et"""
        
        # 1. Hız Kontrolü
        if 'speed' in data:
            if data['speed'] > SPEED_LIMIT_THRESHOLD:
                print(f"🚨 KRİTİK HIZ AŞIMI! ACİL DURDURMA.")
                self.send_inverter_command("STOP")

        # 2. Araç Motor Sıcaklığı Kontrolü
        if 'temperature' in data:
            if data['temperature'] > SAFETY_TEMP_LIMIT:
                print(f"🚨 MOTOR AŞIRI ISINMA ({data['temperature']}°C)! ACİL DURDURMA.")
                self.send_inverter_command("STOP")

        # 3. [YENİ] Batarya Sıcaklığı Kontrolü
        if 'battery_temp' in data:
            bat_temp = data['battery_temp']
            if bat_temp > SAFETY_BATTERY_LIMIT:
                print(f"🚨 BATARYA KRİTİK SICAKLIK ({bat_temp}°C)! SİSTEM KAPATILIYOR.")
                self.send_inverter_command("STOP")
                # İstersen burada freni de çekebilirsin
        
        # 4. Otomatik Fren (Basınca Göre)
        if 'brake_pressure' in data:
            if data['brake_pressure'] > SAFETY_BRAKE_PRESSURE:
                self.send_inverter_command("brake", 100)

    def send_to_server(self, data):
        try:
            if self.sock:
                message = json.dumps(data) + "\n"
                self.sock.sendall(message.encode('utf-8'))
                return True
        except: return False

    def listen_to_pc(self):
        print("🎧 PC Komut Dinleme Hattı Aktif...")
        buffer = ""
        while self.running:
            try:
                if not self.sock:
                    time.sleep(1); continue
                
                data = self.sock.recv(1024).decode('utf-8', errors='ignore')
                if not data: break
                
                buffer += data
                while '\n' in buffer:
                    line, buffer = buffer.split('\n', 1)
                    if not line.strip(): continue
                    try:
                        cmd_json = json.loads(line)
                        self.send_inverter_command(cmd_json.get("command"), cmd_json.get("value", 0))
                    except: pass
            except: break

    def cleanup(self):
        print("\n--- SİSTEM KAPATILIYOR ---")
        self.running = False
        if self.inverter:
            try:
                self.send_inverter_command("STOP")
                time.sleep(0.1)
                self.inverter.close()
                print("✓ Inverter kapatıldı")
            except: pass
        if self.stm32: 
            self.stm32.close()
            print("✓ STM32 kapatıldı")
        if self.sock: 
            self.sock.close()
            print("✓ Server bağlantısı kesildi")

    def run(self):
        print("\n=== HERMOD HYPERLOOP KONTROLCÜSÜ ===")
        
        if not self.connect_stm32(): return
        if not self.connect_inverter(): return
        if not self.connect_server(): return

        self.running = True
        
        t = threading.Thread(target=self.listen_to_pc)
        t.daemon = True
        t.start()

        print("🚀 Sistem Hazır! Veri Akışı Başlıyor...")

        try:
            while self.running:
                sensor_data = self.read_stm32_data()
                
                if sensor_data:
                    # Güvenlik Kontrolleri
                    self.process_sensor_data(sensor_data)
                    
                    # Interface'e Gönder
                    self.send_to_server(sensor_data)
                    
                    # Ekrana Yazdır (Batarya Sıcaklığını da ekledim)
                    pos = sensor_data.get('position', 0)
                    acc = sensor_data.get('acceleration', 0)
                    spd = sensor_data.get('speed', 0)
                    bat = sensor_data.get('battery_temp', 0)
                    
                    sys.stdout.write(f"\r📊 Hız: {spd:.1f} km/h | Batarya: {bat:.1f}°C | Konum: {pos:.1f} m | İvme: {acc:.2f} m/s²   ")
                    sys.stdout.flush()

                time.sleep(0.05) 

        except KeyboardInterrupt:
            print("\nKullanıcı durdurdu.")
        except Exception as e:
            print(f"\nHata: {e}")
        finally:
            self.cleanup()

if __name__ == "__main__":
    FinalClient().run()
