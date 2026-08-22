// Passeport Maçonnique d'un membre : un document PDF d'identité (archivé
// sur Drive, sans QR — voir pdf_service.dart:buildPassportPdf) et un
// mécanisme de vérification distinct, un QR plein écran généré à la demande
// et valable une heure (voir passport_token.dart). Un membre consulte son
// propre passeport ; un membre autorisé (Vénérable Maître, Secrétaire,
// administrateurs) peut aussi l'ouvrir depuis la fiche d'un autre membre.
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../config/lodge_config.dart';
import '../models/civilite.dart';
import '../models/member.dart';
import '../models/passport_token.dart';
import '../services/drive_service.dart';
import '../services/pdf_service.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/br_decor.dart';

class MemberPassportScreen extends StatefulWidget {
  final Member member;
  const MemberPassportScreen({super.key, required this.member});

  @override
  State<MemberPassportScreen> createState() => _MemberPassportScreenState();
}

class _MemberPassportScreenState extends State<MemberPassportScreen> {
  bool _busy = false;

  String get _fileName =>
      'Passeport - ${widget.member.lastName} ${widget.member.firstName}.pdf';

  Future<void> _generatePdf() async {
    final messenger = ScaffoldMessenger.of(context);
    final state = context.read<AppState>();
    setState(() => _busy = true);
    try {
      final bytes = Uint8List.fromList(
        await buildPassportPdf(
          widget.member,
          state.members,
          lodgeVmName: state.lodgeVmName,
        ),
      );
      try {
        await DriveService.instance.archivePassportDocument(
          fileName: _fileName,
          bytes: bytes,
        );
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(content: Text('Archivage Drive : $e')),
        );
      }
      await Printing.sharePdf(bytes: bytes, filename: _fileName);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Erreur PDF : $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showQr() async {
    final messenger = ScaffoldMessenger.of(context);
    final state = context.read<AppState>();
    setState(() => _busy = true);
    try {
      final lodge = LodgeConfig.current;
      final now = DateTime.now();
      final token = PassportToken(
        id: generatePassportToken(),
        memberId: widget.member.id,
        memberName: widget.member.fullName,
        civilite: widget.member.civilite,
        grade: widget.member.grade,
        initiationDate: widget.member.initiationDate,
        entryDate: widget.member.entryDate,
        lodgeName: lodge.name,
        lodgeNumber: lodge.number,
        lodgeOrient: lodge.orient,
        lodgeObedience: lodge.obedienceAcronym,
        createdAt: now,
        expiresAt: now.add(const Duration(hours: 1)),
      );
      await state.createPassportToken(token);
      if (!mounted) return;
      final url = '${lodge.webOrigin}/#/passeport/${token.id}';
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => _PassportQrFullScreen(
            url: url,
            memberName: widget.member.fullName,
            expiresAt: token.expiresAt,
          ),
          fullscreenDialog: true,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Erreur : $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.member;
    return Scaffold(
      appBar: AppBar(title: const Text('Passeport Maçonnique')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          BrCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    BrAvatar(firstName: m.firstName, lastName: m.lastName, size: 52),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${civiliteTitle(m.civilite)} ${m.fullName}'.trim(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            m.grade,
                            style: const TextStyle(color: BrColors.muted, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  '${LodgeConfig.current.shortTitle} — '
                  'O∴ de ${LodgeConfig.current.orient}',
                  style: const TextStyle(color: BrColors.muted, fontSize: 12.5),
                ),
                if (m.initiationDate.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      "Initié le ${m.initiationDate}",
                      style: const TextStyle(color: BrColors.muted, fontSize: 12.5),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: BrColors.violet),
            icon: const Icon(Icons.qr_code_2),
            label: const Text('Afficher mon QR (valable 1 heure)'),
            onPressed: _busy ? null : _showQr,
          ),
          const SizedBox(height: 10),
          Text(
            'À présenter, plein écran, au Couvreur de la Loge visitée pour '
            "vérification. Le QR n'est valable qu'une heure : régénérez-le "
            'juste avant le contrôle.',
            style: const TextStyle(color: BrColors.muted, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            icon: _busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.picture_as_pdf_outlined),
            label: const Text('Générer le PDF (archive Drive)'),
            onPressed: _busy ? null : _generatePdf,
          ),
          const SizedBox(height: 8),
          const Text(
            "Document d'archive/impression, sans QR : la vérification se "
            "fait uniquement via le bouton ci-dessus.",
            style: TextStyle(color: BrColors.muted, fontSize: 12, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _PassportQrFullScreen extends StatelessWidget {
  final String url;
  final String memberName;
  final DateTime expiresAt;
  const _PassportQrFullScreen({
    required this.url,
    required this.memberName,
    required this.expiresAt,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        title: const Text('Vérification du Passeport'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                memberName,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 24),
              QrImageView(
                data: url,
                size: 260,
                backgroundColor: Colors.white,
              ),
              const SizedBox(height: 24),
              Text(
                'Valable jusqu\'à '
                '${expiresAt.hour.toString().padLeft(2, '0')}:'
                '${expiresAt.minute.toString().padLeft(2, '0')}',
                style: const TextStyle(color: Colors.black54, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
