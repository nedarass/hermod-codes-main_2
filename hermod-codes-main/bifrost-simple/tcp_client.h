#ifndef TCP_CLIENT_H
#define TCP_CLIENT_H

#include <QObject>
#include <QTcpSocket>
#include <QJsonDocument>
#include <QJsonObject>

class TCPClient : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool connected READ isConnected NOTIFY connectedChanged)
    Q_PROPERTY(QString speed READ getSpeed NOTIFY sensorDataChanged)
    Q_PROPERTY(QString temperature READ getTemperature NOTIFY sensorDataChanged)
    Q_PROPERTY(QString brakePressed READ getBrakePressed NOTIFY sensorDataChanged)
    // konum ve ivme için 
    Q_PROPERTY(double position READ getPosition NOTIFY sensorDataChanged)
    Q_PROPERTY(QString acceleration READ getAcceleration NOTIFY sensorDataChanged)

public:
    explicit TCPClient(QObject *parent = nullptr);
    ~TCPClient();

    // QML'den çağrılabilir fonksiyonlar
    Q_INVOKABLE void connectToServer(const QString &host, int port);
    Q_INVOKABLE void disconnect();
    Q_INVOKABLE void sendCommand(const QString &command, int value);
    
    bool isConnected() const;
    QString getSpeed() const { return speed; }
    QString getTemperature() const { return temperature; }
    QString getBrakePressed() const { return brakePressed; }
    // konum ve ivme için
    double getPosition() const { return position; }
    QString getAcceleration() const { return acceleration; }

signals:
    void connectedChanged();
    void sensorDataChanged();
    void errorOccurred(const QString &error);

private slots:
    void onConnected();
    void onDisconnected();
    void onReadyRead();
    void onError(QAbstractSocket::SocketError error);

private:
    void parseSensorData(const QString &data);
    
    QTcpSocket *socket;
    QString speed;
    QString temperature;
    QString brakePressed;
    QString buffer;
    // konum ve ivme için
    double position;
    QString acceleration;
};

#endif
