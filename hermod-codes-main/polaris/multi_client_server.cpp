#include <iostream>
#include <string>
#include <vector>
#include <algorithm>
#include <thread>
#include <mutex>
#include <chrono>
#include <cstring>
#include <sstream>
#include <unistd.h>
#include <arpa/inet.h>
#include <sys/select.h>

class MultiClientServer {
private:
    int port;
    int server_fd;
    std::vector<int> clients;
    std::mutex clients_mutex;
    bool running;
    
public:
    MultiClientServer(int p) : port(p), server_fd(-1), running(false) {}
    
    ~MultiClientServer() {
        stop();
    }
    
    bool start() {
        server_fd = socket(AF_INET, SOCK_STREAM, 0);
        if (server_fd == -1) {
            std::cerr << "Socket oluşturulamadı!" << std::endl;
            return false;
        }
        
        int opt = 1;
        setsockopt(server_fd, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));
        
        sockaddr_in server_addr{};
        server_addr.sin_family = AF_INET;
        server_addr.sin_addr.s_addr = INADDR_ANY;
        server_addr.sin_port = htons(port);
        
        if (bind(server_fd, (struct sockaddr*)&server_addr, sizeof(server_addr)) < 0) {
            std::cerr << "Bind hatası!" << std::endl;
            return false;
        }
        
        if (listen(server_fd, 5) < 0) {
            std::cerr << "Listen hatası!" << std::endl;
            return false;
        }
        
        running = true;
        std::cout << "✓ Multi-Client Server başlatıldı - Port: " << port << std::endl;
        return true;
    }
    
    void broadcast(const std::string& data) {
        std::lock_guard<std::mutex> lock(clients_mutex);
        
        std::vector<int> disconnected;
        
        for (int client_fd : clients) {
            ssize_t sent = send(client_fd, data.c_str(), data.length(), MSG_NOSIGNAL);
            if (sent <= 0) {
                disconnected.push_back(client_fd);
            }
        }
        
        // Bağlantısı kopan clientları temizle
        for (int fd : disconnected) {
            close(fd);
            clients.erase(std::remove(clients.begin(), clients.end(), fd), clients.end());
            std::cout << "⚠ Client disconnected: " << fd << std::endl;
        }
    }
    
    void acceptLoop() {
        while (running) {
            sockaddr_in client_addr{};
            socklen_t client_len = sizeof(client_addr);
            
            int client_fd = accept(server_fd, (struct sockaddr*)&client_addr, &client_len);
            if (client_fd < 0) {
                if (running) {
                    std::cerr << "Accept hatası" << std::endl;
                }
                continue;
            }
            
            {
                std::lock_guard<std::mutex> lock(clients_mutex);
                clients.push_back(client_fd);
            }
            
            std::cout << "✓ Yeni client bağlandı: " << inet_ntoa(client_addr.sin_addr) 
                      << " (fd: " << client_fd << ")" << std::endl;
            
            // Her client için ayrı thread
            std::thread([this, client_fd]() {
                this->handleClient(client_fd);
            }).detach();
        }
    }
    
    void handleClient(int client_fd) {
        char buffer[4096];
        
        while (running) {
            memset(buffer, 0, sizeof(buffer));
            ssize_t bytes = recv(client_fd, buffer, sizeof(buffer) - 1, 0);
            
            if (bytes <= 0) {
                break; // Client disconnected
            }
            
            std::string data(buffer, bytes);
            
            // Sensör verilerini göster
            std::cout << "📊 [Client " << client_fd << "] Veri: " << data.substr(0, 80);
            if (data.length() > 80) std::cout << "...";
            std::cout << std::endl;
            
            // Tüm diğer clientlara broadcast et
            broadcast(data);
        }
        
        // Client temizliği
        {
            std::lock_guard<std::mutex> lock(clients_mutex);
            close(client_fd);
            clients.erase(std::remove(clients.begin(), clients.end(), client_fd), clients.end());
        }
        
        std::cout << "⚠ Client ayrıldı: " << client_fd << std::endl;
    }
    
    void stop() {
        running = false;
        
        {
            std::lock_guard<std::mutex> lock(clients_mutex);
            for (int fd : clients) {
                close(fd);
            }
            clients.clear();
        }
        
        if (server_fd != -1) {
            close(server_fd);
            server_fd = -1;
        }
    }
    
    int getClientCount() {
        std::lock_guard<std::mutex> lock(clients_mutex);
        return clients.size();
    }
};

int main() {
    std::cout << "=== Hermod Polaris Multi-Client Server ===" << std::endl;
    std::cout << "Raspberry Pi veri gönderir → Server → GUI'ye broadcast eder\n" << std::endl;
    
    MultiClientServer server(5555);
    
    if (!server.start()) {
        return 1;
    }
    
    std::cout << "✓ Server hazır! Clientlar bekleniyor..." << std::endl;
    std::cout << "  - Raspberry Pi test client'ı bağlanabilir (veri gönderen)" << std::endl;
    std::cout << "  - Bifrost GUI bağlanabilir (veri alan)" << std::endl;
    std::cout << "  - Her veri tüm clientlara broadcast edilir\n" << std::endl;
    
    // Status thread
    std::thread status_thread([&server]() {
        while (true) {
            std::this_thread::sleep_for(std::chrono::seconds(10));
            std::cout << "📊 Aktif client sayısı: " << server.getClientCount() << std::endl;
        }
    });
    status_thread.detach();
    
    // Accept loop (blocking)
    server.acceptLoop();
    
    return 0;
}
