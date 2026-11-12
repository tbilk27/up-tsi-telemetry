# VW Up! TSI Telemetry — Mobile App (Flutter) 📱🏁

Aplicativo mobile em **Flutter** para monitoramento de telemetria em tempo real, manômetro de turbo com pico, conta-giros com Shift Light e diagnóstico de falhas (DTC) via Bluetooth direto do seu celular (Android / iOS).

---

## 🏎️ Navegação por Gesto de Arraste (Swipe)

O aplicativo possui navegação horizontal nativa entre duas páginas:

* **Página 1 (Painel de Telemetria):**
  * Conta-giros esportivo (0-7.000 RPM) com **Shift Light progressivo** (8 LEDs).
  * Manômetro de Pressão de Turbo (-1.0 bar a +2.0 bar) com indicador de pico (*Peak Hold*).
  * Velocímetro em km/h com estimador de marcha (N, 1ª a 5ª).
  * 8 cards de telemetria dos sensores com barras dinâmicas.
* **Página 2 (Alertas, Mensagens e Erros da Injeção) — *Ao arrastar para o lado*:**
  * **Alertas Críticos em Tempo Real:** Monitora se o motor está superaquecendo (> 102°C), se o ar de admissão está saturado (> 55°C), mistura fora de faixa (STFT/LTFT) ou tensão de bateria anormal.
  * **Status da Luz de Injeção (MIL):** Indica se a lâmpada de anomalia da central Bosch MED17 está acesa ou apagada.
  * **Códigos de Falha da Injeção (DTCs):** Lista as falhas ativas com descrições automáticas para a linha TSI EA211.
  * **Botão Destacado: "Apagar Erros (MIL)":** Envia o comando Modo 04 via OBD-II para zerar a memória da central e apagar a luz da injeção no painel.

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
