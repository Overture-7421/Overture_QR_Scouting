# Configuración de la Base de Datos Externa de Firebase

Esta guía explica cómo configurar la aplicación para enviar datos de scouting QR a una base de datos externa de Firebase Realtime Database.

## Resumen

La aplicación ahora soporta:

1. **Horario por Defecto**: La aplicación carga automáticamente el archivo `sample_schedule.txt` del proyecto al iniciar.
2. **Base de Datos Externa de Firebase**: Envía todos los datos de scouting a una base de datos Firebase Realtime Database en un proyecto diferente.

## Pasos de Configuración

### 1. Habilitar la Base de Datos Externa

Edita el archivo `lib/external_firebase_config.json`:

```json
{
  "databaseURL": "https://TU-PROYECTO-EXTERNO-default-rtdb.firebaseio.com",
  "enabled": true
}
```

Reemplaza `TU-PROYECTO-EXTERNO` con el ID real de tu proyecto Firebase.

### 2. Obtener la URL de tu Base de Datos

1. Ve a tu proyecto Firebase externo en la [Consola de Firebase](https://console.firebase.google.com/)
2. Navega a **Realtime Database** en la barra lateral izquierda
3. Si aún no has creado una base de datos, haz clic en **Crear base de datos**
4. Elige tu ubicación y reglas de seguridad (empieza en modo de prueba para desarrollo)
5. Copia la URL de la base de datos, que se ve así: `https://tu-proyecto-id-default-rtdb.firebaseio.com`

### 3. Configurar las Reglas de la Base de Datos

En tu proyecto Firebase externo, ve a **Realtime Database** → **Reglas** y establece las reglas de seguridad apropiadas.

Para desarrollo/pruebas (NO recomendado para producción):
```json
{
  "rules": {
    "scouting_data": {
      ".read": true,
      ".write": true
    }
  }
}
```

### 4. Reconstruir y Desplegar

Después de configurar `external_firebase_config.json`, reconstruye la aplicación:

```bash
flutter pub get
flutter build web
```

Luego despliega a Firebase Hosting:

```bash
firebase deploy --only hosting
```

## Actualizar el Horario por Defecto

Para actualizar el horario predeterminado que se carga automáticamente:

1. Edita `lib/sample_schedule.txt` con la información de tu evento
2. Formato:
   ```
   Event: Nombre de tu Evento 2025
   # ScouterID , Match , Position , Team
   SCOUT1, 1, Blue 1, 1234
   SCOUT2, 2, Red 2, 5678
   ```
3. Reconstruye: `flutter build web`
4. Despliega: `firebase deploy --only hosting`

## Estructura de Datos

Los datos se guardan en el nodo `scouting_data` de tu Firebase con esta estructura:

```
scouting_data/
  ├── [id-auto-generado-1]/
  │   ├── scouterInitials: "ABC"
  │   ├── matchNumber: "1"
  │   ├── teamNumber: "1234"
  │   ├── robot: "Blue 1"
  │   ├── ... (todos los demás campos)
  │   └── timestamp: 1234567890123
  └── [id-auto-generado-2]/
      └── ...
```

## Desactivar Firebase Externo

Para desactivar la integración con Firebase externo, establece `"enabled": false`:

```json
{
  "databaseURL": "https://TU-PROYECTO.firebaseio.com",
  "enabled": false
}
```

## Notas

- Los datos se envían cuando el usuario hace clic en "Commit"
- Si el envío a la base de datos externa falla, se muestra un mensaje de error pero el código QR sigue funcionando
- Se muestra un mensaje de éxito cuando los datos se envían correctamente
- El horario predeterminado se carga automáticamente al iniciar la aplicación
- Los usuarios pueden subir su propio horario para reemplazar el predeterminado
