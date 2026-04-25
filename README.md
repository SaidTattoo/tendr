# Tendr

App de iOS para tareas recurrentes visualizadas como anillos tipo "batería de tiempo". Cada tarea tiene una frecuencia (cada N horas/días, semanal con día específico o mensual con día específico) y un anillo que se va vaciando hasta que toca hacerla.

Inspirado en el widget de baterías nativo de iOS.

## Concepto

Si riegas una planta una vez por semana, el anillo de esa tarea va de 100% (acabas de regarla) a 0% (toca regarla otra vez). Verde → amarillo → rojo según se acerca el vencimiento. Al marcar como hecha, el anillo se llena de nuevo.

## Funcionalidades

- **Frecuencias flexibles** — cada N horas (medicación), cada N días (planta), semanal con día (sábados sacar basura), mensual con día (renta el 1)
- **Tareas con duración** — opcional `endsAt` para casos como "cada 8h durante 1 semana" (medicación). Pasada la fecha, la tarea se mueve a una sección de Finalizadas
- **Categorías personalizables** — cada categoría con su color e icono, organizadas con secciones tipo iOS Notes
- **Widgets nativos**:
  - Home screen: small (1 tarea destacada), medium (4 tareas), large (8 tareas)
  - Lock Screen: circular (anillo nativo), rectangular (1 tarea), inline (texto)
  - Configurable por categoría y modo "solo críticas"
- **Botón ✓ interactivo** en el widget (iOS 17+ App Intents) para marcar como hecha sin abrir la app
- **Notificaciones locales** automáticas cuando una tarea entra en zona crítica (≤25% restante)
- **Undo de 1h** — si te equivocas marcando una tarea, banner flotante para deshacer
- **Sincronización iCloud** — tus tareas en todos tus dispositivos
- **Compartir con la familia** — comparte una categoría completa (ej. "Casa") vía CloudKit Sharing. La familia recibe un link de iCloud, lo aceptan y ven/editan las tareas

## Stack

- **Lenguaje:** Swift + SwiftUI
- **iOS:** 17.0+
- **Sync:** CloudKit + `CKSyncEngine` (iOS 17+)
- **Persistencia local:** UserDefaults vía App Group (compartido entre app y widget)
- **Notificaciones:** UserNotifications (locales)
- **Widget interactivo:** App Intents
- **Generador de proyecto:** XcodeGen

## Estructura

```
.
├── App/                          # Target principal (iOS app)
│   ├── TareasApp.swift           # Entry point
│   ├── ContentView.swift         # Lista principal con secciones por categoría
│   ├── TareaEditView.swift       # Crear/editar tarea
│   ├── CategoriesEditView.swift  # Gestionar categorías + compartir
│   ├── FinishedTasksView.swift   # Sheet de tareas finalizadas
│   ├── AppDelegate.swift         # Recibe URLs de CKShare
│   ├── Tendr.entitlements        # iCloud + App Group
│   ├── PrivacyInfo.xcprivacy     # Privacy manifest
│   └── Assets.xcassets/          # AppIcon
│
├── Widget/                       # Widget extension
│   ├── TareasWidget.swift        # AppIntentConfiguration + TimelineProvider
│   ├── TareasWidgetView.swift    # Vistas para cada tamaño
│   ├── TareasWidgetBundle.swift  # @main del widget bundle
│   ├── TendrWidget.entitlements
│   ├── PrivacyInfo.xcprivacy
│   └── Info.plist
│
├── Shared/                       # Compartido entre app y widget
│   ├── TaskModel.swift           # TareaItem, Frequency, TareasStore
│   ├── CategoryStyle.swift       # Color/icono por categoría + paleta
│   ├── CategoryIntent.swift      # Filtro de categoría en widget config
│   ├── CompleteTaskIntent.swift  # App Intent del botón ✓
│   ├── NotificationManager.swift # Notificaciones locales
│   ├── CloudSync.swift           # CKSyncEngine (privado + shared DB)
│   └── CKRecord+TareaItem.swift  # Codificación a CloudKit
│
├── project.yml                   # XcodeGen spec
├── mockup.html                   # Mockup HTML del concepto del widget
└── appicon.png                   # Icono original (1254×1254)
```

## Setup local

Requiere:
- macOS con Xcode 15+ (idealmente Xcode 16+ para iOS 17.5+)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`

Pasos:
```bash
git clone <este-repo>
cd tendr
xcodegen
open Tendr.xcodeproj
```

Selecciona iPhone simulator → ▶️. Compila sin firmar — el código está estructurado para funcionar en simulador sin Apple Developer account, con CloudKit deshabilitado de forma silenciosa.

## Setup para producción (Apple Developer)

Para que la sincronización iCloud funcione necesitas:

1. **Apple Developer Program** ($99/año)
2. En [developer.apple.com](https://developer.apple.com) → Certificates, IDs & Profiles:
   - Crear App ID `com.tendr.app` con capabilities **iCloud (CloudKit)** + **App Groups**
   - Crear App ID `com.tendr.app.widget` con las mismas capabilities
   - Crear App Group `group.com.tendr.app` (asociar a ambos App IDs)
   - Crear iCloud Container `iCloud.com.tendr.app` (asociar a ambos App IDs)
3. En Xcode → target Tendr → Signing & Capabilities:
   - Team = tu Apple ID
   - "Automatically manage signing"
4. Mismo en target TendrWidget
5. Tras la primera ejecución que envíe records: [CloudKit Console](https://icloud.developer.apple.com/) → tu container → "Deploy schema to Production"

## Antes de subir a App Store

- [ ] Privacy Policy URL pública (Gist o GitHub Pages)
- [ ] Schema deployed a Production en CloudKit Console
- [ ] TestFlight con 2-3 testers durante 1 semana
- [ ] Probar offline → online → offline
- [ ] Probar borrar la app y reinstalar
- [ ] Light mode revisado

## Tareas pendientes

- [ ] Pulir light mode
- [ ] VoiceOver en anillos
- [ ] Indicador visual de "sincronizando"
- [ ] Push notifications de CloudKit (sync sin abrir la app)
- [ ] Onboarding al primer arranque
- [ ] Snooze (posponer 1h) y "saltar este ciclo"
- [ ] Historial / streak por tarea

## Licencia

Proyecto personal. Todos los derechos reservados.
