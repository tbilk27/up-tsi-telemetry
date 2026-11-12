# VW Up! TSI Telemetry — Mobile App (Flutter) 📱🏁

Aplicativo mobile em **Flutter** para monitoramento de telemetria em tempo real, manômetro de turbo com pico, conta-giros com Shift Light e diagnóstico de falhas (DTC) via Bluetooth direto do seu celular (Android / iOS).

---

## 📲 Como Transferir e Instalar no seu Celular

### Opção 1: Direto pelo Computador via USB (Desenvolvedor)
1. Conecte o seu celular Android no notebook via cabo USB.
2. No seu telefone:
   * Vá em **Configurações > Opções do Desenvolvedor** e ative a **Depuração USB**.
3. No terminal dentro da pasta `mobile/`:
   ```bash
   flutter pub get
   flutter run
   ```
   *O aplicativo será compilado e instalado diretamente no seu celular.*

### Opção 2: Gerar o arquivo APK Instalável
Se preferir gerar o arquivo `.apk` para instalar em qualquer Android:
```bash
flutter build apk --release
```
*O instalador APK será gerado em: `build/app/outputs/flutter-apk/app-release.apk`.*  
Basta transferir esse arquivo para o celular (via WhatsApp, Google Drive ou cabo) e tocar para instalar.

---

## 🔌 Como Conectar ao Adaptador Bluetooth no Carro

1. Plugue o adaptador OBD-II na tomada de diagnóstico do seu Up! TSI (fica abaixo do volante, próximo aos fusíveis).
2. Ligue a chave de ignição do carro.
3. No celular, vá em **Configurações > Bluetooth** e procure por **"OBDII"** (ou o nome do seu adaptador).
4. Pareie o dispositivo (a senha padrão costuma ser `1234` ou `0000`).
5. Abra o aplicativo **Up! TSI Telemetry**:
   * Toque na pílula de status no canto superior direito (**CONECTAR**).
   * O aplicativo listará os dispositivos pareados destacando a tag **OBDII**.
   * Toque em **Conectar**.

---

## 🎮 Modo Simulação (Sem Carro)
* Na tela de conexão Bluetooth, você também pode tocar em **"Ativar Modo Simulação (Testar Sem Carro)"** para ver os mostradores acelerando, as trocas de marcha e a subida de pressão de turbo mesmo fora do veículo.

---

## 🏎️ Recursos do App Mobile
* **Orientação Horizontal e Vertical:** O painel se ajusta automaticamente para quando o celular estiver colocado no suporte de painel ou parabrisa.
* **Tachometer com Shift Light:** 8 LEDs de aviso progressivo com flash ciano acima de 5.800 RPM.
* **Manômetro de Turbo com Peak Hold:** Mostrador com vácuo (-1.0 bar) a pressão positiva (+2.0 bar) e indicador de pico de pressão retido.
* **Velocímetro & Indicador de Marcha:** Mostra a marcha estimada (N, 1ª a 5ª) baseado na relação de transmissão do Up! TSI.
* **Diagnóstico de Falhas (DTC):** Varredura e limpeza da luz da injeção com dicionário de códigos do motor TSI (EA211).
