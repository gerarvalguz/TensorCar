# TensorCar

*by OnceOnce Studio*

App de iPhone (SwiftUI) que lee los datos de tu auto con un adaptador **OBD-II ELM327 por WiFi**. Se probó contra un auto simulado; está pensada para una VW Taigun 2024, pero funciona con cualquier auto con puerto OBD-II (en general, autos de 2008 en adelante).

> No necesita internet ni cuenta. Todo lo que guarda se queda en el iPhone, y puedes respaldarlo en tu nube.

---

## Qué hace

### Bienvenida
- La primera vez que abres la app aparece un tutorial animado de 5 pasos: qué es TensorCar, cómo conectar el adaptador, la lectura en vivo, las fallas y el historial. Se puede saltar y no vuelve a salir.

### Conexión
- Se conecta por TCP al adaptador WiFi (por defecto `192.168.0.10:35000`, editable y recordado).
- Instrucciones paso a paso para conectar el iPhone a la red del adaptador.
- **Modo demo:** un auto simulado para probar la app sin hardware (incluye fallas, VIN y sensores que cambian).
- Si el adaptador no responde en 10 segundos, muestra el error en vez de quedarse esperando.

### En vivo
- **Batería:** voltaje leído por el propio adaptador (`ATRV`), funciona con el motor apagado, con un estado estimado:

  | Motor | Voltaje | Estado |
  |---|---|---|
  | Apagado | ≥ 12.5 V | Batería cargada |
  | Apagado | 12.0–12.5 V | Carga media |
  | Apagado | < 12.0 V | Batería baja |
  | Encendido | 12.9–15.0 V | Carga normal |
  | Encendido | 12.0–12.9 V | Voltaje bajo en marcha |
  | Encendido | < 12.0 V | Alternador no carga |
  | Encendido | > 15.0 V | Sobrecarga |

  Es una estimación por voltaje, no la salud real de la batería. Algunos VW bajan la carga del alternador a propósito al circular.

- **Tarjetas principales:** RPM, velocidad, temperatura del refrigerante, carga del motor, acelerador y nivel de combustible, con barra de progreso.
- **Sensores clave del motor:** qué mide cada uno, su lectura en vivo y cuál es un valor normal.

  | Sensor | Lectura en la app |
  |---|---|
  | CKP · cigüeñal | RPM |
  | CMP · árbol de levas | Sin lectura OBD estándar; un desfase aparece como falla P0016–P0019 |
  | ECT · refrigerante | Temperatura (normal 85–95 °C en caliente) |
  | MAF · flujo de aire | g/s |
  | MAP · múltiple de admisión | kPa |
  | TPS · acelerador | % (OBD-II no da el voltaje) |
  | O₂ · oxígeno | λ banda ancha y voltaje de banda estrecha 1-1 y 1-2 |
  | KS · detonación | Sin lectura OBD estándar; muestra el avance de encendido, que baja con golpeteo; fallas P0325–P0334 |

- **Todos los sensores:** unos 35 PIDs estándar, solo los que tu auto reporta. Incluye ajustes de combustible, temperaturas de admisión, aceite, ambiente y catalizador, presión barométrica y del riel, lambda, consumo instantáneo, odómetro, tiempos y distancias desde el último borrado de fallas.
- La pantalla no se apaga mientras está conectada.

### Fallas
- Estado de la luz de motor (MIL) y cantidad de fallas.
- Códigos **almacenados**, **pendientes** y **permanentes**, cada uno con su título y el sistema al que pertenece.
- **Significado sin internet:** al tocar un código se abre su detalle (qué significa, causas probables y síntomas) desde una base de 9,533 códigos genéricos incluida en la app. Las descripciones están en inglés. Si el código no está (por ejemplo, uno propio del fabricante como P1xxx), hay un botón para buscarlo en internet.
- **Borrar fallas** con confirmación (queda registrado en el historial).

### Auto
- VIN, número de calibración y nombre del módulo, si el auto los reporta.
- **Monitores de emisiones** (listos / pendientes), para gasolina y diésel.
- Lista de los PIDs que reporta tu auto.

### Historial
Una línea de tiempo guardada en el iPhone:
- **Escaneo automático** cada vez que te conectas: fecha, kilometraje (si el auto reporta odómetro), voltaje de batería y fallas.
  - Compara con el escaneo anterior del mismo auto: fallas **nuevas** y las que **ya no aparecen**.
  - Avisa si las fallas **se borraron hace poco** (menos de 50 km y menos de 10 arranques), señal típica de que alguien las ocultó antes de vender.
- **Bitácora manual:** servicios, reparaciones, choques u otros, con fecha, kilometraje, taller, costo y notas.
- **Presión de neumáticos:** registro manual de las 4 llantas con una presión ideal configurable y estado por llanta:

  | Lectura | Estado |
  |---|---|
  | ≥ 25 % bajo el ideal | Muy baja |
  | > 2 psi bajo el ideal | Baja |
  | Hasta 4 psi sobre el ideal | Bien |
  | > 4 psi sobre el ideal | Alta |

- **Desliza** un registro a la izquierda para eliminarlo o a la derecha para editarlo. En los escaneos automáticos se puede editar el texto, la fecha y las notas, pero no el tipo.
- **Exportar / Importar:** exporta todo el historial a un archivo JSON (`TensorCar-historial-AAAA-MM-DD.json`) para guardarlo en iCloud Drive, Google Drive u otra nube. Importar agrega solo los registros que no estén ya en la app y nunca borra nada, así que sirve para pasar el historial a otro iPhone o recuperarlo tras reinstalar. El botón ⓘ lo explica dentro de la app.

### Apariencia
- Botón en el encabezado de cada pestaña que alterna **automático → claro → oscuro**.
- Ícono de la app con variante oscura (iOS 18+).

---

## Limitaciones

- **Solo OBD-II estándar** (SAE J1979): motor y emisiones. ABS, airbags, caja de cambios, módulo de batería, choques registrados y datos propios de cada marca requieren comandos UDS del fabricante y no están incluidos.
- **Presión de neumáticos:** la Taigun trae *Tyre Pressure Deflation Warning*, que por lo que indica su nombre es un sistema indirecto (usa los sensores de velocidad del ABS, sin sensores de presión), así que no hay un valor que leer; por eso el registro es manual.
- **Historial de colisiones y talleres:** no existe en el auto. Para el historial oficial, pide al concesionario el historial de servicio con tu VIN.
- Solo adaptadores **WiFi**. Bluetooth no está soportado.
- Algunos clones ELM327 responden fuera del estándar.
- El historial vive en el iPhone. No se sincroniza solo: si borras la app sin haber exportado un respaldo, se pierde.
- Las descripciones de fallas sin conexión están en inglés y solo cubren códigos genéricos.
- Si se corta la comunicación a mitad de una lectura, la app desconecta y hay que reconectar a mano.
- Presión de neumáticos solo en psi.

---

## Usar en el auto

1. Enchufa el adaptador al puerto OBD (bajo el volante) y pon el contacto.
2. En el iPhone, ve a **Ajustes › WiFi** y únete a la red del adaptador (suele llamarse `OBDII`, `V-LINK` o similar).
3. Abre la app, toca **Conectar al auto** y acepta el permiso de **red local**.
4. Si no conecta, revisa en el manual del adaptador su IP y puerto y cámbialos en la pestaña Conexión.

---

## Desarrollo

Requisitos: iOS 17 o posterior. Desarrollado y probado con Xcode 27.

### Correr en el iPhone
1. Abre `TensorCar.xcodeproj` en Xcode.
2. En **Signing & Capabilities** elige tu Team (y cambia el bundle id `com.gera.autoobd` si hace falta; se conservó del nombre anterior para no perder el historial de instalaciones existentes).
3. Conecta el iPhone y dale **Run**.

### Regenerar el proyecto
El `.xcodeproj` se genera con [XcodeGen](https://github.com/yonaskolb/XcodeGen) desde `project.yml`. Después de agregar archivos o cambiar ajustes:

```bash
xcodegen generate
```

### Pruebas
Las pruebas usan el auto simulado: protocolo ELM327, respuestas multi-trama (VIN), fallas, monitores, fórmulas de sensores, batería, neumáticos, historial, respaldo (exportar/importar/editar) y la base de fallas.

```bash
xcodebuild test -project TensorCar.xcodeproj -scheme TensorCar -destination 'platform=iOS Simulator,name=iPhone 16'
```

### Base de códigos de falla
`Sources/DTC.json` se genera desde [OBDex](https://github.com/foerbsnavi/OBDex) (datos CC0, dominio público) con título, descripción, causas y síntomas en inglés. Para actualizarla:

```bash
curl -LO https://foerbsnavi.github.io/OBDex/generic.json
```

```bash
python3 Tools/build_dtc.py generic.json Sources/DTC.json
```

### Estructura

| Archivo | Qué contiene |
|---|---|
| `Sources/Transport.swift` | Conexión TCP al adaptador (Network.framework) y errores |
| `Sources/MockTransport.swift` | Adaptador y auto simulados para el modo demo y las pruebas |
| `Sources/ELM327.swift` | Protocolo ELM327: inicialización, consultas, PIDs soportados, fallas, VIN, monitores, voltaje |
| `Sources/PIDs.swift` | Tabla de sensores y fórmulas, guía de sensores clave, reglas de batería y neumáticos |
| `Sources/OBDModel.swift` | Estado de la app: conexión, lectura continua, fallas, escaneo al historial |
| `Sources/History.swift` | Historial guardado en `Documents/history.json`, respaldo JSON (exportar/importar) |
| `Sources/DTCDictionary.swift` | Lectura de la base de fallas offline y pantalla de detalle |
| `Sources/DTC.json` | Base de 9,533 códigos de falla genéricos |
| `Sources/Tutorial.swift` | Tutorial animado de bienvenida |
| `Sources/Views.swift` | El resto de las pantallas y el estilo |
| `Sources/Assets.xcassets` | Ícono de la app (claro y oscuro) |
| `Tests/OBDTests.swift` | Pruebas unitarias |
| `Tools/build_dtc.py` | Genera `DTC.json` desde OBDex |

### Cómo habla con el auto
1. Abre TCP al adaptador y lo inicializa: `ATZ`, `ATE0`, `ATL0`, `ATS0`, `ATH0`, `ATSP0` (protocolo automático).
2. Pide los PIDs soportados (`0100`, `0120`, …) y detecta si el protocolo es CAN (`ATDPN`).
3. Lee estado (`0101`), fallas (`03`, `07`, `0A`), VIN y datos del módulo (`0902`, `0904`, `090A`) y voltaje (`ATRV`).
4. Lee en bucle los sensores rápidos (RPM, velocidad, carga, acelerador) en cada vuelta y el resto por turnos.
