// Page publique de réponse à un lien de présence (collecte sans connexion) :
// Flux A (membre de la Loge, réponse nominative) et Flux B (dignitaire ou
// Vénérable d'une autre Loge, décompte de délégation). Accessible sans
// authentification classique : voir main.dart pour la détection de route et
// firestore.rules pour la portée exacte des droits accordés au jeton.
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
  int _apprenti = 0;
  int _compagnon = 0;
  int _maitre = 0;
  int _agapeTotal = 0;
  bool? _pendingRecipientAgape;

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
      _apprenti = link.apprentiCount ?? 0;
      _compagnon = link.compagnonCount ?? 0;
      _maitre = link.maitreCount ?? 0;
      _agapeTotal = link.agapeTotal ?? 0;
      _pendingRecipientAgape = link.recipientAgapePresent;
      _state = _LoadState.ready;
    });
  }

  Future<void> _submitMember() async {
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

  Future<void> _submitDelegation() async {
    final status = _pendingStatus;
    if (status == null) return;
    setState(() => _submitting = true);
    try {
      final appState = context.read<AppState>();
      await appState.submitDelegationResponse(
        widget.token,
        status: status,
        apprentiCount: _apprenti,
        compagnonCount: _compagnon,
        maitreCount: _maitre,
        agapeTotal: _agapeTotal,
        recipientAgapePresent: _pendingRecipientAgape,
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

  bool _canSubmitDelegation() {
    if (_pendingStatus == null) return false;
    if (_pendingStatus == kPresenceStatusPresent &&
        (_link?.hasAgape ?? false) &&
        _pendingRecipientAgape == null) {
      return false;
    }
    return true;
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
        final link = _link!;
        // Un dignitaire venant seul (rang 1/2 — voir recipientAlone) répond
        // en Présent/Absent/Agapes, comme un membre : pas de délégation à
        // déclarer.
        final delegation =
            link.kind == kPresenceLinkKindDelegation && !link.recipientAlone;
        return delegation ? _buildDelegationForm(link) : _buildMemberForm(link);
    }
  }

  Widget _buildMemberForm(PresenceLink link) {
    final showAgape = link.hasAgape && _pendingStatus == kPresenceStatusPresent;
    return Column(
      children: [
        BrCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                link.displayName,
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
            onPressed: _canSubmitMember() && !_submitting
                ? _submitMember
                : null,
          ),
        ),
      ],
    );
  }

  bool _canSubmitMember() {
    if (_pendingStatus == null) return false;
    if (_pendingStatus == kPresenceStatusPresent &&
        (_link?.hasAgape ?? false) &&
        _pendingAgape == null) {
      return false;
    }
    return true;
  }

  /// Deux pavés bien distincts pour un dignitaire venant avec une
  /// délégation (rang 3+) : sa propre présence (pavé 1, mêmes
  /// fonctionnalités que pour un membre ou un dignitaire venant seul — voir
  /// [_buildMemberForm]), puis le décompte de sa délégation (pavé 2,
  /// inchangé). Les deux sont envoyés ensemble par un seul bouton, dans la
  /// même écriture Firestore.
  Widget _buildDelegationForm(PresenceLink link) {
    final showOwnAgape = link.hasAgape && _pendingStatus == kPresenceStatusPresent;
    return Column(
      children: [
        // Pavé 1 — sa propre présence.
        BrCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                link.recipientName,
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
                  _pendingRecipientAgape = null;
                }),
              ),
            ),
          ],
        ),
        if (showOwnAgape) ...[
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
                  selected: _pendingRecipientAgape == true,
                  onTap: () => setState(() => _pendingRecipientAgape = true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ChoiceButton(
                  label: 'Non',
                  icon: Icons.remove_circle_outline,
                  color: BrColors.muted,
                  selected: _pendingRecipientAgape == false,
                  onTap: () => setState(() => _pendingRecipientAgape = false),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 24),

        // Pavé 2 — sa délégation, distincte de sa présence personnelle
        // ci-dessus : il peut déléguer des FF∴/SS∴ de sa Loge sans venir en
        // personne, ou l'inverse.
        BrCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'Votre délégation',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Merci d\'indiquer le nombre de personnes de votre '
                'délégation présentes à cette tenue, par grade.',
                style: TextStyle(color: BrColors.muted, fontSize: 12.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _CounterField(
          label: 'Apprentis présents en tenue',
          value: _apprenti,
          onChanged: (v) => setState(() => _apprenti = v),
        ),
        const SizedBox(height: 12),
        _CounterField(
          label: 'Compagnons présents en tenue',
          value: _compagnon,
          onChanged: (v) => setState(() => _compagnon = v),
        ),
        const SizedBox(height: 12),
        _CounterField(
          label: 'Maîtres présents en tenue',
          value: _maitre,
          onChanged: (v) => setState(() => _maitre = v),
        ),
        const SizedBox(height: 18),
        _CounterField(
          label: 'Total agapes de la délégation (vous compris si présent)',
          value: _agapeTotal,
          onChanged: (v) => setState(() => _agapeTotal = v),
        ),
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
            onPressed: _canSubmitDelegation() && !_submitting
                ? _submitDelegation
                : null,
          ),
        ),
      ],
    );
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

class _CounterField extends StatelessWidget {
  final String label;
  final int value;
  final ValueChanged<int> onChanged;
  const _CounterField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return BrCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: BrColors.text, fontSize: 13.5),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline, color: BrColors.muted),
            onPressed: value > 0 ? () => onChanged(value - 1) : null,
          ),
          SizedBox(
            width: 28,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: BrColors.gold),
            onPressed: () => onChanged(value + 1),
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
