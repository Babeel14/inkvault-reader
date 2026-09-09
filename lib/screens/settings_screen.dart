import 'package:flutter/material.dart';
import '../services/obsidian_link.dart';
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}
class _SettingsScreenState extends State<SettingsScreen> {
  final _folder = TextEditingController();
  final _vault = TextEditingController();
  String? _linked;
  bool _busy = true;
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    await _run(() async {
      final s = await ObsidianLink.settings();
      _folder.text = s['folder'] as String? ?? 'Baker Reader';
      _vault.text = s['vault'] as String? ?? '';
      _linked = s['uri'] as String?;
    });
  }
  Future<void> _run(Future<void> Function() action) async {
    if (mounted) setState(() => _busy = true);
    try { await action(); }
    catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo completar: $e'))); }
    finally { if (mounted) setState(() => _busy = false); }
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Ajustes · Baker Reader')),
    body: ListView(padding: const EdgeInsets.all(20), children: [
      const Icon(Icons.bakery_dining, size: 54), const SizedBox(height: 20),
      Text('Obsidian', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 8),
      const Text('Selecciona la carpeta local de tu vault de Obsidian. Android conservará el permiso para guardar notas e imágenes. No necesitas una cuenta.'),
      const SizedBox(height: 16),
      Text(_linked == null ? 'Sin vincular' : 'Carpeta vinculada', style: const TextStyle(fontWeight: FontWeight.bold)),
      if (_linked != null) Text(Uri.decodeFull(_linked!), maxLines: 3, overflow: TextOverflow.ellipsis),
      OutlinedButton.icon(onPressed: _busy ? null : () async { await _run(ObsidianLink.chooseFolder); await _load(); }, icon: const Icon(Icons.folder_open), label: Text(_linked == null ? 'Vincular carpeta de Obsidian' : 'Cambiar carpeta vinculada')),
      TextField(controller: _folder, decoration: const InputDecoration(labelText: 'Subcarpeta de destino', hintText: 'Lecturas/Baker Reader')),
      const SizedBox(height: 12),
      TextField(controller: _vault, decoration: const InputDecoration(labelText: 'Nombre del vault (opcional)', helperText: 'Para abrirlo directamente en Obsidian')),
      const SizedBox(height: 20),
      FilledButton(onPressed: _busy ? null : () => _run(() async {
        await ObsidianLink.configure(_folder.text.trim(), _vault.text.trim());
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ajustes guardados')));
      }), child: const Text('Guardar ajustes')),
      TextButton(onPressed: _busy || _linked == null ? null : () async { await _run(ObsidianLink.unlink); await _load(); }, child: const Text('Desvincular')),
      const SizedBox(height: 24),
      const Text('Las anotaciones se conservan en Baker Reader al cerrar y reabrir. Los documentos originales no se sobrescriben. En móvil activa el botón del dedo para dibujar sin lápiz.'),
    ]));
  @override
  void dispose() { _folder.dispose(); _vault.dispose(); super.dispose(); }
}
