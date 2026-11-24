import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/obd_bluetooth_service.dart';

class ObdTerminalScreen extends StatefulWidget {
  const ObdTerminalScreen({Key? key}) : super(key: key);

  @override
  State<ObdTerminalScreen> createState() => _ObdTerminalScreenState();
}

class _ObdTerminalScreenState extends State<ObdTerminalScreen> {
  final TextEditingController _cmdController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _autoScroll = true;
  String _lastManualResponse = '';
  bool _isSending = false;

  @override
  void dispose() {
    _cmdController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_autoScroll && _scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _sendManual(ObdBluetoothService obd, String cmd) async {
    if (cmd.trim().isEmpty) return;
    setState(() => _isSending = true);
    final resp = await obd.sendManualCommand(cmd.trim().toUpperCase());
    if (mounted) {
      setState(() {
        _lastManualResponse = resp.trim();
        _isSending = false;
      });
      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    final obd = Provider.of<ObdBluetoothService>(context);
    final logs = obd.logs;

    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    return Scaffold(
      backgroundColor: const Color(0xFF0A0D14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121722),
        elevation: 0,
        title: const Text(
          'TERMINAL & LOGS OBDII',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        actions: [
          // Copiar Logs
          IconButton(
            tooltip: 'Copiar Logs para Área de Transferência',
            icon: const Icon(Icons.copy, size: 20),
            onPressed: logs.isEmpty
                ? null
                : () async {
                    final text = obd.exportLogsAsText();
                    await Clipboard.setData(ClipboardData(text: text));
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          backgroundColor: Color(0xFF00E676),
                          content: Text('Logs copiados para a área de transferência!'),
                        ),
                      );
                    }
                  },
          ),
          // Salvar em Arquivo
          IconButton(
            tooltip: 'Salvar Arquivo de Log no Telefone',
            icon: const Icon(Icons.save_alt, size: 20),
            onPressed: logs.isEmpty
                ? null
                : () async {
                    final path = await obd.saveLogToFile();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: path != null
                              ? const Color(0xFF00E676)
                              : const Color(0xFFFF5252),
                          content: Text(path != null
                              ? 'Salvo em: $path'
                              : 'Erro ao salvar arquivo de log.'),
                        ),
                      );
                    }
                  },
          ),
          // Limpar Logs
          IconButton(
            tooltip: 'Limpar Logs',
            icon: const Icon(Icons.delete_sweep, size: 20),
            onPressed: logs.isEmpty ? null : () => obd.clearLogs(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Header Status Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFF161F2E),
              border: Border(bottom: BorderSide(color: Color(0xFF242E42))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: obd.isConnected
                            ? const Color(0xFF00E676)
                            : const Color(0xFFFF5252),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      obd.isConnected ? 'CONECTADO' : 'DESCONECTADO',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: obd.isConnected
                            ? const Color(0xFF00E676)
                            : const Color(0xFFFF5252),
                      ),
                    ),
                  ],
                ),
                Text(
                  'Transações: ${logs.length}',
                  style: const TextStyle(fontSize: 10, color: Color(0xFF8B9BB4)),
                ),
                Text(
                  'Latência Média: ${obd.avgLatencyMs.toStringAsFixed(1)} ms',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF00E5FF),
                  ),
                ),
              ],
            ),
          ),

          if (obd.activeLogFilePath != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              color: const Color(0xFF101826),
              child: Text(
                'Auto-Log Bruto: ${obd.activeLogFilePath}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 9.5,
                  color: Color(0xFF00E676),
                ),
              ),
            ),

          // Quick Command Test Chips
          Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            color: const Color(0xFF0E131D),
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildQuickChip(obd, '010C', 'RPM'),
                _buildQuickChip(obd, '010B', 'MAP/Turbo'),
                _buildQuickChip(obd, '010D', 'Velocidade'),
                _buildQuickChip(obd, '0111', 'Borboleta'),
                _buildQuickChip(obd, '0133', 'Barômetro'),
                _buildQuickChip(obd, '0100', 'PIDs Suportados'),
                _buildQuickChip(obd, 'ATDP', 'Protocolo'),
                _buildQuickChip(obd, 'ATRV', 'Tensão'),
              ],
            ),
          ),

          // Last Manual Response Box
          if (_lastManualResponse.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              color: const Color(0xFF1E283B),
              child: Text(
                'Última Resposta: $_lastManualResponse',
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFFFD600),
                ),
              ),
            ),

          // Logs Console List
          Expanded(
            child: logs.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.terminal, size: 40, color: Color(0xFF344563)),
                        SizedBox(height: 10),
                        Text(
                          'Aguardando comunicação OBDII...',
                          style: TextStyle(color: Color(0xFF7387A8), fontSize: 13),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Conecte ao adaptador ou toque em um chip de comando acima.',
                          style: TextStyle(color: Color(0xFF4A5A75), fontSize: 11),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.all(8),
                    itemCount: logs.length,
                    itemBuilder: (context, index) {
                      final item = logs[index];
                      final isErr = !item.success;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 4),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isErr
                              ? const Color(0xFF261014)
                              : const Color(0xFF0F1522),
                          borderRadius: BorderRadius.circular(4),
                          border: Border(
                            left: BorderSide(
                              color: isErr
                                  ? const Color(0xFFFF5252)
                                  : const Color(0xFF00E676),
                              width: 3,
                            ),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.timeFormatted,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 10,
                                color: Color(0xFF637694),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E283B),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: Text(
                                item.command,
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF00E5FF),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                item.rawResponse.replaceAll('\r', ' ').replaceAll('\n', ' ').trim(),
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 11,
                                  color: isErr
                                      ? const Color(0xFFFF8A80)
                                      : Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${item.latencyMs}ms',
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 9,
                                color: item.latencyMs > 250
                                    ? const Color(0xFFFF9100)
                                    : const Color(0xFF5A739B),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),

          // Manual Input Bar
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Color(0xFF121722),
              border: Border(top: BorderSide(color: Color(0xFF242E42))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _cmdController,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      color: Colors.white,
                      fontSize: 13,
                    ),
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      hintText: 'Digite um comando (ex: 010B, ATDP, 0100)...',
                      hintStyle: const TextStyle(color: Color(0xFF5A739B), fontSize: 11),
                      filled: true,
                      fillColor: const Color(0xFF0A0D14),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFF242E42)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFF242E42)),
                      ),
                    ),
                    onSubmitted: (val) => _sendManual(obd, val),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: _isSending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFFE51A24),
                          ),
                        )
                      : const Icon(Icons.send, color: Color(0xFF0070F3)),
                  onPressed: _isSending ? null : () => _sendManual(obd, _cmdController.text),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickChip(ObdBluetoothService obd, String cmd, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
      child: ActionChip(
        backgroundColor: const Color(0xFF182233),
        side: const BorderSide(color: Color(0xFF28364F)),
        padding: const EdgeInsets.symmetric(horizontal: 6),
        label: Text(
          '$cmd ($label)',
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 10,
            color: Color(0xFFC0CDE0),
          ),
        ),
        onPressed: _isSending ? null : () => _sendManual(obd, cmd),
      ),
    );
  }
}
