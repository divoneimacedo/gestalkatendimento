# Gestalk Flutter Desktop - começo da aplicação

Base inicial criada a partir da análise do projeto `front` enviado.

## O que já vem pronto

- Estrutura Flutter para Windows/macOS/Linux.
- Login com armazenamento de token.
- Cliente HTTP com header `Authorization` e `X-Company-Slug`.
- Tela de fila baseada na tela React `src/app/[slug]/queue/page.tsx`.
- Polling da fila a cada 15 segundos.
- Ações de atender e cancelar chamada.
- Serviço de notificação nativa.
- Serviço de som contínuo para nova chamada/fila com atendimento pendente.
- Serviço de Tray para ícone próximo ao relógio no Windows.
- Tela placeholder para a chamada de vídeo com pontos de integração do VideoSDK Flutter.

## Como rodar

```bash
flutter pub get
flutter run -d windows
```

Para Linux/macOS:

```bash
flutter run -d linux
flutter run -d macos
```

## Configuração da API

Edite:

```dart
lib/core/app_config.dart
```

Defina `baseUrl`, `defaultSlug` e, se for usar token gerado pelo backend para VideoSDK, `videoSdkTokenEndpoint`.

## Observações importantes

O projeto React enviado usa `@videosdk.live/react-sdk`. Para Flutter, a documentação atual da VideoSDK informa compatibilidade com Android/iOS, Web beta e Desktop beta. Por isso, eu deixei a tela de chamada isolada para vocês testarem primeiro câmera, microfone, entrada na sala e compartilhamento de tela no Windows.

O pacote `videosdk` pode exigir ajustes conforme a versão disponível no pub.dev no momento do `flutter pub get`. Caso alguma API mude, a estrutura do projeto continua válida: a adaptação fica concentrada em `lib/screens/call_screen.dart`.

## Próximos passos sugeridos

1. Configurar URLs reais da API.
2. Ajustar contrato do login conforme backend.
3. Colocar o arquivo de som em `assets/sounds/call_alert.mp3`.
4. Colocar o ícone do tray em `assets/icons/tray.ico` para Windows.
5. Implementar a entrada real na sala VideoSDK.
6. Criar instalador com `msix`, Inno Setup ou `flutter_distributor`.
