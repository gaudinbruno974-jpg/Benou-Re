// Page publique de réponse à un lien de présence (collecte sans connexion,
// Flux A — membres de la Loge). Accessible sans authentification classique :
// voir main.dart pour la détection de route et firestore.rules pour la
// portée exacte des droits accordés au jeton.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/presence_link.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/br_decor.dart';

class PresenceResponseScreen extends StatefulWidget {
  final String token;
  const PresenceResponseScreen({super.key, required this.token});

  @override
  State<PresenceResponseScreen> createState() =>
      _PresenceResponseScreenState();
}

enum _LoadState { loading, notFound, expired, ready, submitted }

class _PresenceResponseScreenState extends State<PresenceResponseScreen> {
  _LoadState _state = _LoadState.loading;
  PresenceLink? _link;
  bool _submitting = false;
  String? _pendingStatus;
  bool? _pendingAgape;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final appState = context.read<AppState>();
    final link = await appState.getPresenceLink(widget.token);
    if (!mounted) return;
    if (link == null) {
      setState(() => _state = _LoadState.notFound);
      return;
    }
    if (link.isExpired) {
      setState(() {
        _link = link;
        _state = _LoadState.expired;
      });
      return;
    }
    setState(() {
      _link = link;
      _pendingStatus = link.status == kPresenceStatusPending
          ? null
          : link.status;
      _pendingAgape = link.agapePresent;
      _state = _LoadState.ready;
    });
  }

  Future<void> _submit() async {
    final status = _pendingStatus;
    if (status == null) return;
    final link = _link;
    if (link == null) return;
    setState(() => _submitting = true);
    try {
      final appState = context.read<AppState>();
      await appState.submitPresenceResponse(
        widget.token,
        status: status,
        agapePresent: status == kPresenceStatusPresent && link.hasAgape
            ? (_pendingAgape ?? false)
            : null,
      );
      if (!mounted) return;
      setState(() => _state = _LoadState.submitted);
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur d\'envoi : $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Réponse de présence')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: _buildBody(),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_state) {
      case _LoadState.loading:
        return const Padding(
          padding: EdgeInsets.all(40),
          child: Center(
            child: CircularProgressIndicator(color: BrColors.gold),
          ),
        );
      case _LoadState.notFound:
        return const _MessageCard(
          icon: Icons.link_off,
          title: 'Lien invalide',
          message: 'Ce lien de réponse est introuvable. Vérifiez qu\'il a '
              'été copié en entier, ou contactez le Secrétariat.',
        );
      case _LoadState.expired:
        return const _MessageCard(
          icon: Icons.hourglass_bottom,
          title: 'Délai de réponse dépassé',
          message: 'Ce lien n\'est plus valable : le délai de réponse pour '
              'cette tenue est dépassé. Contactez le Secrétariat si vous '
              'souhaitez signaler votre présence.',
        );
      case _LoadState.submitted:
        return const _MessageCard(
          icon: Icons.check_circle_outline,
          title: 'Réponse enregistrée',
          message: 'Merci, votre réponse a bien été transmise. Vous pouvez '
              'revenir sur ce lien pour la modifier tant qu\'il reste '
              'valable.',
          color: BrColors.menuVisiteurs,
        );
      case _LoadState.ready:
        return _buildForm(_link!);
    }
  }

  Widget _buildForm(PresenceLink link) {
    final showAgape = link.hasAgape && _pendingStatus == kPresenceStatusPresent;
    return Column(
      children: [
        BrCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                link.memberName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                link.sessionLabel,
                style: const TextStyle(color: BrColors.gold, fontSize: 14),
              ),
              const SizedBox(height: 4),
              Text(
                'Tenue ${link.sessionType} au ${link.sessionDegreeLabel} '
                'degré, le ${link.sessionDateLabel}',
                style: const TextStyle(color: BrColors.muted, fontSize: 13),
              ),
              if (link.isAnswered) ...[
                const SizedBox(height: 12),
                Text(
                  'Réponse déjà enregistrée : vous pouvez la modifier.',
                  style: TextStyle(
                    color: BrColors.muted.withValues(alpha: 0.85),
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: _ChoiceButton(
                label: 'Présent',
                icon: Icons.check_circle_outline,
                color: BrColors.menuVisiteurs,
                selected: _pendingStatus == kPresenceStatusPresent,
                onTap: () => setState(() {
                  _pendingStatus = kPresenceStatusPresent;
                }),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ChoiceButton(
                label: 'Absent',
                icon: Icons.cancel_outlined,
                color: BrColors.menuTresorerie,
                selected: _pendingStatus == kPresenceStatusAbsent,
                onTap: () => setState(() {
                  _pendingStatus = kPresenceStatusAbsent;
                  _pendingAgape = null;
                }),
              ),
            ),
          ],
        ),
        if (showAgape) ...[
          const SizedBox(height: 18),
          const Text(
            'Présent aux agapes ?',
            style: TextStyle(color: BrColors.text, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _ChoiceButton(
                  label: 'Oui',
                  icon: Icons.restaurant_outlined,
                  color: BrColors.teal,
                  selected: _pendingAgape == true,
                  onTap: () => setState(() => _pendingAgape = true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ChoiceButton(
                  label: 'Non',
                  icon: Icons.remove_circle_outline,
                  color: BrColors.muted,
                  selected: _pendingAgape == false,
                  onTap: () => setState(() => _pendingAgape = false),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: _submitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send_outlined),
            label: const Text('Envoyer ma réponse'),
            onPressed: _canSubmit() && !_submitting ? _submit : null,
          ),
        ),
      ],
    );
  }

  bool _canSubmit() {
    if (_pendingStatus == null) return false;
    if (_pendingStatus == kPresenceStatusPresent &&
        (_link?.hasAgape ?? false) &&
        _pendingAgape == null) {
      return false;
    }
    return true;
  }
}

class _MessageCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Color color;
  const _MessageCard({
    required this.icon,
    required this.title,
    required this.message,
    this.color = BrColors.gold,
  });

  @override
  Widget build(BuildContext context) {
    return BrCard(
      padding: const EdgeInsets.all(28),
      child: Column(
        children: [
          Icon(icon, color: color, size: 40),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: BrColors.muted, fontSize: 13.5, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _ChoiceButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  const _ChoiceButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return BrCard(
      accent: color,
      onTap: onTap,
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Column(
        children: [
          Icon(icon, color: selected ? color : BrColors.muted, size: 28),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : BrColors.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
