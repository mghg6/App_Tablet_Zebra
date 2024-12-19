import 'package:flutter/material.dart';

class SettingsPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ajustes Generales',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF46707E),
                ),
              ),
              SizedBox(height: 20),
              ListTile(
                leading: Icon(Icons.person, color: Color(0xFF46707E)),
                title: Text('Cuenta'),
                subtitle: Text('Administra la configuración de tu cuenta'),
                onTap: () {},
              ),
              Divider(),
              ListTile(
                leading: Icon(Icons.notifications, color: Color(0xFF46707E)),
                title: Text('Notificaciones'),
                subtitle: Text('Preferencias de notificaciones'),
                onTap: () {},
              ),
              Divider(),
              ListTile(
                leading: Icon(Icons.lock, color: Color(0xFF46707E)),
                title: Text('Privacidad'),
                subtitle: Text('Configuración de privacidad y seguridad'),
                onTap: () {},
              ),
              Divider(),
              ListTile(
                leading: Icon(Icons.info, color: Color(0xFF46707E)),
                title: Text('Acerca de'),
                subtitle: Text('Información sobre esta aplicación'),
                onTap: () {},
              ),
            ],
          ),
        ),
      ),
    );
  }
}
