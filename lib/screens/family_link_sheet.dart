import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/vault.dart';
import '../models/family_gallery.dart';
import '../services/share_service.dart';
import '../theme/app_theme.dart';

/// Bottom sheet for the owner's permanent family-gallery link: set the baby's
/// name/birthdate (for age labels), copy/share the one link everyone uses, and
/// turn it on or off.
Future<void> showFamilyLinkSheet(BuildContext context, Vault vault) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppTheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => _FamilyLinkSheet(vault: vault),
  );
}

class _FamilyLinkSheet extends StatefulWidget {
  final Vault vault;
  const _FamilyLinkSheet({required this.vault});

  @override
  State<_FamilyLinkSheet> createState() => _FamilyLinkSheetState();
}

class _FamilyLinkSheetState extends State<_FamilyLinkSheet> {
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController =
        TextEditingController(text: widget.vault.gallery?.babyName ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickBirthdate(FamilyGallery g) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: g.birthdate ?? DateTime(now.year, now.month, now.day),
      firstDate: DateTime(now.year - 18),
      lastDate: now,
      helpText: "Baby's date of birth",
    );
    if (picked != null) {
      await widget.vault.setBabyProfile(birthdate: picked);
      if (mounted) setState(() {});
    }
  }

  Future<void> _saveName() async {
    await widget.vault.setBabyProfile(name: _nameController.text);
  }

  String _formatDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final g = widget.vault.gallery;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: AppTheme.textMuted.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text('Family gallery link',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            const Text(
              'One link for everyone — grandma, auntie, all of them. They open it '
              'to browse every photo, sorted by date and age. New photos appear '
              'automatically.',
              style: TextStyle(color: AppTheme.textMuted, height: 1.4),
            ),
            const SizedBox(height: 18),
            if (g == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              _babyProfile(g),
              const SizedBox(height: 18),
              _linkRow(g),
              const SizedBox(height: 14),
              _shareTargets(g),
              const SizedBox(height: 8),
              const Text(
                'Messenger & Instagram DM: tap “More…”, or copy the link and '
                'paste it into the chat.',
                style: TextStyle(
                    color: AppTheme.textMuted, fontSize: 12, height: 1.4),
              ),
              const Divider(height: 32),
              _activeToggle(g),
            ],
          ],
        ),
      ),
    );
  }

  Widget _babyProfile(FamilyGallery g) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _nameController,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.done,
          onEditingComplete: _saveName,
          onSubmitted: (_) => _saveName(),
          decoration: const InputDecoration(
            labelText: "Baby's name",
            hintText: 'e.g. Aria',
            filled: true,
            fillColor: AppTheme.surfaceHigh,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(14)),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 10),
        InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _pickBirthdate(g),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
            decoration: BoxDecoration(
              color: AppTheme.surfaceHigh,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(Icons.cake_outlined,
                    size: 20, color: AppTheme.textMuted),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    g.birthdate == null
                        ? 'Set date of birth (for age labels)'
                        : 'Born ${_formatDate(g.birthdate!)}',
                    style: TextStyle(
                      color: g.birthdate == null
                          ? AppTheme.textMuted
                          : Colors.white,
                    ),
                  ),
                ),
                const Icon(Icons.edit_calendar_outlined,
                    size: 18, color: AppTheme.textMuted),
              ],
            ),
          ),
        ),
        if (g.birthdate == null)
          const Padding(
            padding: EdgeInsets.only(top: 6, left: 4),
            child: Text(
              'Without a birthdate, photos still show but without the age badge.',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
            ),
          ),
      ],
    );
  }

  Widget _linkRow(FamilyGallery g) {
    final url = ShareService.galleryLinkFor(g.token);
    return Opacity(
      opacity: g.active ? 1 : 0.5,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surfaceHigh,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            const Icon(Icons.link_rounded, color: AppTheme.mint, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                url,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.copy_rounded, size: 18),
              tooltip: 'Copy link',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: url));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Link copied')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _shareTargets(FamilyGallery g) {
    final enabled = g.active;
    final baby = g.babyName;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _target(
          'WhatsApp',
          Icons.chat_rounded,
          const Color(0xFF25D366),
          enabled
              ? () => ShareService.shareGalleryToWhatsApp(g.token, baby)
              : null,
        ),
        _target(
          'Telegram',
          Icons.send_rounded,
          const Color(0xFF29A9EA),
          enabled
              ? () => ShareService.shareGalleryToTelegram(g.token, baby)
              : null,
        ),
        _target(
          'More…',
          Icons.ios_share_rounded,
          AppTheme.secondary,
          enabled
              ? () => ShareService.shareGalleryViaSystem(g.token, baby)
              : null,
        ),
      ],
    );
  }

  Widget _activeToggle(FamilyGallery g) {
    return SwitchListTile(
      value: g.active,
      onChanged: (v) async {
        await widget.vault.setGalleryActive(v);
        if (mounted) setState(() {});
      },
      activeColor: AppTheme.primary,
      contentPadding: EdgeInsets.zero,
      title: Text(g.active ? 'Link is active' : 'Link is turned off'),
      subtitle: Text(
        g.active
            ? 'Anyone with the link can view the gallery.'
            : 'The link is revoked — no one can open it until you turn it back on.',
        style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
      ),
    );
  }

  Widget _target(
      String label, IconData icon, Color color, VoidCallback? onTap) {
    return Opacity(
      opacity: onTap == null ? 0.4 : 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(icon, color: color, size: 26),
              ),
              const SizedBox(height: 8),
              Text(label, style: const TextStyle(fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}
