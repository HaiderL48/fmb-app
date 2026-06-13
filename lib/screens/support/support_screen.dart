import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../apis/api_manager.dart';
import '../../constants/colors.dart';
import '../../constants/styles.dart';
import '../../providers/auth/user_data_provider.dart';
import '../../widgets/app_header.dart';
import '../../widgets/app_logo_loader.dart';

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  bool _loading = true;
  bool _hasLoadedOnce = false;
  String? _error;
  List<Map<String, dynamic>> _contacts = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final token = context.read<UserDataProvider>().token;
    if (token.trim().isEmpty) {
      setState(() {
        _loading = false;
        _hasLoadedOnce = true;
        _contacts = const [];
      });
      return;
    }
    try {
      final res = await ApiManager.getContactInfo(token: token);
      if (!mounted) return;
      setState(() {
        final data = res['data'];
        if (data is List) {
          _contacts = data
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        } else {
          _contacts = const [];
        }
        _loading = false;
        _hasLoadedOnce = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
        _hasLoadedOnce = true;
      });
    }
  }

  String _cleanPhone(String s) => s.replaceAll(RegExp(r'\s+'), ' ').trim();

  Future<void> _launch(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final sorted = [..._contacts]
      ..sort((a, b) {
        final sa = (a['sortOrder'] is num)
            ? (a['sortOrder'] as num).toInt()
            : 0;
        final sb = (b['sortOrder'] is num)
            ? (b['sortOrder'] as num).toInt()
            : 0;
        if (sa != sb) return sa.compareTo(sb);
        final na = (a['name'] ?? '').toString();
        final nb = (b['name'] ?? '').toString();
        return na.compareTo(nb);
      });

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          AppHeader(
            title: 'Support',
            leadingIcon: Icons.arrow_back_rounded,
            showSupport: false,
            showNotifications: false,
            showLogout: false,
            extraActions: [
              IconButton(
                onPressed: _loading ? null : _load,
                icon: const Icon(
                  Icons.refresh_rounded,
                  color: AppColors.fmbAccent,
                ),
              ),
            ],
          ),
          Expanded(
            child: _loading
                ? (_hasLoadedOnce
                      ? RefreshIndicator(
                          onRefresh: _load,
                          color: AppColors.fmbPrimary,
                          child: _SupportList(
                            error: _error,
                            contacts: sorted,
                            cleanPhone: _cleanPhone,
                            launch: _launch,
                          ),
                        )
                      : const Center(child: AppLogoLoader()))
                : RefreshIndicator(
                    onRefresh: _load,
                    color: AppColors.fmbPrimary,
                    child: _SupportList(
                      error: _error,
                      contacts: sorted,
                      cleanPhone: _cleanPhone,
                      launch: _launch,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

enum _Tone { info, error }

class _SupportList extends StatelessWidget {
  const _SupportList({
    required this.error,
    required this.contacts,
    required this.cleanPhone,
    required this.launch,
  });

  final String? error;
  final List<Map<String, dynamic>> contacts;
  final String Function(String value) cleanPhone;
  final Future<void> Function(String url) launch;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (error != null) ...[
          _InfoCard(
            title: 'Could not load contact info',
            body: 'Using fallback support details for now.\n\n$error',
            tone: _Tone.error,
          ),
          const SizedBox(height: 12),
        ],
        _InfoCard(
          title: 'Get in touch',
          body: 'Reach out to our support team using the options below.',
          tone: _Tone.info,
        ),
        const SizedBox(height: 12),
        if (contacts.isEmpty) ...[
          _ActionTile(
            icon: Icons.phone_outlined,
            title: 'Phone',
            subtitle: '+965 1234 5678',
            onTap: () => launch('tel:+96512345678'),
          ),
        ] else ...[
          for (final c in contacts) ...[
            _SupportContactTile(
              purpose: (c['contactPurpose'] ?? '').toString().trim(),
              name: (c['name'] ?? '').toString().trim(),
              contactNumber: cleanPhone((c['contactNumber'] ?? '').toString()),
              onCall: () => launch(
                'tel:${(c['contactNumber'] ?? '').toString().replaceAll(RegExp(r'\s+'), '')}',
              ),
              onWhatsApp: () => launch(
                'https://wa.me/${(c['contactNumber'] ?? '').toString().replaceAll(RegExp(r'\D'), '')}',
              ),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.title,
    required this.body,
    required this.tone,
  });

  final String title;
  final String body;
  final _Tone tone;

  @override
  Widget build(BuildContext context) {
    final bg = tone == _Tone.error
        ? AppColors.errorBackground
        : AppColors.infoBackground;
    final border = tone == _Tone.error
        ? AppColors.errorBorder
        : AppColors.infoBorder;
    final fg = tone == _Tone.error ? AppColors.errorText : AppColors.infoText;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTextStyle.h4.copyWith(
              color: fg,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: AppTextStyle.bodySm.copyWith(color: fg, height: 1.35),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      borderRadius: AppRadius.mdAll,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.mdAll,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: AppRadius.mdAll,
            border: Border.all(color: AppColors.border),
            boxShadow: AppShadow.sm,
          ),
          child: Row(
            children: [
              Icon(icon, color: AppColors.fmbPrimary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTextStyle.bodySm.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AppTextStyle.bodyXs.copyWith(
                        color: AppColors.gray600,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.gray500),
            ],
          ),
        ),
      ),
    );
  }
}

class _SupportContactTile extends StatelessWidget {
  const _SupportContactTile({
    required this.purpose,
    required this.name,
    required this.contactNumber,
    required this.onCall,
    required this.onWhatsApp,
  });

  final String purpose;
  final String name;
  final String contactNumber;
  final VoidCallback onCall;
  final VoidCallback onWhatsApp;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      borderRadius: AppRadius.mdAll,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: AppRadius.mdAll,
          border: Border.all(color: AppColors.border),
          boxShadow: AppShadow.sm,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Icon(
                Icons.support_agent_rounded,
                color: AppColors.fmbPrimary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (purpose.isNotEmpty)
                    Text(
                      purpose,
                      style: AppTextStyle.bodyXs.copyWith(
                        color: AppColors.gray600,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  Text(
                    name.isNotEmpty ? name : 'Support',
                    style: AppTextStyle.bodySm.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    contactNumber,
                    style: AppTextStyle.bodyXs.copyWith(
                      color: AppColors.gray600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _MiniActionButton(
                        icon: Icons.call_rounded,
                        label: 'Call',
                        onTap: onCall,
                      ),
                      const SizedBox(width: 10),
                      _MiniActionButton(
                        icon: Icons.chat_bubble_outline_rounded,
                        label: 'WhatsApp',
                        onTap: onWhatsApp,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniActionButton extends StatelessWidget {
  const _MiniActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: SizedBox(
        height: 40,
        child: OutlinedButton.icon(
          onPressed: onTap,
          icon: Icon(icon, size: 18, color: AppColors.fmbPrimary),
          label: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.fmbPrimary,
            ),
          ),
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: AppColors.border),
            shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
            backgroundColor: AppColors.background,
          ),
        ),
      ),
    );
  }
}
