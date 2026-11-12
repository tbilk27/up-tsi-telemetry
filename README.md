# VW Up! TSI (Speed) — Telemetry & Diagnostics Ecosystem 🏁

Ecossistema completo de telemetria em tempo real, datalogging e diagnóstico automotivo dedicado ao **Volkswagen Up! TSI 1.0 (Plataforma PQ12 / EA211)** através do adaptador Bluetooth OBD-II (ELM327).

---

## 📂 Estrutura do Repositório

* **`/` (Raiz):** Aplicativo Desktop Multiplataforma (**Windows & macOS**) em **Electron + Node.js**.
* **[`/mobile`](file:///c:/source/up-tsi/mobile):** Aplicativo Mobile Nativo (**Android & iOS**) em **Flutter** com conexão Bluetooth direta.

---

## 🖥️ 1. Aplicativo Desktop (Windows & macOS)

### Como rodar no Windows:
* **Modo Real (Conectado ao Carro):** Dê um duplo clique em [`start-dashboard.bat`](file:///c:/source/up-tsi/start-dashboard.bat) ou execute `npm start`.
* **Modo Mock (Dados Fictícios Locais):** Dê um duplo clique em [`start-mock.bat`](file:///c:/source/up-tsi/start-mock.bat) ou execute `npm run mock`.
  * *Controle Interativo:* Segure a **Barra de Espaço** ou a **Seta para Cima (↑)** no teclado para acelerar e encher a turbina interativamente!

### Como rodar no macOS:
```bash
npm install
npm start        # Modo real
npm run mock     # Modo mock
npm run build:mac # Gerar instalador nativo DMG na pasta dist/
```

---

## 📱 2. Aplicativo Mobile (Flutter)

O aplicativo mobile foi desenvolvido para você rodar direto no celular fixado no suporte do painel do Up! TSI.

### Recursos do App Mobile:
* **Conexão Bluetooth Direta:** Tela de escaneamento e conexão com o adaptador `OBDII` pareado no telefone.
* **Rotação Automática:** Otimizado para funcionar tanto em pé quanto deitado (modo painel de corrida).
* **Instrumentos Digitais:**
  * Conta-giros de alta precisão com **Shift Light** progressivo (8 LEDs).
  * Manômetro de Pressão de Turbo (-1.0 bar a +2.0 bar) com indicador de pico (*Peak Hold*).
  * Velocímetro com estimador de marcha (N, 1ª a 5ª) calibrado para o câmbio MQ200 do Up! TSI.
* **Diagnóstico DTC:** Varre a ECU Bosch MED17, exibe os códigos com descrições do TSI e permite apagar falhas (Modo 04).
* **Modo Simulação:** Permite testar todos os instrumentos na tela mesmo sem o carro por perto.

### Como compilar para o telefone:
Dentro da pasta `mobile/`:
```bash
# Para rodar direto no telefone conectado via USB:
flutter run

# Para gerar o arquivo APK instalável:
flutter build apk --release
```
*(Mais detalhes no [README do Mobile](file:///c:/source/up-tsi/mobile/README.md))*
