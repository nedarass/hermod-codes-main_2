#include "tcp_client.h"
#include <QDebug>

TCPClient::TCPClient(QObject *parent) 
    : QObject(parent)
    , socket(new QTcpSocket(this))
    , speed("0")
    , temperature("0")
    , brakePressed("0")
    // konum ve ivme için
    , position("0")
    , acceleration("0.0")
{
    connect(socket, &QTcpSocket::connected, this, &TCPClient::onConnected);
    connect(socket, &QTcpSocket::disconnected, this, &TCPClient::onDisconnected);
    connect(socket, &QTcpSocket::readyRead, this, &TCPClient::onReadyRead);
    connect(socket, &QTcpSocket::errorOccurred, this, &TCPClient::onError);
}

TCPClient::~TCPClient() {
    if (socket->isOpen()) {
        socket->close();
    }
}

void TCPClient::connectToServer(const QString &host, int port) {
    if (socket->state() == QAbstractSocket::ConnectedState) {
        qDebug() << "Zaten bağlı!";
        return;
    }
    
    // localhost için 127.0.0.1 kullan
    QString connectHost = (host == "localhost") ? "192.168.2.3" : host;
    
    qDebug() << "Bağlanıyor:" << connectHost << ":" << port;
    socket->connectToHost(connectHost, port);
}

void TCPClient::disconnect() {
    socket->disconnectFromHost();
}

void TCPClient::sendCommand(const QString &command, int value) {
    if (!isConnected()) {
        qWarning() << "Bağlantı yok! Komut gönderilemedi.";
        return;
    }
    
    QJsonObject json;
    json["command"] = command;
    json["value"] = value;
    
    QJsonDocument doc(json);
    QString message = doc.toJson(QJsonDocument::Compact) + "\n";
    
    socket->write(message.toUtf8());
    socket->flush();
    
    qDebug() << "Komut gönderildi:" << command << "=" << value;
}

bool TCPClient::isConnected() const {
    return socket->state() == QAbstractSocket::ConnectedState;
}

void TCPClient::onConnected() {
    qDebug() << "✓ Server'a bağlandı!";
    emit connectedChanged();
}

void TCPClient::onDisconnected() {
    qDebug() << "Bağlantı kesildi";
    emit connectedChanged();
}

void TCPClient::onReadyRead() {
    buffer += QString::fromUtf8(socket->readAll());
    
    // Satır satır işle (her JSON bir satırda)
    while (buffer.contains('\n')) {
        int idx = buffer.indexOf('\n');
        QString line = buffer.left(idx).trimmed();
        buffer = buffer.mid(idx + 1);
        
        if (!line.isEmpty()) {
            parseSensorData(line);
        }
    }
}

void TCPClient::onError(QAbstractSocket::SocketError error) {
    QString errorMsg = socket->errorString();
    qWarning() << "TCP Hatası:" << errorMsg;
    emit errorOccurred(errorMsg);
}

void TCPClient::parseSensorData(const QString &data) {
    QJsonDocument doc = QJsonDocument::fromJson(data.toUtf8());
    if (doc.isNull() || !doc.isObject()) {
        qWarning() << "Geçersiz JSON:" << data;
        return;
    }
    
    QJsonObject json = doc.object();
    
    // Sensör verilerini güncelle ve debug
    if (json.contains("speed")) {
        speed = QString::number(json["speed"].toDouble(), 'f', 1);
        qDebug() << "Speed updated:" << speed;
    }
    if (json.contains("temperature")) {
        temperature = QString::number(json["temperature"].toDouble(), 'f', 1);
        qDebug() << "Temp updated:" << temperature;
    }
    if (json.contains("brake_pressure")) {
        brakePressed = QString::number(json["brake_pressure"].toInt());
        qDebug() << "Brake updated:" << brakePressed;
    }
    
    // Konum verisi (Metre cinsinden)
    if (json.contains("position")) {
        position = QString::number(json["position"].toDouble(), 'f', 1); // Virgülden sonra 1 basamak
        qDebug() << "Position updated:" << position;
    }

    // İvme verisi (m/s² veya g kuvveti)
    if (json.contains("acceleration")) {
        acceleration = QString::number(json["acceleration"].toDouble(), 'f', 2); // Hassas veri için 2 basamak
        qDebug() << "Acceleration updated:" << acceleration;
    }

    qDebug() << "Emitting sensorDataChanged signal";
    emit sensorDataChanged();
}
