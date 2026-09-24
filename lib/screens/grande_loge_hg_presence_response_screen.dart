// Page publique de réponse à un lien de présence pour une tenue de Hauts
// Grades (collecte sans connexion) — même principe que
// presence_response_screen.dart (loges bleues) : Flux A (membre du corps,
// réponse nominative) et Flux B (dignitaire invité, présence + décompte
// global de délégation, sans répartition par grade). Accessible sans
// authentification classique : voir main.dart pour la détection de route
// (#/reponse-hg/<jeton>, distincte de #/reponse/<jeton> des loges bleues)
// et firestore.rules pour la portée exacte des droits accordés au jeton.
import 'package:flutter/material.dart';

import '../models/hg_presence_link.dart';
import '../services/hg_body_service.dart';
import '../theme.dart';
import '../widgets/br_decor.dart';

class GrandeLogeHgPresenceResponseScreen extends StatefulWidget {
  final String token;
  const GrandeLogeHgPresenceResponseScreen({super.key, required this.token});

  @override
  State<GrandeLogeHgPresenceResponseScreen> createState() =>
      _GrandeLogeHgPresenceResponseScreenState();
}

enum _LoadState { loading, notFound, expired, ready, submitted }

class _GrandeLogeHgPresenceResponseScreenState
    extends State<GrandeLogeHgPresenceResponseScreen> {
  _LoadState _state = _LoadState.loading;
  HgPresenceLink? _link;
  bool _submitting = false;
  String? _pendingStatus;
  bool? _pendingAgape;
  int _delegationCount = 0;
  bool? _pendingRecipientAgape;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final link = await HgBodyService.instance.getHgPresenceLink(widget.token);
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
      _pendingStatus = link.status == kHgPresenceStatusPending
          ? null
          : link.status;
      _pendingAgape = link.agapePresent;
      _delegationCount = link.delegationCount ?? 0;
      _pendingRecipientAgape = link.recipientAgapePresent;
      _state = _LoadState.ready;
    });
  }

  Future<void> _submitMember() async {
    final status = _pendingStatus;
    final link = _link;
    if (status == null || link == null) return;
    setState(() => _submitting = true);
    try {
      await HgBodyService.instance.submitHgMemberResponse(
        widget.token,
        status: status,
        agapePresent: status == kHgPresenceStatusPresent && link.hasAgape
            ? (_pendingAgape ?? false)
            : null,
      );
      if (!mounted) return;
      setState(() => _state = _LoadState.submitted);
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erreur d\'envoi : $e')));
    }
  }

  Future<void> _submitDelegation() async {
    final status = _pendingStatus;
    if (status == null) return;
    setState(() => _submitting = true);
    try {
      await HgBodyService.instance.submitHgDelegationResponse(
        widget.token,
        status: status,
        delegationCount: _delegationCount,
        recipientAgapePresent: _pendingRecipientAgape,
      );
      if (!mounted) return;
      setState(() => _state = _LoadState.submitted);
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erreur d\'envoi : $e')));
    }
  }

  bool _canSubmitMember() {
    if (_pendingStatus == null) return false;
    if (_pendingStatus == kHgPresenceStatusPresent &&
        (_link?.hasAgape ?? false) &&
        _pendingAgape == null) {
      return false;
    }
    return true;
  }

  bool _canSubmitDelegation() {
    if (_pendingStatus == null) return false;
    if (_pendingStatus == kHgPresenceStatusPresent &&
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
          child: Center(child: CircularProgressIndicator(color: BrColors.gold)),
        );
      case _LoadState.notFound:
        return const _MessageCard(
          icon: Icons.link_off,
          title: 'Lien invalide',
          message:
              'Ce lien de réponse est introuvable. Vérifiez qu\'il a '
              'été copié en entier, ou contactez le Secrétariat.',
        );
      case _LoadState.expired:
        return const _MessageCard(
          icon: Icons.hourglass_bottom,
          title: 'Délai de réponse dépassé',
          message:
              'Ce lien n\'est plus valable : le délai de réponse pour '
              'cette tenue est dépassé. Contactez le Secrétariat si vous '
              'souhaitez signaler votre présence.',
        );
      case _LoadState.submitted:
        return const _MessageCard(
          icon: Icons.check_circle_outline,
          title: 'Réponse enregistrée',
          message:
              'Merci, votre réponse a bien été transmise. Vous pouvez '
              'revenir sur ce lien pour la modifier tant qu\'il reste '
              'valable.',
          color: BrColors.menuVisiteurs,
        );
      case _LoadState.ready:
        final link = _link!;
        final delegation =
            link.kind == kHgPresenceLinkKindDelegation && !link.recipientAlone;
        return delegation ? _buildDelegationForm(link) : _buildMemberForm(link);
    }
  }

  Widget _buildMemberForm(HgPresenceLink link) {
    final showAgape =
        link.hasAgape && _pendingStatus == kHgPresenceStatusPresent;
    return Column(
      children: [
        _HeaderCard(link: link, name: link.displayName),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: _ChoiceButton(
                label: 'Présent',
                icon: Icons.check_circle_outline,
                color: BrColors.menuVisiteurs,
                selected: _pendingStatus == kHgPresenceStatusPresent,
                onTap: () =>
                    setState(() => _pendingStatus = kHgPresenceStatusPresent),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ChoiceButton(
                label: 'Absent',
                icon: Icons.cancel_outlined,
                color: BrColors.menuTresorerie,
                selected: _pendingStatus == kHgPresenceStatusAbsent,
                onTap: () => setState(() {
                  _pendingStatus = kHgPresenceStatusAbsent;
                  _pendingAgape = null;
                }),
              ),
            ),
          ],
        ),
        if (showAgape) ...[
          const SizedBox(height: 18),
          _AgapeChoice(
            value: _pendingAgape,
            onChanged: (v) => setState(() => _pendingAgape = v),
          ),
        ],
        const SizedBox(height: 24),
        _SubmitButton(
          submitting: _submitting,
          enabled: _canSubmitMember(),
          onPressed: _submitMember,
        ),
      ],
    );
  }

  Widget _buildDelegationForm(HgPresenceLink link) {
    final showOwnAgape =
        link.hasAgape && _pendingStatus == kHgPresenceStatusPresent;
    return Column(
      children: [
        _HeaderCard(link: link, name: link.recipientName),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: _ChoiceButton(
                label: 'Présent',
                icon: Icons.check_circle_outline,
                color: BrColors.menuVisiteurs,
                selected: _pendingStatus == kHgPresenceStatusPresent,
                onTap: () =>
                    setState(() => _pendingStatus = kHgPresenceStatusPresent),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ChoiceButton(
                label: 'Absent',
                icon: Icons.cancel_outlined,
                color: BrColors.menuTresorerie,
                selected: _pendingStatus == kHgPresenceStatusAbsent,
                onTap: () => setState(() {
                  _pendingStatus = kHgPresenceStatusAbsent;
                  _pendingRecipientAgape = null;
                }),
              ),
            ),
          ],
        ),
        if (showOwnAgape) ...[
          const SizedBox(height: 18),
          _AgapeChoice(
            value: _pendingRecipientAgape,
            onChanged: (v) => setState(() => _pendingRecipientAgape = v),
          ),
        ],
        const SizedBox(height: 24),
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
                'délégation présentes à cette tenue.',
                style: TextStyle(color: BrColors.muted, fontSize: 12.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _CounterField(
          label: 'Personnes de la délégation présentes',
          value: _delegationCount,
          onChanged: (v) => setState(() => _delegationCount = v),
        ),
        const SizedBox(height: 24),
        _SubmitButton(
          submitting: _submitting,
          enabled: _canSubmitDelegation(),
          onPressed: _submitDelegation,
        ),
      ],
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final HgPresenceLink link;
  final String name;
  const _HeaderCard({required this.link, required this.name});

  @override
  Widget build(BuildContext context) {
    return BrCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
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
            'Tenue ${link.sessionType} — ${link.sessionDegreeLabel}, le '
            '${link.sessionDateLabel}',
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
    );
  }
}

class _AgapeChoice extends StatelessWidget {
  final bool? value;
  final ValueChanged<bool> onChanged;
  const _AgapeChoice({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                selected: value == true,
                onTap: () => onChanged(true),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ChoiceButton(
                label: 'Non',
                icon: Icons.remove_circle_outline,
                color: BrColors.muted,
                selected: value == false,
                onTap: () => onChanged(false),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SubmitButton extends StatelessWidget {
  final bool submitting;
  final bool enabled;
  final VoidCallback onPressed;
  const _SubmitButton({
    required this.submitting,
    required this.enabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        icon: submitting
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.send_outlined),
        label: const Text('Envoyer ma réponse'),
        onPressed: enabled && !submitting ? onPressed : null,
      ),
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
            style: const TextStyle(
              color: BrColors.muted,
              fontSize: 13.5,
              height: 1.4,
            ),
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
            icon: const Icon(
              Icons.remove_circle_outline,
              color: BrColors.muted,
            ),
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
