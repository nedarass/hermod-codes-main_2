import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ApplicationWindow {
    id: mainWindow
    visible: true
    width: 1400
    height: 800
    minimumWidth: 800
    minimumHeight: 500
    title: "HERMOD HYPERLOOP CONTROL SYSTEM"
    
    color: "#0a0e27"
    
    // Arka plan gradient
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#0a0e27" }
            GradientStop { position: 1.0; color: "#1a1f3a" }
        }
    }
    
    // Debug - bağlantı durumunu göster
    Text {
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.margins: 10
        text: "Speed: " + tcpClient.speed + " | Temp: " + tcpClient.temperature + " | Brake: " + tcpClient.brakePressed
        color: "#00ff88"
        font.pixelSize: 10
        z: 100
    }
    
    // Header Bar
    Rectangle {
        id: headerBar
        width: parent.width
        height: 80
        z: 10
        
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#1e2645" }
            GradientStop { position: 1.0; color: "#0f1729" }
        }
        
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
            
            // Hyperloop Logo
            Rectangle {
                width: 60
                height: 60
                radius: 30
                color: "#00ff88"
                Layout.alignment: Qt.AlignVCenter
                
                Text {
                    anchors.centerIn: parent
                    text: "⚡"
                    font.pixelSize: 32
                    color: "#0a0e27"
                }
            }
            
            // Title
            ColumnLayout {
                spacing: 2
                Layout.alignment: Qt.AlignVCenter
                
                Text {
                    text: "HERMOD HYPERLOOP"
                    color: "#ffffff"
                    font.pixelSize: 24
                    font.bold: true
                    font.family: "Segoe UI"
                }
                
                Text {
                    text: "Control System v1.0"
                    color: "#00ff88"
                    font.pixelSize: 12
                }
            }
            
            Item { Layout.fillWidth: true }
            
            // Status Indicator
            Rectangle {
                width: 180
                height: 50
                radius: 25
                color: tcpClient.connected ? "#00ff8822" : "#ff444422"
                border.color: tcpClient.connected ? "#00ff88" : "#ff4444"
                border.width: 2
                Layout.alignment: Qt.AlignVCenter
                
                RowLayout {
                    anchors.centerIn: parent
                    spacing: 12
                    
                    Rectangle {
                        width: 12
                        height: 12
                        radius: 6
                        color: tcpClient.connected ? "#00ff88" : "#ff4444"
                        
                        SequentialAnimation on opacity {
                            running: tcpClient.connected
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.3; duration: 800 }
                            NumberAnimation { to: 1.0; duration: 800 }
                        }
                    }
                    
                    Text {
                        text: tcpClient.connected ? "ONLINE" : "OFFLINE"
                        color: tcpClient.connected ? "#00ff88" : "#ff4444"
                        font.pixelSize: 16
                        font.bold: true
                        font.family: "Segoe UI"
                    }
                }
            }
            
            // Connect Button
            Rectangle {
                width: 120
                height: 50
                radius: 8
                color: connectButtonArea.pressed ? "#00cc66" : (connectButtonArea.containsMouse ? "#00ff88" : "#00dd77")
                Layout.alignment: Qt.AlignVCenter
                
                Text {
                    anchors.centerIn: parent
                    text: tcpClient.connected ? "DISCONNECT" : "CONNECT"
                    color: "#0a0e27"
                    font.pixelSize: 14
                    font.bold: true
                }
                
                MouseArea {
                    id: connectButtonArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        if (tcpClient.connected) {
                            tcpClient.disconnect()
                        } else {
                            console.log("Connecting to 127.0.0.1:5555...")
                            tcpClient.connectToServer("127.0.0.1", 5555)
                        }
                    }
                }
            }
        }
    }
    
    // Main Content - Scrollable
    Flickable {
        anchors.fill: parent
        anchors.topMargin: 80
        contentHeight: mainContent.height
        contentWidth: width
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        
        ScrollBar.vertical: ScrollBar {
            active: true
            policy: ScrollBar.AsNeeded
        }
        
        ColumnLayout {
            id: mainContent
            width: parent.width
            spacing: 20
            
            // Sensor Data Cards
            GridLayout {
                id: cardGrid
                Layout.fillWidth: true
                Layout.margins: 20
                Layout.topMargin: 10
                columns: Math.max(1, Math.floor((mainWindow.width - 60) / 280))
                rowSpacing: 15
                columnSpacing: 15
                
                // Speed Card
                ModernSensorCard {
                    Layout.preferredWidth: 260
                    Layout.preferredHeight: 220
                    title: "SPEED"
                    value: tcpClient.speed
                    unit: "km/h"
                    icon: "▶"
                    accentColor: "#00d4ff"
                    maxValue: 500
                }
                
                // Temperature Card
                ModernSensorCard {
                    Layout.preferredWidth: 260
                    Layout.preferredHeight: 220
                    title: "TEMP"
                    value: tcpClient.temperature
                    unit: "°C"
                    icon: "🌡"
                    accentColor: "#ff6b35"
                    maxValue: 100
                }
                
                // Brake Card
                ModernSensorCard {
                    Layout.preferredWidth: 260
                    Layout.preferredHeight: 220
                    title: "BRAKE"
                    value: tcpClient.brakePressed
                    unit: "%"
                    icon: "■"
                    accentColor: "#ff4757"
                    maxValue: 100
                }
                
                // Battery Card
                ModernSensorCard {
                    Layout.preferredWidth: 260
                    Layout.preferredHeight: 220
                    title: "BATTERY"
                    value: "95"
                    unit: "%"
                    icon: "⚡"
                    accentColor: "#00ff88"
                    maxValue: 100
                }


                 // Position Card (Konum)
                 ModernSensorCard {
                     Layout.preferredWidth: 260
                     Layout.preferredHeight: 220
                     title: "POSITION"
                     value: tcpClient.position
                     unit: "m"
                     icon: "📍"  // Veya "🚩"
                      accentColor: "#d4af37" // Altın sarısı (Gold) - Farklılık olsun diye
                     maxValue: 3000 // Pisti 3km varsayarak (bunu değiştirebilirsin)
                }

                 // Acceleration Card (İvme)
                 ModernSensorCard {
                    Layout.preferredWidth: 260
                    Layout.preferredHeight: 220
                    title: "ACCELERATION"
                    value: tcpClient.acceleration
                    unit: "m/s²"
                    icon: "🚀"
                    accentColor: "#bd93f9" // Mor (Purple) - Neon tema ile uyumlu
                    maxValue: 20 // Max 20 m/s² (Yaklaşık 2G) varsayıldı
                }
            }
            
            // Control Panels
            GridLayout {
                id: controlGrid
                Layout.fillWidth: true
                Layout.margins: 20
                columns: mainWindow.width > 900 ? 2 : 1
                rowSpacing: 15
                columnSpacing: 15
                
                // Motor Control Panel
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 520
                    Layout.minimumWidth: 300
                    radius: 15
                    color: "#1e2645"
                    border.color: "#2d3a5c"
                    border.width: 1
                    
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 25
                        spacing: 20
                        
                        Text {
                            text: "⚙ MOTOR CONTROL"
                            color: "#00d4ff"
                            font.pixelSize: 22
                            font.bold: true
                        }
                        
                        Rectangle { height: 1; Layout.fillWidth: true; color: "#2d3a5c" }
                        
                        // Motor Start/Stop Button
                        Rectangle {
                            id: motorButton
                            Layout.fillWidth: true
                            Layout.preferredHeight: 60
                            radius: 10

                             // Buton durumu için bir property (varsayılan: kapalı)
                            property bool isRunning: false

                            // Çalışıyorsa Kırmızı (Durdur), Duruyorsa Mavi (Başlat)
                            color: isRunning ? "#ff4757" : "#00d4ff"
                            border.color: isRunning ? "#ff8fa3" : "#80eaff"
                            border.width: 2

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 10

                                Text {
                                    text: "⚡"
                                    font.pixelSize: 20
                                    color: "#0a0e27"
                                }

                                Text {
                                    text: motorButton.isRunning ? "STOP MOTOR" : "START MOTOR"
                                    color: "#0a0e27"
                                    font.pixelSize: 18
                                    font.bold: true
                                    font.family: "Segoe UI"
                                    }
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor

                                // Tıklanınca ne olsun?
                                onClicked: {
                                motorButton.isRunning = !motorButton.isRunning


                                var cmdValue = motorButton.isRunning ? 1 : 0
                                tcpClient.sendCommand("motor_power", cmdValue)

                               console.log("Motor komutu gönderildi: " + cmdValue)
                                }


                                onEntered: parent.opacity = 0.9
                                onExited: parent.opacity = 1.0
                           }


                            Behavior on color {
                            ColorAnimation { duration: 200 }
                                }
                         }

                                                // Buton ile slider arasına biraz boşluk
                                                Item { height: 10 }
                        // Frequency Control
                        ControlSlider {
                            id: frequencySlider
                            Layout.fillWidth: true
                            label: "Motor Frequency"
                            unit: "Hz"
                            minVal: 0
                            maxVal: 60
                            accentColor: "#00d4ff"
                            commandName: "set_frequency"
                        }
                        
                        Item { height: 10 }
                        
                        // Speed Limit
                        ControlSlider {
                            id: speedLimitSlider
                            Layout.fillWidth: true
                            label: "Speed Limit"
                            unit: "km/h"
                            minVal: 0
                            maxVal: 500
                            currentValue: 100
                            accentColor: "#00ff88"
                            commandName: "speed_limit"
                        }
                        
                        Item { Layout.fillHeight: true }
                    }
                }
                
                // Safety Control Panel
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 350
                    Layout.minimumWidth: 300
                    radius: 15
                    color: "#1e2645"
                    border.color: "#2d3a5c"
                    border.width: 1
                    
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 25
                        spacing: 20
                        
                        Text {
                            text: "🛑 SAFETY CONTROLS"
                            color: "#ff6b35"
                            font.pixelSize: 22
                            font.bold: true
                        }
                        
                        Rectangle { height: 1; Layout.fillWidth: true; color: "#2d3a5c" }
                        
                        // Brake Control
                        ControlSlider {
                            id: brakeSlider
                            Layout.fillWidth: true
                            label: "Brake Force"
                            unit: "%"
                            minVal: 0
                            maxVal: 100
                            accentColor: "#ff4757"
                            commandName: "brake"
                        }
                        
                        Item { Layout.fillHeight: true }
                        
                        // Emergency Stop
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 100
                            radius: 12
                            color: emergencyMouseArea.pressed ? "#cc0000" : (emergencyMouseArea.containsMouse ? "#ff3333" : "#ff0000")
                            
                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 8
                                
                                Text {
                                    text: "⚠"
                                    font.pixelSize: 40
                                    color: "white"
                                    Layout.alignment: Qt.AlignHCenter
                                }
                                
                                Text {
                                    text: "EMERGENCY STOP"
                                    font.pixelSize: 20
                                    font.bold: true
                                    color: "white"
                                    Layout.alignment: Qt.AlignHCenter
                                }
                            }
                            
                            MouseArea {
                                id: emergencyMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: {
                                    tcpClient.sendCommand("emergency_stop", 1)
                                }
                            }
                            
                            SequentialAnimation on scale {
                                running: true
                                loops: Animation.Infinite
                                NumberAnimation { to: 1.02; duration: 1000; easing.type: Easing.InOutQuad }
                                NumberAnimation { to: 1.0; duration: 1000; easing.type: Easing.InOutQuad }
                            }
                        }
                    }
                }
            }
            
            Item { height: 20 }  // Bottom spacing
        }
    }
    
    // Modern Sensor Card Component
    component ModernSensorCard: Rectangle {
        property string title: ""
        property string value: "0"
        property string unit: ""
        property string icon: ""
        property color accentColor: "#00ff88"
        property real maxValue: 100
        
        radius: 15
        color: "#1e2645"
        border.color: accentColor
        border.width: 2
        
        Rectangle {
            anchors.fill: parent
            anchors.margins: 2
            radius: 13
            color: "#0f1729"
            
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 15
                
                // Header
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12
                    
                    Rectangle {
                        width: 40
                        height: 40
                        radius: 20
                        color: accentColor + "33"
                        
                        Text {
                            anchors.centerIn: parent
                            text: icon
                            font.pixelSize: 22
                            color: accentColor
                        }
                    }
                    
                    Text {
                        text: title
                        color: "#b0b8cc"
                        font.pixelSize: 16
                        font.bold: true
                        font.family: "Segoe UI"
                    }
                }
                
                Item { Layout.fillHeight: true }
                
                // Value Display
                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 8
                    
                    Text {
                        text: value
                        color: accentColor
                        font.pixelSize: 52
                        font.bold: true
                        font.family: "Segoe UI"
                    }
                    
                    Text {
                        text: unit
                        color: "#7080a0"
                        font.pixelSize: 20
                        Layout.alignment: Qt.AlignBottom
                        Layout.bottomMargin: 10
                    }
                }
                
                // Progress Bar
                Rectangle {
                    Layout.fillWidth: true
                    height: 8
                    radius: 4
                    color: "#2d3a5c"
                    
                    Rectangle {
                        width: parent.width * Math.min(parseFloat(value) / maxValue, 1.0)
                        height: parent.height
                        radius: 4
                        color: accentColor
                        
                        Behavior on width {
                            NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
                        }
                    }
                }
            }
        }
        
        // Glow effect
        Rectangle {
            anchors.fill: parent
            anchors.margins: -4
            radius: 17
            color: "transparent"
            border.color: accentColor
            border.width: 1
            opacity: 0.3
        }
    }
    
    // Control Slider Component
    component ControlSlider: Rectangle {
        property string label: ""
        property string unit: ""
        property real minVal: 0
        property real maxVal: 100
        property real currentValue: 0
        property color accentColor: "#00ff88"
        property string commandName: ""
        
        height: 120
        radius: 10
        color: "#0f1729"
        border.color: "#2d3a5c"
        border.width: 1
        
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 15
            spacing: 12
            
            RowLayout {
                Layout.fillWidth: true
                
                Text {
                    text: label
                    color: "#b0b8cc"
                    font.pixelSize: 16
                    font.bold: true
                }
                
                Item { Layout.fillWidth: true }
                
                Text {
                    id: valueDisplay
                    text: Math.round(slider.value) + " " + unit
                    color: accentColor
                    font.pixelSize: 20
                    font.bold: true
                }
            }
            
            Slider {
                id: slider
                Layout.fillWidth: true
                from: minVal
                to: maxVal
                value: currentValue
                stepSize: 1
                
                background: Rectangle {
                    x: slider.leftPadding
                    y: slider.topPadding + slider.availableHeight / 2 - height / 2
                    width: slider.availableWidth
                    height: 8
                    radius: 4
                    color: "#2d3a5c"
                    
                    Rectangle {
                        width: slider.visualPosition * parent.width
                        height: parent.height
                        color: accentColor
                        radius: 4
                    }
                }
                
                handle: Rectangle {
                    x: slider.leftPadding + slider.visualPosition * (slider.availableWidth - width)
                    y: slider.topPadding + slider.availableHeight / 2 - height / 2
                    width: 24
                    height: 24
                    radius: 12
                    color: slider.pressed ? Qt.darker(accentColor, 1.2) : accentColor
                    border.color: "#ffffff"
                    border.width: 2
                }
            }
            
            Rectangle {
                Layout.fillWidth: true
                height: 36
                radius: 6
                color: sendButtonArea.pressed ? Qt.darker(accentColor, 1.3) : (sendButtonArea.containsMouse ? Qt.lighter(accentColor, 1.2) : accentColor)
                
                Text {
                    anchors.centerIn: parent
                    text: "SEND"
                    color: "#0a0e27"
                    font.pixelSize: 14
                    font.bold: true
                }
                
                MouseArea {
                    id: sendButtonArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        tcpClient.sendCommand(commandName, Math.round(slider.value))
                    }
                }
            }
        }
    }
}
