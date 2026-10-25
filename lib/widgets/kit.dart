import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../app/theme.dart';

// Composants du style « fintech » de l'application : listes denses, pastilles d'initiales,
// titres de section, squelettes de chargement, actions rapides. Couleurs : KfColors uniquement.

// Initiales dans une pastille : « Djakaridja DAO » → « DD »
String initialsOf(String name) {
  final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return '?';
  return (words.first[0] + (words.length > 1 ? words.last[0] : '')).toUpperCase();
}

class KfAvatar extends StatelessWidget {
  const KfAvatar(this.name, {super.key, this.size = 40, this.inverted = false});
  final String name;
  final double size;
  final bool inverted; // sur fond vert foncé

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: inverted ? KfColors.onHero.withValues(alpha: 0.16) : KfColors.brandSoft,
          shape: BoxShape.circle,
        ),
        child: Text(
          initialsOf(name),
          style: TextStyle(
            fontSize: size * 0.36,
            fontWeight: FontWeight.w600,
            color: inverted ? KfColors.onHero : KfColors.brand,
          ),
        ),
      );
}

// Titre de section discret : « À RELANCER » + action à droite
class KfOverline extends StatelessWidget {
  const KfOverline(this.title, {super.key, this.action, this.onAction, this.padding});
  final String title;
  final String? action;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) => Padding(
        padding: padding ?? const EdgeInsets.fromLTRB(KfSpace.s1, KfSpace.s6, KfSpace.s1, KfSpace.s2),
        child: Row(children: [
          Expanded(
            child: Text(
              title.toUpperCase(),
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.6, color: KfColors.inkMuted),
            ),
          ),
          if (action != null)
            GestureDetector(
              onTap: onAction,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(action!, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: KfColors.brand)),
              ),
            ),
        ]),
      );
}

// Groupe de lignes dans une seule carte, séparées par un trait fin
class KfGroup extends StatelessWidget {
  const KfGroup({super.key, required this.children, this.dividerIndent = 68});
  final List<Widget> children;
  final double dividerIndent;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: KfColors.surfaceRaised,
          borderRadius: BorderRadius.circular(KfRadius.lg),
          border: Border.all(color: KfColors.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) Divider(height: 1, indent: dividerIndent),
            children[i],
          ],
        ]),
      );
}

// Ligne de liste : pastille, titre, sous-titre, montant et statut à droite
class KfRow extends StatelessWidget {
  const KfRow({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.subtitleColor,
    this.trailing,
    this.trailingBottom,
    this.onTap,
  });
  final Widget? leading;
  final String title;
  final String? subtitle;
  final Color? subtitleColor;
  final Widget? trailing;
  final Widget? trailingBottom;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: KfSpace.s4, vertical: 12),
          child: Row(children: [
            if (leading != null) ...[leading!, const SizedBox(width: 12)],
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: KfColors.ink)),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, color: subtitleColor ?? KfColors.inkMuted)),
                ],
              ]),
            ),
            if (trailing != null || trailingBottom != null) ...[
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                ?trailing,
                if (trailingBottom != null) ...[const SizedBox(height: 4), trailingBottom!],
              ]),
            ],
          ]),
        ),
      );
}

// Pastille compacte de statut (point + libellé), pour les listes
class KfPill extends StatelessWidget {
  const KfPill(this.label, {super.key, required this.color, required this.background, this.strike = false});
  final String label;
  final Color color;
  final Color background;
  final bool strike;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(999)),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            height: 16 / 11,
            fontWeight: FontWeight.w600,
            color: color,
            decoration: strike ? TextDecoration.lineThrough : null,
          ),
        ),
      );
}

// Action rapide : rond avec icône + libellé (bandeau de l'accueil, détail d'une facture)
class KfQuickAction extends StatelessWidget {
  const KfQuickAction({super.key, required this.icon, required this.label, required this.onTap, this.inverted = false, this.danger = false});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool inverted; // sur fond vert foncé
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final background = inverted ? KfColors.onHero.withValues(alpha: 0.14) : (danger ? KfColors.dangerSoft : KfColors.brandSoft);
    final foreground = inverted ? KfColors.onHero : (danger ? KfColors.danger : KfColors.brand);
    return Opacity(
      opacity: onTap == null ? 0.45 : 1,
      child: InkWell(
        onTap: onTap == null
            ? null
            : () {
                HapticFeedback.lightImpact();
                onTap!();
              },
        borderRadius: BorderRadius.circular(KfRadius.lg),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: KfSpace.s2, horizontal: 2),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(color: background, shape: BoxShape.circle),
              child: Icon(icon, color: foreground, size: 22),
            ),
            const SizedBox(height: 6),
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: inverted ? KfColors.onHero : KfColors.ink)),
          ]),
        ),
      ),
    );
  }
}

// Squelette de chargement : blocs gris qui pulsent doucement
class KfSkeleton extends StatefulWidget {
  const KfSkeleton({super.key, required this.child});
  final Widget child;

  @override
  State<KfSkeleton> createState() => _KfSkeletonState();
}

class _KfSkeletonState extends State<KfSkeleton> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: Tween(begin: 0.45, end: 1.0).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut)),
        child: widget.child,
      );
}

class KfBone extends StatelessWidget {
  const KfBone({super.key, this.width, this.height = 12, this.radius = 6, this.color});
  final double? width;
  final double height;
  final double radius;
  final Color? color;

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(color: color ?? KfColors.surfaceSunken, borderRadius: BorderRadius.circular(radius)),
      );
}

// Liste en cours de chargement (n lignes fantômes)
class KfListSkeleton extends StatelessWidget {
  const KfListSkeleton({super.key, this.rows = 6});
  final int rows;

  @override
  Widget build(BuildContext context) => KfSkeleton(
        child: KfGroup(children: [
          for (var i = 0; i < rows; i++)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: KfSpace.s4, vertical: 14),
              child: Row(children: [
                KfBone(width: 40, height: 40, radius: 20),
                SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    KfBone(width: 140, height: 13),
                    SizedBox(height: 8),
                    KfBone(width: 90, height: 11),
                  ]),
                ),
                KfBone(width: 70, height: 13),
              ]),
            ),
        ]),
      );
}

// État vide : icône dans un rond, message, action éventuelle
class KfEmptyState extends StatelessWidget {
  const KfEmptyState({super.key, required this.icon, required this.title, this.message, this.action, this.onAction});
  final IconData icon;
  final String title;
  final String? message;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: KfSpace.s6, vertical: KfSpace.s8),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(color: KfColors.brandSoft, shape: BoxShape.circle),
            child: Icon(icon, color: KfColors.brand, size: 28),
          ),
          const SizedBox(height: KfSpace.s4),
          Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          if (message != null) ...[
            const SizedBox(height: KfSpace.s1),
            Text(message!, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: KfColors.inkMuted)),
          ],
          if (action != null) ...[
            const SizedBox(height: KfSpace.s4),
            FilledButton(onPressed: onAction, style: FilledButton.styleFrom(minimumSize: const Size(0, 44)), child: Text(action!)),
          ],
        ]),
      );
}

// Pastilles de filtre compactes (onglets de statut)
class KfFilterPills extends StatelessWidget {
  const KfFilterPills({super.key, required this.options, required this.selected, required this.onSelected});
  final List<(String id, String label, int? count)> options;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 36,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: KfSpace.s4),
          itemCount: options.length,
          separatorBuilder: (_, _) => const SizedBox(width: KfSpace.s2),
          itemBuilder: (_, index) {
            final (id, label, count) = options[index];
            final active = id == selected;
            return GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                onSelected(id);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: active ? KfColors.ink : KfColors.surfaceRaised,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: active ? KfColors.ink : KfColors.line),
                ),
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(text: label),
                    if (count != null)
                      TextSpan(
                        text: '  $count',
                        style: TextStyle(color: active ? KfColors.onBrand.withValues(alpha: 0.7) : KfColors.inkMuted),
                      ),
                  ]),
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: active ? KfColors.onBrand : KfColors.ink),
                ),
              ),
            );
          },
        ),
      );
}

// En-tête d'onglet : grand titre, sous-titre, action à droite (remplace la barre d'application)
class KfPageHeader extends StatelessWidget {
  const KfPageHeader({super.key, required this.title, this.subtitle, this.trailing});
  final String title;
  final Widget? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(KfSpace.s4 + 4, MediaQuery.of(context).padding.top + KfSpace.s4, KfSpace.s4, KfSpace.s3),
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontSize: 28, height: 34 / 28, fontWeight: FontWeight.w700, letterSpacing: -0.5)),
              if (subtitle != null) ...[const SizedBox(height: 2), subtitle!],
            ]),
          ),
          ?trailing,
        ]),
      );
}

// Champ de recherche compact
class KfSearchField extends StatelessWidget {
  const KfSearchField({super.key, required this.hint, required this.onChanged});
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: KfSpace.s4),
        child: SizedBox(
          height: 44,
          child: TextField(
            onChanged: onChanged,
            textInputAction: TextInputAction.search,
            style: const TextStyle(fontSize: 15),
            decoration: InputDecoration(
              hintText: hint,
              filled: true,
              fillColor: KfColors.surfaceSunken,
              contentPadding: EdgeInsets.zero,
              prefixIcon: Icon(Icons.search, size: 20, color: KfColors.inkMuted),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(KfRadius.lg), borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(KfRadius.lg), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(KfRadius.lg),
                borderSide: BorderSide(color: KfColors.brand, width: 1.5),
              ),
            ),
          ),
        ),
      );
}

// Champ de saisie avec son libellé au-dessus (comme kf-field du site)
class KfLabeledField extends StatelessWidget {
  const KfLabeledField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.keyboardType,
    this.obscureText = false,
    this.suffix,
    this.enabled = true,
    this.autofillHints,
    this.textInputAction,
    this.onSubmitted,
    this.errorText,
    this.minLines,
    this.maxLines = 1,
    this.onChanged,
    this.textCapitalization = TextCapitalization.none,
  });
  final String label;
  final TextEditingController controller;
  final String? hint;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? suffix;
  final bool enabled;
  final Iterable<String>? autofillHints;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final String? errorText;
  final int? minLines;
  final int? maxLines;
  final ValueChanged<String>? onChanged;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(borderRadius: BorderRadius.circular(KfRadius.lg), borderSide: BorderSide(color: color, width: width));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: KfColors.inkSoft)),
      const SizedBox(height: 6),
      TextField(
        controller: controller,
        enabled: enabled,
        keyboardType: keyboardType,
        obscureText: obscureText,
        autocorrect: !obscureText && keyboardType != TextInputType.emailAddress,
        enableSuggestions: !obscureText,
        autofillHints: autofillHints,
        textInputAction: textInputAction,
        onSubmitted: onSubmitted,
        onChanged: onChanged,
        minLines: minLines,
        maxLines: obscureText ? 1 : maxLines,
        textCapitalization: textCapitalization,
        style: const TextStyle(fontSize: 15),
        decoration: InputDecoration(
          hintText: hint,
          errorText: errorText,
          filled: true,
          fillColor: KfColors.surface,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          suffixIcon: suffix,
          border: border(KfColors.line),
          enabledBorder: border(KfColors.line),
          focusedBorder: border(KfColors.brand, 1.5),
          errorBorder: border(KfColors.danger),
          focusedErrorBorder: border(KfColors.danger, 1.5),
        ),
      ),
    ]);
  }
}

// Bandeau « hors connexion » (en haut de l'écran)
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) => Material(
        color: KfColors.ink,
        borderRadius: BorderRadius.circular(999),
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.wifi_off_rounded, size: 16, color: KfColors.surface),
            const SizedBox(width: 8),
            Text('Hors connexion · dernières données affichées', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: KfColors.surface)),
          ]),
        ),
      );
}

// Ligne de réglage : icône dans une pastille, titre, sous-titre, élément à droite (interrupteur, chevron)
class KfSettingRow extends StatelessWidget {
  const KfSettingRow({super.key, required this.icon, required this.title, this.subtitle, this.trailing, this.onTap, this.danger = false});
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: KfSpace.s4, vertical: 12),
          child: Row(children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: danger ? KfColors.dangerSoft : KfColors.brandSoft, borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, size: 18, color: danger ? KfColors.danger : KfColors.brand),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: danger ? KfColors.danger : KfColors.ink)),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: TextStyle(fontSize: 13, color: KfColors.inkMuted)),
                ],
              ]),
            ),
            if (trailing != null) ...[const SizedBox(width: KfSpace.s2), trailing!]
            else if (onTap != null && !danger)
              Icon(LucideIcons.chevronRight, size: 18, color: KfColors.inkMuted),
          ]),
        ),
      );
}

// Poignée en haut des fenêtres du bas de l'écran
class KfSheetHandle extends StatelessWidget {
  const KfSheetHandle({super.key});

  @override
  Widget build(BuildContext context) => Center(
        child: Container(width: 36, height: 4, decoration: BoxDecoration(color: KfColors.line, borderRadius: BorderRadius.circular(2))),
      );
}

// Sélecteur segmenté (devise, type…) : options côte à côte, l'option choisie en blanc sur fond gris
class KfSegmented extends StatelessWidget {
  const KfSegmented({super.key, required this.options, required this.selected, required this.onChanged, this.enabled = true});
  final List<(String id, String label)> options;
  final String selected;
  final ValueChanged<String> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: KfColors.surfaceSunken, borderRadius: BorderRadius.circular(KfRadius.lg)),
        child: Row(children: [
          for (final (id, label) in options)
            Expanded(
              child: GestureDetector(
                onTap: !enabled || id == selected
                    ? null
                    : () {
                        HapticFeedback.selectionClick();
                        onChanged(id);
                      },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: id == selected ? KfColors.surfaceRaised : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                    boxShadow: id == selected ? [BoxShadow(color: KfColors.ink.withValues(alpha: 0.08), blurRadius: 4, offset: const Offset(0, 1))] : null,
                  ),
                  child: Text(label,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: id == selected ? KfColors.ink : KfColors.inkMuted)),
                ),
              ),
            ),
        ]),
      );
}

// Pastilles de choix sur plusieurs lignes (délai de paiement…)
class KfChoicePills extends StatelessWidget {
  const KfChoicePills({super.key, required this.options, required this.selected, required this.onChanged, this.enabled = true});
  final List<(String id, String label)> options;
  final String selected;
  final ValueChanged<String> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) => Wrap(spacing: KfSpace.s2, runSpacing: KfSpace.s2, children: [
        for (final (id, label) in options)
          GestureDetector(
            onTap: !enabled
                ? null
                : () {
                    HapticFeedback.selectionClick();
                    onChanged(id);
                  },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: id == selected ? KfColors.brandSoft : KfColors.surfaceRaised,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: id == selected ? KfColors.brand : KfColors.line),
              ),
              child: Text(label,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: id == selected ? KfColors.brand : KfColors.ink)),
            ),
          ),
      ]);
}

// Bloc de formulaire : titre de section + carte
class KfFormSection extends StatelessWidget {
  const KfFormSection({super.key, required this.title, required this.child, this.trailing});
  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(KfSpace.s1, KfSpace.s6, KfSpace.s1, KfSpace.s2),
          child: Row(children: [
            Expanded(
              child: Text(title.toUpperCase(),
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.6, color: KfColors.inkMuted)),
            ),
            ?trailing,
          ]),
        ),
        child,
      ]);
}

// Carte blanche arrondie (contenu de formulaire)
class KfCard extends StatelessWidget {
  const KfCard({super.key, required this.child, this.padding = const EdgeInsets.all(KfSpace.s4), this.borderColor});
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(
          color: KfColors.surfaceRaised,
          borderRadius: BorderRadius.circular(KfRadius.lg),
          border: Border.all(color: borderColor ?? KfColors.line),
        ),
        child: child,
      );
}
