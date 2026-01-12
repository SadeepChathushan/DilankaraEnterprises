// lib/pages/edit_delivery/EditDeliveryPage.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:printing/printing.dart';
import 'package:file_saver/file_saver.dart';
import 'package:open_filex/open_filex.dart';

import '../../core/models.dart';
import '../../core/repository.dart';
import '../../services/pdf_export.dart';
import '../../services/localization_service.dart';

class EditDeliveryPage extends StatefulWidget {
  const EditDeliveryPage({super.key, required this.deliveryId});
  final String deliveryId;

  @override
  State<EditDeliveryPage> createState() => _EditDeliveryPageState();
}

class _EditDeliveryPageState extends State<EditDeliveryPage> {
  final _repo = Repository.instance;
  Delivery? _delivery;

  List<WoodGroup> _groups = [];

  final _lorryController = TextEditingController();
  final _lenCtl = TextEditingController();
  final _widthCtl = TextEditingController();

  final FocusNode _lenFocus = FocusNode();
  final FocusNode _widthFocus = FocusNode();

  final List<(double, double, double)> _history = [];

  static const List<String> _kThicknessOptions = <String>[
    '1/8',
    '3/4',
    '1',
    '1 1/8',
    '1 1/4',
    '1 3/4',
    '1.5',
    '1 3/8',
    '2',
  ];
  String _selectedThicknessStr = _kThicknessOptions.first;

  String _currentLanguage = 'en';

  // Color scheme
  static const Color _primaryOrange = Color(0xFFE87A0D); // rgb(232,122,13)
  static const Color _darkBackground = Color(0xFF121212);
  static const Color _cardBackground = Color(0xFF1E1E1E);
  static const Color _inputBackground = Color(0xFF2A2A2A);

  @override
  void initState() {
    super.initState();
    _load();
    _loadLanguagePreference();
  }

  @override
  void dispose() {
    _lorryController.dispose();
    _lenCtl.dispose();
    _widthCtl.dispose();
    _lenFocus.dispose();
    _widthFocus.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final deliveries = await _repo.getDeliveries();
    _delivery = deliveries.firstWhere((d) => d.id == widget.deliveryId);
    _lorryController.text = _delivery!.lorryName;
    _groups = await _repo.getGroups(widget.deliveryId);
    if (mounted) setState(() {});
  }

  Future<void> _loadLanguagePreference() async {
    final savedLanguage = await LocalizationService.getSavedLanguage();
    setState(() {
      _currentLanguage = savedLanguage;
    });
  }

  Future<void> _saveHeader() async {
    if (_delivery == null) return;
    final name = _lorryController.text.trim();
    await _repo.updateDelivery(id: _delivery!.id, lorryName: name);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_t('Saved', 'සුරකින ලදී')),
        backgroundColor: _primaryOrange,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _t(String english, [String? sinhala]) {
    if (_currentLanguage == 'si' && sinhala != null) {
      return sinhala;
    }
    return english;
  }

  String _fmt(num n) => (n % 1 == 0) ? n.toInt().toString() : n.toString();

  double? _parseNumberOrFraction(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return null;

    if (s.contains(' ')) {
      final parts = s.split(RegExp(r'\s+'));
      if (parts.length != 2) return null;
      final whole = double.tryParse(parts[0]);
      final frac = _parseSimpleFraction(parts[1]);
      if (whole == null || frac == null) return null;
      return whole + frac;
    }

    if (s.contains('/')) {
      return _parseSimpleFraction(s);
    }

    return double.tryParse(s);
  }

  double? _parseSimpleFraction(String s) {
    final p = s.split('/');
    if (p.length != 2) return null;
    final a = double.tryParse(p[0].trim());
    final b = double.tryParse(p[1].trim());
    if (a == null || b == null || b == 0) return null;
    return a / b;
  }

  Future<String> _ensureGroupId(double t, double l) async {
    final existing = _groups.where((g) => g.thickness == t && g.length == l);
    if (existing.isNotEmpty) return existing.first.id;
    final gid = await _repo.addGroup(deliveryId: widget.deliveryId, thickness: t, length: l);
    _groups = await _repo.getGroups(widget.deliveryId);
    return gid;
  }

  Future<void> _addEntry() async {
    final t = _parseNumberOrFraction(_selectedThicknessStr);
    final l = double.tryParse(_lenCtl.text.trim());
    final w = double.tryParse(_widthCtl.text.trim());

    if (t == null || l == null || w == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_t('Enter valid numbers for thickness, length, width',
              'වලංගු ඝනකම, දිග සහ පළල ඇතුලත් කරන්න')),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final gid = await _ensureGroupId(t, l);
    await _repo.addWidths(gid, [w]);

    setState(() {
      _history.insert(0, (t, l, w));
      if (_history.length > 3) _history.removeRange(3, _history.length);
      _lenCtl.clear();
      _widthCtl.clear();
    });

    _lenFocus.requestFocus();
  }

  void _removeHistoryAt(int i) {
    setState(() {
      _history.removeAt(i);
    });
  }

  Future<void> _showSubmitConfirmation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          _t('Confirm Submission', 'ඉදිරිපත් කිරීම තහවුරු කරන්න'),
          style: const TextStyle(color: _primaryOrange, fontWeight: FontWeight.bold),
        ),
        content: Text(
          _t('Are you sure you want to submit to backend?',
              'ඔබට ඇත්තටම බැක්එන්ඩ් වෙත ඉදිරිපත් කිරීමට අවශ්‍යද?'),
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(_t('No', 'නැහැ'), style: const TextStyle(color: Colors.white70)),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: _primaryOrange),
            child: Text(_t('Yes', 'ඔව්'), style: const TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _submitAll();
    }
  }

  Future<void> _submitAll() async {
    if (_history.isEmpty) return;
    setState(() => _history.clear());
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_t('Submitted to backend', 'බැක්එන්ඩ් වෙත ඉදිරිපත් කරන ලදී')),
        backgroundColor: _primaryOrange,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<String> _generatePdf() async {
    final path = await DeliveryPdfService.instance
        .exportDeliveryPdf(widget.deliveryId, shopHeader: 'Shop Header');
    return path;
  }

  Future<void> _exportPdf() async {
    try {
      final path = await _generatePdf();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_t('PDF saved (app storage): $path',
              'PDF ගබඩා කර ඇත (යෙදුම් ගබඩාව): $path')),
          backgroundColor: _primaryOrange,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_t('PDF export failed: $e', 'PDF නිර්යාතය අසාර්ථක විය: $e')),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _sharePdf() async {
    try {
      final path = await _generatePdf();
      final bytes = await File(path).readAsBytes();
      await Printing.sharePdf(bytes: bytes, filename: p.basename(path));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_t('Share failed: $e', 'හුවමාරුව අසාර්ථක විය: $e')),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _saveToDevice() async {
    try {
      final path = await _generatePdf();
      final bytes = await File(path).readAsBytes();

      final savedUri = await FileSaver.instance.saveFile(
        name: p.basenameWithoutExtension(path),
        bytes: bytes,
        ext: 'pdf',
        mimeType: MimeType.pdf,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_t('Saved to: $savedUri', 'ගබඩා කළ ස්ථානය: $savedUri')),
          backgroundColor: _primaryOrange,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_t('Save failed: $e', 'ගබඩා කිරීම අසාර්ථක විය: $e')),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _openPdf() async {
    try {
      final path = await _generatePdf();
      await OpenFilex.open(path);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_t('Open failed: $e', 'විවෘත කිරීම අසාර්ථක විය: $e')),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showPdfMenu(Offset? position) async {
    final selected = await showMenu<String>(
      context: context,
      color: _cardBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      position: RelativeRect.fromLTRB(
        position?.dx ?? MediaQuery.of(context).size.width,
        position?.dy ?? kToolbarHeight,
        0,
        0,
      ),
      items: [
        PopupMenuItem(
          value: 'generate',
          child: Row(
            children: [
              const Icon(Icons.save_alt, color: _primaryOrange, size: 20),
              const SizedBox(width: 12),
              Text(
                _t('Generate (app storage)', 'ජනනය කරන්න (යෙදුම් ගබඩාව)'),
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'share',
          child: Row(
            children: [
              const Icon(Icons.share, color: _primaryOrange, size: 20),
              const SizedBox(width: 12),
              Text(
                _t('Share PDF', 'PDF හුවමාරු කරන්න'),
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'save',
          child: Row(
            children: [
              const Icon(Icons.download, color: _primaryOrange, size: 20),
              const SizedBox(width: 12),
              Text(
                _t('Save to device…', 'උපාංගයේ ගබඩා කරන්න…'),
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'open',
          child: Row(
            children: [
              const Icon(Icons.open_in_new, color: _primaryOrange, size: 20),
              const SizedBox(width: 12),
              Text(
                _t('Open PDF', 'PDF විවෘත කරන්න'),
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
      ],
    );

    switch (selected) {
      case 'generate':
        await _exportPdf();
        break;
      case 'share':
        await _sharePdf();
        break;
      case 'save':
        await _saveToDevice();
        break;
      case 'open':
        await _openPdf();
        break;
    }
  }

  Future<void> _toggleLanguage() async {
    final newLanguage = _currentLanguage == 'en' ? 'si' : 'en';
    await LocalizationService.saveLanguage(newLanguage);
    setState(() {
      _currentLanguage = newLanguage;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_delivery == null) {
      return Scaffold(
        backgroundColor: _darkBackground,
        appBar: AppBar(
          backgroundColor: Colors.black,
          elevation: 0,
          title: Text(
            _t('Edit Delivery', 'භාරදීම සංස්කරණය කරන්න'),
            style: const TextStyle(color: _primaryOrange, fontWeight: FontWeight.bold),
          ),
          iconTheme: const IconThemeData(color: _primaryOrange),
        ),
        body: const Center(
          child: CircularProgressIndicator(color: _primaryOrange),
        ),
      );
    }
    final date = DateFormat('yyyy-MM-dd HH:mm').format(_delivery!.date.toLocal());

    return Scaffold(
      backgroundColor: _darkBackground,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 4,
        shadowColor: _primaryOrange.withOpacity(0.3),
        title: Text(
          _t('Edit Delivery', 'භාරදීම සංස්කරණය කරන්න'),
          style: const TextStyle(
            color: _primaryOrange,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        iconTheme: const IconThemeData(color: _primaryOrange),
        actions: [
          // Language toggle button
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: _cardBackground,
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              icon: Icon(
                _currentLanguage == 'en' ? Icons.language : Icons.translate,
                color: _primaryOrange,
              ),
              onPressed: _toggleLanguage,
              tooltip: _t('Change Language', 'භාෂාව වෙනස් කරන්න'),
            ),
          ),
          // PDF menu
          Container(
            margin: const EdgeInsets.only(left: 4, right: 8),
            decoration: BoxDecoration(
              color: _cardBackground,
              borderRadius: BorderRadius.circular(8),
            ),
            child: PopupMenuButton<String>(
              tooltip: _t('PDF Actions', 'PDF ක්‍රියාමාර්ග'),
              icon: const Icon(Icons.picture_as_pdf, color: _primaryOrange),
              color: _cardBackground,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onSelected: (v) async {
                switch (v) {
                  case 'generate':
                    await _exportPdf();
                    break;
                  case 'share':
                    await _sharePdf();
                    break;
                  case 'save':
                    await _saveToDevice();
                    break;
                  case 'open':
                    await _openPdf();
                    break;
                }
              },
              itemBuilder: (ctx) => [
                PopupMenuItem(
                  value: 'generate',
                  child: Row(
                    children: [
                      const Icon(Icons.save_alt, color: _primaryOrange, size: 20),
                      const SizedBox(width: 12),
                      Text(
                        _t('Generate (app storage)', 'ජනනය කරන්න (යෙදුම් ගබඩාව)'),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'share',
                  child: Row(
                    children: [
                      const Icon(Icons.share, color: _primaryOrange, size: 20),
                      const SizedBox(width: 12),
                      Text(
                        _t('Share PDF', 'PDF හුවමාරු කරන්න'),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'save',
                  child: Row(
                    children: [
                      const Icon(Icons.download, color: _primaryOrange, size: 20),
                      const SizedBox(width: 12),
                      Text(
                        _t('Save to device…', 'උපාංගයේ ගබඩා කරන්න…'),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'open',
                  child: Row(
                    children: [
                      const Icon(Icons.open_in_new, color: _primaryOrange, size: 20),
                      const SizedBox(width: 12),
                      Text(
                        _t('Open PDF', 'PDF විවෘත කරන්න'),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header Card
          Container(
            decoration: BoxDecoration(
              color: _cardBackground,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _primaryOrange.withOpacity(0.3), width: 1),
              boxShadow: [
                BoxShadow(
                  color: _primaryOrange.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.local_shipping, color: _primaryOrange, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      _t('Delivery Information', 'භාරදීම් තොරතුරු'),
                      style: const TextStyle(
                        color: _primaryOrange,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _lorryController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: _t('Lorry name', 'ලොරි නම'),
                    labelStyle: TextStyle(color: _primaryOrange.withOpacity(0.7)),
                    filled: true,
                    fillColor: _inputBackground,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: _primaryOrange.withOpacity(0.3)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _primaryOrange, width: 2),
                    ),
                    prefixIcon: const Icon(Icons.drive_eta, color: _primaryOrange),
                  ),
                  onSubmitted: (_) => _saveHeader(),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.calendar_today, color: _primaryOrange, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      '${_t('Date', 'දිනය')}: $date',
                      style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14),
                    ),
                    const Spacer(),
                    ElevatedButton.icon(
                      onPressed: _saveHeader,
                      icon: const Icon(Icons.save, size: 18),
                      label: Text(_t('Save', 'සුරකින්න')),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryOrange,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Main Entry Card
          Container(
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _primaryOrange, width: 2),
              boxShadow: [
                BoxShadow(
                  color: _primaryOrange.withOpacity(0.2),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // History Box
                Container(
                  height: 220,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: _inputBackground,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _primaryOrange, width: 2),
                  ),
                  child: _history.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.history, color: _primaryOrange.withOpacity(0.5), size: 48),
                              const SizedBox(height: 8),
                              Text(
                                _t('History last 3 (empty)', 'අවසන් 3 (හිස්)'),
                                style: TextStyle(
                                  color: _primaryOrange.withOpacity(0.7),
                                  fontWeight: FontWeight.w500,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(8),
                          itemCount: _history.length,
                          separatorBuilder: (_, __) => Divider(
                            height: 1,
                            color: _primaryOrange.withOpacity(0.3),
                          ),
                          itemBuilder: (ctx, i) {
                            final e = _history[i];
                            return Container(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: _cardBackground,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: _primaryOrange.withOpacity(0.3)),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'x=${_fmt(e.$1)}   y=${_fmt(e.$2)}   z=${_fmt(e.$3)}',
                                      style: const TextStyle(
                                        color: _primaryOrange,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close, color: Colors.redAccent),
                                    onPressed: () => _removeHistoryAt(i),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),

                const SizedBox(height: 20),

                // Thickness Dropdown
                DropdownButtonFormField<String>(
                  value: _selectedThicknessStr,
                  decoration: InputDecoration(
                    labelText: _t('thickness (trenches)', 'ඝනකම (ට්‍රෙන්ච්)'),
                    filled: true,
                    fillColor: _inputBackground,
                    labelStyle: const TextStyle(color: _primaryOrange, fontWeight: FontWeight.w500),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: _primaryOrange.withOpacity(0.5), width: 1.5),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _primaryOrange, width: 2),
                    ),
                    prefixIcon: const Icon(Icons.straighten, color: _primaryOrange),
                  ),
                  dropdownColor: _cardBackground,
                  style: const TextStyle(color: _primaryOrange, fontSize: 16, fontWeight: FontWeight.bold),
                  icon: const Icon(Icons.arrow_drop_down, color: _primaryOrange),
                  items: _kThicknessOptions
                      .map((s) => DropdownMenuItem(
                            value: s,
                            child: Text(s),
                          ))
                      .toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _selectedThicknessStr = v);
                  },
                ),

                const SizedBox(height: 16),

                // Length + Width Row
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _lenCtl,
                        focusNode: _lenFocus,
                        style: const TextStyle(color: _primaryOrange, fontSize: 16, fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                          labelText: _t('length (ft)', 'දිග (අඩි)'),
                          filled: true,
                          fillColor: _inputBackground,
                          labelStyle: const TextStyle(color: _primaryOrange, fontWeight: FontWeight.w500),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: _primaryOrange.withOpacity(0.5), width: 1.5),
                          ),
                          focusedBorder:  OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: _primaryOrange, width: 2),
                          ),
                          prefixIcon: const Icon(Icons.height, color: _primaryOrange),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        textInputAction: TextInputAction.next,
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9\.]'))],
                        onSubmitted: (_) => _widthFocus.requestFocus(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _widthCtl,
                        focusNode: _widthFocus,
                        style: const TextStyle(color: _primaryOrange, fontSize: 16, fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                          labelText: _t('width (trenches)', 'පළල (ට්‍රෙන්ච්)'),
                          filled: true,
                          fillColor: _inputBackground,
                          labelStyle: const TextStyle(color: _primaryOrange, fontWeight: FontWeight.w500),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: _primaryOrange.withOpacity(0.5), width: 1.5),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: _primaryOrange, width: 2),
                          ),
                          prefixIcon: const Icon(Icons.width_full, color: _primaryOrange),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        textInputAction: TextInputAction.done,
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9\.]'))],
                        onSubmitted: (_) async {
                          await _addEntry();
                          _lenFocus.requestFocus();
                        },
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Buttons Row: Enter, Submit, PDF
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _addEntry,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryOrange,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          _t('Enter (save)', 'ඇතුලත් කරන්න (සුරකින්න)'),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _history.isEmpty ? null : _showSubmitConfirmation,
                        icon: const Icon(Icons.cloud_upload, color: Colors.black),
                        label: Text(
                          _t('Submit', 'ඉදිරිපත් කරන්න'),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _history.isEmpty ? Colors.grey.shade800 : _primaryOrange,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    InkResponse(
                      onTapDown: (d) => _showPdfMenu(d.globalPosition),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _cardBackground,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _primaryOrange, width: 2),
                        ),
                        child: const Icon(Icons.picture_as_pdf, color: _primaryOrange, size: 28),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
