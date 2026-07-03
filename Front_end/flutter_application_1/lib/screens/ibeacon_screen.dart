import 'package:flutter/material.dart';

import '../models/ibeacon.dart';
import '../services/beacon_scan_service.dart';
import '../services/marketplace_service.dart';
import '../theme/app_colors.dart';

class IBeaconScreen extends StatefulWidget {
  const IBeaconScreen({super.key});

  @override
  State<IBeaconScreen> createState() => _IBeaconScreenState();
}

class _IBeaconScreenState extends State<IBeaconScreen> {
  final _service = MarketplaceService();
  final _rssiController = TextEditingController(text: '-70');

  IBeacon? _ibeacon;
  bool _loading = true;
  bool _saving = false;
  bool _scanning = false;
  bool _activite = true;

  String? _selectedUuid;
  int? _selectedMajor;
  int? _selectedMinor;

  bool get _hasBeaconSelection =>
      _selectedUuid != null && _selectedMajor != null && _selectedMinor != null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _rssiController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final ibeacon = await _service.getMonIBeacon();
      if (!mounted) return;
      if (ibeacon != null) {
        _selectedUuid = ibeacon.uuid;
        _selectedMajor = ibeacon.major;
        _selectedMinor = ibeacon.minor;
        _rssiController.text = ibeacon.rssiSeuil.toString();
        _activite = ibeacon.activite;
      }
      setState(() {
        _ibeacon = ibeacon;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Future<void> _scanBleDevices() async {
    setState(() => _scanning = true);
    try {
      final beacons = await BeaconScanService.scanNearbyBeacons();
      if (!mounted) return;

      if (beacons.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Aucun iBeacon détecté. Vérifiez que le beacon est allumé et proche (2 m).',
            ),
          ),
        );
        return;
      }

      final picked = await _showBeaconPicker(beacons);
      if (picked == null || !mounted) return;

      setState(() {
        _selectedUuid = picked.uuid;
        _selectedMajor = picked.major;
        _selectedMinor = picked.minor;
        _rssiController.text = picked.rssi.toString();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('iBeacon sélectionné. Enregistrez pour le lier à votre stand.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<ScannedBeaconInfo?> _showBeaconPicker(
    List<ScannedBeaconInfo> beacons,
  ) {
    return showModalBottomSheet<ScannedBeaconInfo>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.lightGrey,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Sélectionnez votre iBeacon',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: AppColors.darkOlive,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Choisissez le beacon branché sur votre stand.',
                  style: TextStyle(
                    color: AppColors.textGrey.withValues(alpha: 0.85),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: beacons.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final beacon = beacons[index];
                      return Material(
                        color: AppColors.lightGrey.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(14),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => Navigator.pop(context, beacon),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.bluetooth,
                                  color: AppColors.oliveGreen,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Major ${beacon.major} · Minor ${beacon.minor}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.darkOlive,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        beacon.uuid,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textGrey
                                              .withValues(alpha: 0.85),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '${beacon.rssi} dBm',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.oliveGreen,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _save() async {
    final uuid = _selectedUuid?.trim();
    final major = _selectedMajor;
    final minor = _selectedMinor;
    final rssi = int.tryParse(_rssiController.text.trim()) ?? -70;

    if (uuid == null || uuid.isEmpty || major == null || minor == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Scannez et sélectionnez d\'abord votre iBeacon'),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      if (_ibeacon == null) {
        final created = await _service.creerIBeacon(
          uuid: uuid,
          major: major,
          minor: minor,
          rssiSeuil: rssi,
          activite: _activite,
        );
        if (!mounted) return;
        setState(() {
          _ibeacon = created;
          _saving = false;
        });
      } else {
        final updated = await _service.modifierIBeacon(
          id: _ibeacon!.id,
          uuid: uuid,
          major: major,
          minor: minor,
          rssiSeuil: rssi,
          activite: _activite,
        );
        if (!mounted) return;
        setState(() {
          _ibeacon = updated;
          _saving = false;
        });
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('iBeacon enregistré')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Future<void> _delete() async {
    if (_ibeacon == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer l\'iBeacon ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await _service.supprimerIBeacon(_ibeacon!.id);
      if (!mounted) return;
      setState(() {
        _ibeacon = null;
        _selectedUuid = null;
        _selectedMajor = null;
        _selectedMinor = null;
        _rssiController.text = '-70';
        _activite = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('iBeacon supprimé')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFE8F0E0),
              AppColors.cream,
              AppColors.cream,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(),
              Expanded(
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.oliveGreen,
                        ),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                        child: Column(
                          children: [
                            _buildHeader(),
                            const SizedBox(height: 24),
                            _buildStepCard(
                              step: 1,
                              title: 'Préparation',
                              child: Column(
                                children: [
                                  _checkItem(
                                    'Branchez ou allumez votre iBeacon (retirez la languette si neuf).',
                                  ),
                                  const SizedBox(height: 10),
                                  _checkItem(
                                    'Placez le beacon à moins de 2 mètres de votre téléphone.',
                                  ),
                                  const SizedBox(height: 10),
                                  _checkItem(
                                    'Activez le Bluetooth sur cet appareil.',
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildStepCard(
                              step: 2,
                              title: 'Découverte',
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed:
                                          _scanning ? null : _scanBleDevices,
                                      icon: _scanning
                                          ? const SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: AppColors.white,
                                              ),
                                            )
                                          : const Icon(Icons.radar),
                                      label: Text(
                                        _scanning
                                            ? 'Scan en cours…'
                                            : 'Scan BLE Devices',
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.oliveGreen,
                                        foregroundColor: AppColors.white,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 16,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(14),
                                        ),
                                        elevation: 0,
                                      ),
                                    ),
                                  ),
                                  if (_scanning) ...[
                                    const SizedBox(height: 12),
                                    Text(
                                      'Recherche des iBeacons à proximité…',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textGrey
                                            .withValues(alpha: 0.85),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildStepCard(
                              step: 3,
                              title: 'Configuration',
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (_hasBeaconSelection)
                                    _buildSelectedBeaconCard()
                                  else
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: AppColors.lightGrey
                                            .withValues(alpha: 0.45),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Text(
                                        'Scannez un iBeacon à l\'étape 2 pour récupérer automatiquement UUID, Major et Minor.',
                                        style: TextStyle(
                                          fontSize: 13,
                                          height: 1.35,
                                          color: AppColors.textGrey
                                              .withValues(alpha: 0.9),
                                        ),
                                      ),
                                    ),
                                  const SizedBox(height: 14),
                                  _configField(
                                    'RSSI seuil',
                                    _rssiController,
                                    '-70',
                                  ),
                                  const SizedBox(height: 8),
                                  SwitchListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: const Text(
                                      'Actif',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.darkOlive,
                                      ),
                                    ),
                                    value: _activite,
                                    activeThumbColor: AppColors.oliveGreen,
                                    onChanged: (v) =>
                                        setState(() => _activite = v),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed:
                                    (_saving || !_hasBeaconSelection) ? null : _save,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.limeGreen,
                                  foregroundColor: AppColors.darkOlive,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(28),
                                  ),
                                  elevation: 0,
                                ),
                                child: _saving
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: AppColors.darkOlive,
                                        ),
                                      )
                                    : Text(
                                        _ibeacon == null
                                            ? 'Enregistrer le beacon'
                                            : 'Mettre à jour',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedBeaconCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.limeGreen.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.oliveGreen.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.check_circle, color: AppColors.oliveGreen, size: 18),
              SizedBox(width: 8),
              Text(
                'iBeacon détecté',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.darkOlive,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _beaconInfoRow('UUID', _selectedUuid!),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _beaconInfoRow('Major', '$_selectedMajor')),
              const SizedBox(width: 12),
              Expanded(child: _beaconInfoRow('Minor', '$_selectedMinor')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _beaconInfoRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 12,
            color: AppColors.textGrey.withValues(alpha: 0.85),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: AppColors.darkOlive,
          ),
        ),
      ],
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 8, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, color: AppColors.oliveGreen),
          ),
          const Icon(Icons.hub_outlined, color: AppColors.oliveGreen, size: 22),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Beacon management',
              style: TextStyle(
                color: AppColors.oliveGreen,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
          if (_ibeacon != null)
            IconButton(
              onPressed: _delete,
              icon: const Icon(Icons.delete_outline, color: Color(0xFFC0392B)),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            color: AppColors.limeGreen.withValues(alpha: 0.35),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.limeGreen.withValues(alpha: 0.25),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Icon(
            Icons.bluetooth_searching,
            size: 40,
            color: AppColors.oliveGreen,
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Connect New Beacon',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppColors.darkOlive,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Scannez votre iBeacon pour le lier automatiquement à votre stand.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textGrey.withValues(alpha: 0.85),
            fontSize: 14,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildStepCard({
    required int step,
    required String title,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppColors.lightGrey,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  '$step',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textGrey.withValues(alpha: 0.8),
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: AppColors.darkOlive,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _checkItem(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.check_circle,
          color: AppColors.oliveGreen,
          size: 20,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: AppColors.textGrey.withValues(alpha: 0.9),
              fontSize: 13,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }

  Widget _configField(
    String label,
    TextEditingController controller,
    String hint,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: AppColors.textGrey.withValues(alpha: 0.9),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: AppColors.lightGrey.withValues(alpha: 0.45),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
        ),
      ],
    );
  }
}
