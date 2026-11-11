# VW Up! TSI (Speed) — Telemetry & Diagnostics Dashboard 🏁

Aplicativo desktop multiplataforma (**Windows & macOS**) desenvolvido em **Electron** e **Node.js** para monitoramento em tempo real, datalogging e diagnóstico automotivo dedicado ao **Volkswagen Up! TSI 1.0 (Plataforma PQ12 / EA211)** através do seu adaptador Bluetooth OBD-II (ELM327).

---

## 🚀 Como Iniciar o Aplicativo

### No Windows:
* **Modo Real (Conectado ao Carro via OBD-II):**
  ```powershell
  npm start
  ```
  *(Ou dê um duplo clique no arquivo [`start-dashboard.bat`](file:///c:/source/up-tsi/start-dashboard.bat))*
* **Modo Mock (Dados Fictícios Locais):**
  ```powershell
  npm run mock
  ```
  *(Ou dê um duplo clique no arquivo [`start-mock.bat`](file:///c:/source/up-tsi/start-mock.bat))*

### No macOS (MacBook / Mac mini / iMac):
1. Abra o Terminal e execute:
   ```bash
   npm install
   npm start
   ```
2. Para rodar em modo Mock no Mac:
   ```bash
   npm run mock
   ```
3. Para gerar o instalador nativo do macOS (`.dmg` e `.zip` com `.app` universal):
   ```bash
   npm run build:mac
   ```
   *O instalador `.dmg` será gerado na pasta `dist/`.*

---

## 🎮 Controle Interativo no Modo Mock

No modo Mock, além do ciclo automático de puxada e troca de marcha:
* **Segure a Barra de Espaço ou a Seta para Cima (↑)** no teclado para acelerar o carro interativamente!
* O acelerador vai a 100%, o conta-giros sobe até 6.500 RPM, o manômetro atinge 1.25 bar de turbo e os LEDs do Shift Light acendem até o alerta de troca aos 5.800+ RPM!
* Ao soltar a tecla, a borboleta fecha e gera vácuo (-0.68 bar) no coletor de admissão.

---

## 🎛️ Principais Recursos Implementados

1. **Gauges Esportivos Animados:**
   * **Conta-giros (Tachometer):** 0 a 7.000 RPM com faixa vermelha aos 6.000 RPM.
   * **Shift Light Progressivo:** Barra de 8 LEDs (Verde -> Amarelo -> Vermelho -> Flash ciano aos 5.800+ RPM).
   * **Manômetro de Pressão de Turbo (Boost):** Escala de -1.0 bar (vácuo) até +2.0 bar (pressão positiva), com marcador de pico de pressão retido (*Peak Hold*) e leituras simultâneas em Bar e PSI.
   * **Velocímetro Digital:** Em km/h com estimador de marcha (N, 1ª, 2ª, 3ª, 4ª, 5ª) baseado nas relações do câmbio MQ200 do Up! TSI.

2. **Grade de Sensores e Telemetria em Tempo Real:**
   * **Coolant:** Temperatura do arrefecimento (°C) com alerta de superaquecimento (> 102°C).
   * **IAT (Intake Air Temperature):** Temperatura do ar de admissão para avaliar a eficiência do intercooler ar/água.
   * **MAP:** Pressão absoluta do coletor em kPa.
   * **TPS:** Abertura percentual da borboleta de aceleração (0 a 100%).
   * **Engine Load:** Carga do motor calculada pela ECU Bosch MED17.
   * **Avanço de Ignição:** Ponto de ignição em graus (° APMS).
   * **Ajustes de Combustível (STFT & LTFT):** Correções de curto e longo prazo de mistura (etanol/gasolina).
   * **Tensão da Bateria:** Voltagem em tempo real com indicador de alternador ativo.

3. **Diagnóstico DTC (Check Engine / Códigos de Falha):**
   * **Escanear Falhas (Modo 03):** Varre a ECU e decodifica falhas com banco de dados de códigos comuns do motor TSI (ex: P0299, P0234, P0300, etc.).
   * **Apagar Falhas (Modo 04):** Limpa registros de erro e apaga a luz espia da injeção.

4. **Datalogger Automático em CSV:**
   * Botão de gravação instantânea que salva amostras de alta frequência em `logs/datalog_up_tsi_<data>.csv` para análise em planilhas ou softwares de telemetria.

5. **Multiplataforma:**
   * Suporte nativo a Windows (com descoberta de portas COM virtuais RFCOMM) e macOS (com descoberta de `/dev/cu.*` e `/dev/tty.*` Bluetooth).
