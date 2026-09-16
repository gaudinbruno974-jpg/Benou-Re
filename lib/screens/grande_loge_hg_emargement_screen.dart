// Émargement d'une tenue d'un corps de Hauts Grades — même principe que
// emargement_screen.dart (loges bleues), simplifié à un seul signataire de
// planche (le Trois Fois Puissant Maître) : un Collège de Perfection n'a
// pas les offices Orateur/V∴M∴/Secrétaire distincts d'une loge bleue.
import 'package:flutter/material.dart';

import '../models/dignitary.dart';
import '../models/hg_body.dart';
import '../models/member.dart';
import '../models/session.dart';
import '../models/visitor.dart';
import '../services/hg_body_service.dart';
import '../theme.dart';
import '../widgets/br_decor.dart';
import '../widgets/signature_dialog.dart';

const String _tfpmSignatureKey = 'plancheTfpmSignature';

class _Signer {
  final String id;
  final String name;
  final String role;
  final String? current;
  const _Signer(this.id, this.name, this.role, this.current);
}

class GrandeLogeHgEmargementScreen extends StatefulWidget {
  final HgBody body;
  final Session session;
  const GrandeLogeHgEmargementScreen({
    super.key,
    required this.body,
    required this.session,
  });

  @override
  State<GrandeLogeHgEmargementScreen> createState() =>
      _GrandeLogeHgEmargementScreenState();
}

class _GrandeLogeHgEmargementScreenState
    extends State<GrandeLogeHgEmargementScreen> {
  late Session _session;
  List<Member> _members = [];
  List<Visitor> _visitors = [];
  List<Dignitary> _dignitaries = [];

  @override
  void initState() {
    super.initState();
    _session = widget.session;
    HgBodyService.instance.membersStream(widget.body).first.then((v) {
      if (mounted) setState(() => _members = v);
    });
    HgBodyService.instance.visitorsStream(widget.body).first.then((v) {
      if (mounted) setState(() => _visitors = v);
    });
    HgBodyService.instance.dignitariesStream(widget.body).first.then((v) {
      if (mounted) setState(() => _dignitaries = v);
    });
  }

  Future<void> _sign(_Signer signer, {required bool isPlanche}) async {
    final dataUrl = await captureSignature(context, signer.name);
    if (dataUrl == null) return;
    final map = Map<String, dynamic>.from(_session.toMap());
    if (isPlanche) {
      map[_tfpmSignatureKey] = dataUrl;
    } else {
      map['signatures'] = {..._session.signatures, signer.id: dataUrl};
    }
    final updated = Session.fromMap(_session.id, map);
    await HgBodyService.instance.updateSession(widget.body, updated);
    setState(() => _session = updated);
  }

  @override
  Widget build(BuildContext context) {
    final sigs = _session.signatures;
    final presentMembers = _members
        .where((m) => _session.presentIds.contains(m.id))
        .toList();
    final presentVisitors = _visitors
        .where((v) => _session.visitorIds.contains(v.id))
        .toList();
    final presentDignitaries = _dignitaries
        .where((d) => _session.dignitaryIds.contains(d.id))
        .toList();

    final memberSigners = [
      for (final m in presentMembers)
        _Signer(
          m.id,
          m.fullName,
          m.function.isNotEmpty && m.function != 'Aucun'
              ? m.function
              : 'Membre',
          sigs[m.id],
        ),
    ];
    final visitorSigners = [
      for (final v in presentVisitors)
        _Signer(v.id, v.fullName, 'Visiteur', sigs[v.id]),
    ];
    final dignitarySigners = [
      for (final d in presentDignitaries)
        _Signer(
          d.id,
          d.fullName,
          d.title.isNotEmpty ? d.title : 'Dignitaire',
          sigs[d.id],
        ),
    ];
    final signerTfpm = _Signer(
      _tfpmSignatureKey,
      (_session.vmName ?? '').isNotEmpty ? _session.vmName! : 'Signataire',
      'Trois Fois Puissant Maître',
      _session.extra[_tfpmSignatureKey] as String?,
    );
    final total =
        memberSigners.length +
        visitorSigners.length +
        dignitarySigners.length +
        1;
    final missing = [
      ...memberSigners,
      ...visitorSigners,
      ...dignitarySigners,
      signerTfpm,
    ].where((s) => (s.current ?? '').isEmpty).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Émargement'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(28),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8, left: 16, right: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '$missing signature(s) manquante(s) sur $total',
                style: const TextStyle(color: BrColors.muted, fontSize: 12),
              ),
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 18, 14, 28),
        children: [
          const BrSectionTitle('MEMBRES PRÉSENTS', icon: Icons.draw_outlined),
          if (memberSigners.isEmpty)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'Aucun membre présent enregistré.',
                style: TextStyle(color: BrColors.muted),
              ),
            ),
          for (final s in memberSigners)
            _SignerTile(signer: s, onSign: () => _sign(s, isPlanche: false)),
          const SizedBox(height: 12),
          const BrSectionTitle('VISITEURS PRÉSENTS', icon: Icons.draw_outlined),
          if (visitorSigners.isEmpty)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'Aucun visiteur présent enregistré.',
                style: TextStyle(color: BrColors.muted),
              ),
            ),
          for (final s in visitorSigners)
            _SignerTile(signer: s, onSign: () => _sign(s, isPlanche: false)),
          const SizedBox(height: 12),
          const BrSectionTitle(
            'DIGNITAIRES PRÉSENTS',
            icon: Icons.draw_outlined,
          ),
          if (dignitarySigners.isEmpty)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'Aucun dignitaire présent enregistré.',
                style: TextStyle(color: BrColors.muted),
              ),
            ),
          for (final s in dignitarySigners)
            _SignerTile(signer: s, onSign: () => _sign(s, isPlanche: false)),
          const SizedBox(height: 12),
          const BrSectionTitle(
            'SIGNATURE DE LA PLANCHE TRACÉE',
            icon: Icons.draw_outlined,
          ),
          _SignerTile(
            signer: signerTfpm,
            onSign: () => _sign(signerTfpm, isPlanche: true),
          ),
        ],
      ),
    );
  }
}

class _SignerTile extends StatelessWidget {
  final _Signer signer;
  final VoidCallback? onSign;
  const _SignerTile({required this.signer, this.onSign});

  @override
  Widget build(BuildContext context) {
    final signed = (signer.current ?? '').isNotEmpty;
    final color = signed ? const Color(0xFF34D399) : BrColors.gold;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: BrCard(
        accent: color,
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    signer.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    signer.role,
                    style: const TextStyle(color: BrColors.muted, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            BrBadge(
              label: signed ? 'Signé' : 'En attente',
              color: color,
              icon: signed ? Icons.check_circle_outline : Icons.schedule,
            ),
            const SizedBox(width: 6),
            TextButton(
              onPressed: onSign,
              child: Text(
                signed ? 'Modifier' : 'Signer',
                style: const TextStyle(color: BrColors.teal),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
