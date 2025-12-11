#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include "tcp_client.h"

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);

    // TCP Client oluştur
    TCPClient client;
    
    // QML Engine
    QQmlApplicationEngine engine;
    
    // QML'e client'ı tanıt
    engine.rootContext()->setContextProperty("tcpClient", &client);

    // Ana QML dosyasını yükle (build klasöründen)
    const QUrl url(QUrl::fromLocalFile("MainWindow.qml"));
    QObject::connect(
        &engine,
        &QQmlApplicationEngine::objectCreated,
        &app,
        [url](QObject *obj, const QUrl &objUrl) {
            if (!obj && url == objUrl)
                QCoreApplication::exit(-1);
        },
        Qt::QueuedConnection);
    
    engine.load(url);
    
    if (engine.rootObjects().isEmpty())
        return -1;

    return app.exec();
}
