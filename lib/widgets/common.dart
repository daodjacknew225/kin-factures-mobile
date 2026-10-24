import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../app/theme.dart';
import '../core/format.dart';

// Composants partagés, équivalents des classes kf- du site (kf-badge, kf-amount, kf-alert…)

class KfLogo extends StatelessWidget {
  const KfLogo({super.key, this.height = 32, this.iconOnly = false});
  final double height;
  final bool iconOnly;

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
        iconOnly ? 'assets/logo-kin-factures-icone.svg' : 'assets/logo-kin-factures.svg',
        height: height,
        semanticsLabel: 'Kin Factures',
      );
}

enum BadgeTone { paid, pending, overdue, neutral }

// Badge de statut (kf-badge) : point coloré + libellé
class KfBadge extends StatelessWidget {
  const KfBadge(this.label, {super.key, this.tone = BadgeTone.neutral, this.strike = false});
  final String label;
  final BadgeTone tone;
  final bool strike;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = switch (tone) {
      BadgeTone.paid => (KfColors.brandSoft, KfColors.brand),
      BadgeTone.pending => (KfColors.pendingSoft, KfColors.pending),
      BadgeTone.overdue => (KfColors.dangerSoft, KfColors.danger),
      BadgeTone.neutral => (KfColors.surfaceSunken, KfColors.inkMuted),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: KfSpace.s2, vertical: 2),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(999)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 6, height: 6, decoration: BoxDecoration(color: foreground, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            height: 16 / 12,
            fontWeight: FontWeight.w500,
            color: foreground,
            decoration: strike ? TextDecoration.lineThrough : null,
          ),
        ),
      ]),
    );
  }
}

enum AmountSize { sm, md, lg, xl }

// Montant (kf-amount) : chiffres alignés, devise en gris
class KfAmount extends StatelessWidget {
  const KfAmount(this.value, this.currency, {super.key, this.size = AmountSize.md, this.color});
  final num? value;
  final String currency;
  final AmountSize size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final (fontSize, weight) = switch (size) {
      AmountSize.sm => (13.0, FontWeight.w500),
      AmountSize.md => (15.0, FontWeight.w500),
      AmountSize.lg => (24.0, FontWeight.w600),
      AmountSize.xl => (32.0, FontWeight.w600),
    };
    return Text.rich(
      TextSpan(children: [
        TextSpan(text: formatNumber(value)),
        TextSpan(text: ' $currency', style: const TextStyle(fontWeight: FontWeight.w500, color: KfColors.inkMuted)),
      ]),
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: weight,
        color: color ?? KfColors.ink,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
      maxLines: 1,
    );
  }
}

enum AlertTone { success, danger, pending }

// Message (kf-alert)
class KfAlert extends StatelessWidget {
  const KfAlert(this.message, {super.key, this.tone = AlertTone.danger});
  final String message;
  final AlertTone tone;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = switch (tone) {
      AlertTone.success => (KfColors.brandSoft, KfColors.brand),
      AlertTone.danger => (KfColors.dangerSoft, KfColors.danger),
      AlertTone.pending => (KfColors.pendingSoft, KfColors.pending),
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: KfSpace.s4, vertical: KfSpace.s3),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(KfRadius.md)),
      child: Text(message, style: TextStyle(fontSize: 13, height: 18 / 13, color: foreground)),
    );
  }
}

// Chargement d'une page
class KfLoader extends StatelessWidget {
  const KfLoader({super.key});

  @override
  Widget build(BuildContext context) => const Center(
        child: Padding(
          padding: EdgeInsets.all(KfSpace.s8),
          child: SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 3, color: KfColors.brand)),
        ),
      );
}

// Erreur de chargement avec « Réessayer »
class KfErrorView extends StatelessWidget {
  const KfErrorView(this.message, {super.key, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(KfSpace.s6),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            KfAlert(message),
            const SizedBox(height: KfSpace.s4),
            OutlinedButton(onPressed: onRetry, child: const Text('Réessayer')),
          ]),
        ),
      );
}

// Liste vide
class KfEmpty extends StatelessWidget {
  const KfEmpty(this.message, {super.key, this.icon = Icons.inbox_outlined});
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(KfSpace.s8),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 40, color: KfColors.inkMuted),
            const SizedBox(height: KfSpace.s3),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: KfColors.inkMuted)),
          ]),
        ),
      );
}

// Titre de section (section-title du site)
class KfSectionTitle extends StatelessWidget {
  const KfSectionTitle(this.title, {super.key, this.trailing});
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: KfSpace.s3),
        child: Row(children: [
          Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 17))),
          ?trailing,
        ]),
      );
}
