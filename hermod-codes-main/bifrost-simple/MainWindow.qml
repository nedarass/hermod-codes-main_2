import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ApplicationWindow {
    id: mainWindow
    visible: true
    width: 1400
    height: 900
    minimumWidth: 1000
    minimumHeight: 600
    title: "HERMOD HYPERLOOP CONTROL SYSTEM"
    color: "#0a0e27"

    // =========================================================
    // 1. HEADER BAR (Bağlantı ve Durum Paneli - Eski Haline Döndü)
    // =========================================================
    Rectangle {
        id: headerBar
        width: parent.width
        height: 80
        z: 100 // En üstte dursun

        gradient: Gradient {
            GradientStop { position: 0.0; color: "#1e2645" }
            GradientStop { position: 1.0; color: "#0f1729" }
        }

        // Alt çizgi (Bağlantı durumuna göre renk değiştirir)
        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: 2
            color: tcpClient.connected ? "#00ff88" : "#ff4444"
        }

        RowLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 30

            // Logo Alanı
            Rectangle {
                width: 50; height: 50; radius: 25
                color: "#00ff88"
                Text {
                    anchors.centerIn: parent
                    text: "⚡"; font.pixelSize: 28; color: "#0a0e27"
                }
            }

            // Başlık
            ColumnLayout {
                spacing: 0
                Text {
                    text: "HERMOD HYPERLOOP"; color: "white"
                    font.pixelSize: 22; font.bold: true
                }
                Text {
                    text: "Control Station v2.0"; color: "#00ff88"
                    font.pixelSize: 11
                }
            }

            Item { Layout.fillWidth: true } // Boşluk

            // Bağlantı Durumu Göstergesi
            Rectangle {
                width: 140; height: 40; radius: 20
                color: tcpClient.connected ? "#00ff8822" : "#ff444422"
                border.color: tcpClient.connected ? "#00ff88" : "#ff4444"
                border.width: 1

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 10
                    Rectangle {
                        width: 10; height: 10; radius: 5
                        color: tcpClient.connected ? "#00ff88" : "#ff4444"
                    }
                    Text {
                        text: tcpClient.connected ? "ONLINE" : "OFFLINE"
                        color: tcpClient.connected ? "#00ff88" : "#ff4444"
                        font.bold: true
                    }
                }
            }

            // CONNECT Butonu
            Button {
                text: tcpClient.connected ? "DISCONNECT" : "CONNECT"
                palette.button: tcpClient.connected ? "#ff4757" : "#00ff88"
                palette.buttonText: "black"
                font.bold: true
                onClicked: {
                    if (tcpClient.connected) tcpClient.disconnect()
                    else tcpClient.connectToServer("127.0.0.1", 5555)
                }
            }
        }
    }

    // =========================================================
    // 2. ANA İÇERİK (Scroll Edilebilir)
    // =========================================================
    Flickable {
        anchors.top: headerBar.bottom
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        contentHeight: mainContent.height + 50
        clip: true

        ColumnLayout {
            id: mainContent
            width: parent.width - 40
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 20
            spacing: 25

            // --- A. TÜNEL GÖRSELLEŞTİRME ---
            Rectangle {
                Layout.fillWidth: true
                height: 150
                color: "#161b33"
                radius: 10
                border.color: "#2d3a5c"
                border.width: 2

                // Metre Çizgileri
                Row {
                    anchors.centerIn: parent
                    spacing: (parent.width - 60) / 20
                    Repeater {
                        model: 21
                        Rectangle {
                            width: 1; height: 100
                            color: "#2d3a5c"
                            Text {
                                anchors.top: parent.bottom; anchors.topMargin: 5
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: (index * 10) + "m"; color: "#506080"; font.pixelSize: 10
                            }
                        }
                    }
                }

                // HAREKET EDEN POD
                Rectangle {
                    id: podIndicator
                    width: (2.0 / tunnelLen) * visWidth; height: 30; radius: 2
                    color: "#00d4ff"; border.color: "white"; border.width: 2

                    property real tunnelLen: 208.0
                    property real visWidth: parent.width - 80

                    // Konuma göre X hesaplama
                    x: 40 + (Math.min(tcpClient.position, tunnelLen) / tunnelLen) * visWidth
                    y: (parent.height - height) / 2

                    Text {
                        anchors.centerIn: parent
                        text: tcpClient.position.toFixed(1) + "m"
                        color: "black"; font.bold: true; font.pixelSize: 11
                    }

                    // Hareket Animasyonu
                    Behavior on x { NumberAnimation { duration: 100 } }
                }

                // Kritik Noktalar (Sarı: Start, Kırmızı: Özel Bölgeler)
                Rectangle { x: (11/208)*(parent.width-80)+40; y: 15; width: 2; height: 120; color: "yellow"; opacity: 0.6 }
                Rectangle { x: (86/208)*(parent.width-80)+40; y: 15; width: 2; height: 120; color: "red"; opacity: 0.6 }
                Rectangle { x: (160/208)*(parent.width-80)+40; y: 15; width: 2; height: 120; color: "red"; opacity: 0.6 }
            }

            // --- B. SENSÖR KARTLARI (İvme Eklendi) ---
            GridLayout {
                Layout.fillWidth: true
                columns: 5 // 5 Kart yan yana
                columnSpacing: 15

                // 1. HIZ
                SensorCard { title: "SPEED"; value: tcpClient.speed; unit: "km/h"; icon: "🚀"; colorCode: "#00d4ff" }
                // 2. MOTOR ISISI
                SensorCard { title: "MOTOR TEMP"; value: tcpClient.temperature; unit: "°C"; icon: "🌡"; colorCode: "#ff6b35" }
                // 3. BATARYA
                SensorCard { title: "BATTERY"; value: "48.2"; unit: "V"; icon: "⚡"; colorCode: "#f9ca24" }
                // 4. İVME (YENİ)
                SensorCard { title: "ACCEL"; value: tcpClient.acceleration; unit: "m/s²"; icon: "📉"; colorCode: "#bd93f9" }
                // 5. FREN BASINCI
                SensorCard { title: "BRAKE PRS"; value: tcpClient.brakePressed; unit: "%"; icon: "🛑"; colorCode: "#ff4757" }
            }

            // --- C. KONTROL PANELLERİ (Slider Yok, Sadece Input) ---
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 250
                spacing: 20

                // MOTOR CONTROL KUTUSU
                ControlBox {
                    Layout.fillWidth: true; Layout.fillHeight: true
                    title: "MOTOR CONTROL"
                    accentColor: "#00d4ff"

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 20
                        width: parent.width * 0.8

                        // Input Alanı
                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: "Frequency (0-60 Hz):"; color: "#b0b8cc"; font.pixelSize: 14 }
                            Item { Layout.fillWidth: true }

                            TextField {
                                id: motorInput
                                placeholderText: "0.0"
                                color: "white"
                                font.pixelSize: 18
                                horizontalAlignment: Text.AlignHCenter
                                background: Rectangle { color: "#0f1729"; border.color: "#2d3a5c"; radius: 5; width: 80; height: 40 }
                                validator: DoubleValidator { bottom: 0; top: 60 }
                            }

                            Button {
                                text: "SET"
                                onClicked: {
                                    var val = parseFloat(motorInput.text)
                                    tcpClient.sendCommand("set_frequency", val)
                                    motorStatusText.text = "Target: " + val + " Hz"
                                }
                            }
                        }

                        Text { id: motorStatusText; text: "Target: 0 Hz"; color: "#00d4ff"; font.bold: true }

                        // Hızlı Butonlar
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10
                            Button {
                                text: "START (10Hz)"
                                Layout.fillWidth: true
                                onClicked: {
                                    motorInput.text = "10"
                                    tcpClient.sendCommand("set_frequency", 10)
                                }
                            }
                            Button {
                                text: "STOP (0Hz)"
                                Layout.fillWidth: true
                                palette.button: "#ff4757"
                                onClicked: {
                                    motorInput.text = "0"
                                    tcpClient.sendCommand("set_frequency", 0)
                                }
                            }
                        }
                    }
                }

                // BRAKE CONTROL KUTUSU
                ControlBox {
                    Layout.fillWidth: true; Layout.fillHeight: true
                    title: "BRAKE CONTROL"
                    accentColor: "#ff4757"

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 20
                        width: parent.width * 0.8

                        // Input Alanı
                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: "Force (0-100 %):"; color: "#b0b8cc"; font.pixelSize: 14 }
                            Item { Layout.fillWidth: true }

                            TextField {
                                id: brakeInput
                                placeholderText: "0"
                                color: "white"
                                font.pixelSize: 18
                                horizontalAlignment: Text.AlignHCenter
                                background: Rectangle { color: "#0f1729"; border.color: "#2d3a5c"; radius: 5; width: 80; height: 40 }
                                validator: IntValidator { bottom: 0; top: 100 }
                            }

                            Button {
                                text: "APPLY"
                                onClicked: {
                                    var val = parseFloat(brakeInput.text)
                                    tcpClient.sendCommand("brake_level", val)
                                }
                            }
                        }

                        // ACİL DURDURMA BUTONU (Çok Büyük)
                        Button {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 60
                            text: "EMERGENCY STOP"
                            font.bold: true
                            font.pixelSize: 18

                            background: Rectangle {
                                color: parent.down ? "#990000" : "#cc0000"
                                radius: 8
                                border.color: "red"
                                border.width: 2
                            }
                            contentItem: Text {
                                text: parent.text
                                color: "white"
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                font: parent.font
                            }

                            onClicked: {
                                brakeInput.text = "100"
                                motorInput.text = "0"
                                tcpClient.sendCommand("emergency_stop", 1)
                            }
                        }
                    }
                }
            }
        }
    }

    // =========================================================
    // YARDIMCI BİLEŞENLER
    // =========================================================

    // Sensör Kartı Tasarımı
    component SensorCard: Rectangle {
        property string title: ""
        property string value: "0"
        property string unit: ""
        property string icon: ""
        property color colorCode: "white"

        Layout.fillWidth: true
        Layout.preferredHeight: 110
        color: "#1e2645"
        radius: 10
        border.color: colorCode

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 5
            Text { text: icon + " " + title; color: "#b0b8cc"; font.pixelSize: 13 }
            Text { text: value; color: colorCode; font.pixelSize: 32; font.bold: true }
            Text { text: unit; color: "#7080a0"; font.pixelSize: 13 }
        }
    }

    // Kontrol Kutusu Tasarımı
    component ControlBox: Rectangle {
        property string title: ""
        property color accentColor: "white"
        default property alias content: contentArea.data

        color: "#1e2645"
        radius: 10
        border.color: "#2d3a5c"

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            // Başlık Çubuğu
            Rectangle {
                Layout.fillWidth: true; height: 40
                color: "transparent"
                border.width: 0

                Text {
                    anchors.centerIn: parent
                    text: title; color: accentColor; font.bold: true; font.pixelSize: 16
                }
                Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: "#2d3a5c" }
            }

            // İçerik Alanı
            Item {
                id: contentArea
                Layout.fillWidth: true; Layout.fillHeight: true
            }
        }
    }
}
