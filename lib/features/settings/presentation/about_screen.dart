import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import '../../../shared/widgets/app_icon.dart';
import '../../../shared/widgets/custom_widgets.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../../../core/utils/layout_constants.dart';
import 'app_info_provider.dart';
import 'package:mixstream/l10n/generated/app_localizations.dart';

class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.about),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: ListView(
            padding: const EdgeInsets.symmetric(
              horizontal: LayoutConstants.spacingMd,
              vertical: LayoutConstants.spacingLg,
            ),
            children: [
              _DeveloperHeader(colorScheme: colorScheme, textTheme: textTheme),
              SizedBox(height: LayoutConstants.spacingXxl),
              _AppInfoSection(ref: ref),
              SizedBox(height: LayoutConstants.spacingXxl),
              _BiographySection(colorScheme: colorScheme, textTheme: textTheme),
              SizedBox(height: LayoutConstants.spacingXxl),
              _SkillsSection(colorScheme: colorScheme, textTheme: textTheme),
              SizedBox(height: LayoutConstants.spacingXxl),
              _SpecializationsSection(colorScheme: colorScheme, textTheme: textTheme),
              SizedBox(height: LayoutConstants.spacingXxl),
              _ContactInfoSection(colorScheme: colorScheme, textTheme: textTheme),
              SizedBox(height: LayoutConstants.spacingXxl),
              _ActionButtonsSection(colorScheme: colorScheme),
              SizedBox(height: LayoutConstants.spacingXxl),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final Widget child;

  const _SectionCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(LayoutConstants.radiusXl),
      ),
      child: Padding(
        padding: const EdgeInsets.all(LayoutConstants.spacingLg),
        child: child,
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String icon;
  final String title;
  final ColorScheme colorScheme;

  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: LayoutConstants.spacingMd),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(LayoutConstants.radiusMd),
            ),
            child: AppIcon(icon, size: 20, color: colorScheme.primary),
          ),
          const SizedBox(width: LayoutConstants.spacingSm),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _DeveloperHeader extends StatelessWidget {
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  const _DeveloperHeader({
    required this.colorScheme,
    required this.textTheme,
  });

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      child: Column(
        children: [
          const SizedBox(height: LayoutConstants.spacingSm),
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: colorScheme.primary.withValues(alpha: 0.3),
                width: 4,
              ),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.primary.withValues(alpha: 0.15),
                  blurRadius: 24,
                  spreadRadius: 4,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipOval(
              child: Image.asset(
                'assets/images/developer.png',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    AppIcon('developer', size: 60),
              ),
            ),
          ),
          const SizedBox(height: LayoutConstants.spacingLg),
          Text(
            'Latiful Hassan Zihan',
            style: textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: LayoutConstants.spacingXs),
          Text(
            'Student \u2022 Full-Stack Developer \u2022 Open Source Enthusiast',
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: LayoutConstants.spacingLg),
        ],
      ),
    );
  }
}

class _AppInfoSection extends StatelessWidget {
  final WidgetRef ref;

  const _AppInfoSection({required this.ref});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final appInfoAsync = ref.watch(detailedAppInfoProvider);

    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            icon: 'app-info',
            title: 'About Application',
            colorScheme: colorScheme,
          ),
          appInfoAsync.when(
            data: (info) => Column(
              children: info.toEntries().map((entry) {
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: LayoutConstants.spacingXs - 2,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 140,
                        child: Text(
                          entry.label,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          entry.value,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(LayoutConstants.spacingLg),
                child: AppLoadingIndicator(),
              ),
            ),
            error: (err, stack) => Center(
              child: Padding(
                padding: const EdgeInsets.all(LayoutConstants.spacingLg),
                child: Text(
                  'Failed to load app info',
                  style: TextStyle(color: colorScheme.error),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BiographySection extends StatelessWidget {
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  const _BiographySection({
    required this.colorScheme,
    required this.textTheme,
  });

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            icon: 'developer',
            title: 'Developer Biography',
            colorScheme: colorScheme,
          ),
          const SizedBox(height: LayoutConstants.spacingSm),
          Text(
            'Latiful Hassan Zihan is a student and independent software developer from Bangladesh '
            'with a strong passion for open-source software, Android development, automation, and '
            'modern technologies. He specializes in Python, Flutter, Kotlin, JavaScript, PHP, and '
            'Bash, building efficient, privacy-focused, and user-friendly applications.\n\n'
            'His interests include Android app development, Telegram and Discord bots, AI-powered '
            'applications, Linux, cloud deployment, cybersecurity, and API integrations. He actively '
            'develops tools for media downloading, productivity, streaming, and automation while '
            'contributing to open-source projects.\n\n'
            'Beyond software development, he enjoys exploring Islamic history, emerging technologies, '
            'and continuously learning new skills to create innovative digital solutions.',
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _SkillsSection extends StatelessWidget {
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  const _SkillsSection({
    required this.colorScheme,
    required this.textTheme,
  });

  static const _skills = [
    'Python', 'Flutter', 'Kotlin', 'JavaScript', 'PHP', 'HTML5', 'CSS3',
    'Bash', 'Android SDK', 'Jetpack Compose', 'Git', 'GitHub', 'Linux',
    'REST API', 'Firebase', 'SQLite', 'Room Database', 'AI Integration',
    'Telegram Bot API', 'Discord API',
  ];

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            icon: 'skills',
            title: 'Skills',
            colorScheme: colorScheme,
          ),
          const SizedBox(height: LayoutConstants.spacingSm),
          Wrap(
            spacing: LayoutConstants.spacingXs,
            runSpacing: LayoutConstants.spacingXs,
            children: _skills.map((skill) {
              return Chip(
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(
                  horizontal: LayoutConstants.spacingXs,
                ),
                label: Text(
                  skill,
                  style: textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(LayoutConstants.radiusPill),
                  side: BorderSide(
                    color: colorScheme.primary.withValues(alpha: 0.3),
                  ),
                ),
                backgroundColor: colorScheme.primaryContainer.withValues(alpha: 0.3),
                side: BorderSide.none,
                avatar: Icon(
                  Icons.check,
                  size: 14,
                  color: colorScheme.primary,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _SpecializationsSection extends StatelessWidget {
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  const _SpecializationsSection({
    required this.colorScheme,
    required this.textTheme,
  });

  static const _specializations = [
    _Specialization('Android Application Development', 'android'),
    _Specialization('Cross Platform Apps', 'code'),
    _Specialization('Automation', 'ai-innovation'),
    _Specialization('Telegram Bots', 'telegram'),
    _Specialization('Discord Bots', 'discord'),
    _Specialization('AI Applications', 'ai-brain'),
    _Specialization('Media Downloaders', 'download-square-01'),
    _Specialization('Privacy Focused Software', 'privacy'),
    _Specialization('Open Source Development', 'github'),
  ];

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            icon: 'star',
            title: 'Specializations',
            colorScheme: colorScheme,
          ),
          const SizedBox(height: LayoutConstants.spacingSm),
          ..._specializations.map((spec) {
            return Padding(
              padding: const EdgeInsets.only(bottom: LayoutConstants.spacingSm),
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(LayoutConstants.radiusLg),
                  side: BorderSide(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(
                        LayoutConstants.radiusMd,
                      ),
                    ),
                    child: AppIcon(spec.icon, size: 20, color: colorScheme.primary),
                  ),
                  title: Text(
                    spec.name,
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  trailing: AppIcon(
                    'arrow-right-03',
                    size: 18,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: LayoutConstants.spacingMd,
                    vertical: LayoutConstants.spacingXs,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(LayoutConstants.radiusLg),
                  ),
                  onTap: null,
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _Specialization {
  final String name;
  final String icon;
  const _Specialization(this.name, this.icon);
}

class _ContactInfoSection extends StatelessWidget {
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  const _ContactInfoSection({
    required this.colorScheme,
    required this.textTheme,
  });

  static const _contacts = [
    _ContactItem('Username', 'AlwaysZihan', 'user-account'),
    _ContactItem('Location', 'Bangladesh', 'location'),
    _ContactItem('Email', 'alwayszihan@proton.me', 'email'),
    _ContactItem('GitHub', 'https://github.com/alwayszihanx', 'github'),
    _ContactItem('Telegram', 'https://t.me/alwayszihan', 'telegram'),
    _ContactItem('Instagram', 'https://instagram.com/alwayszihan', 'instagram'),
    _ContactItem('Facebook', 'https://facebook.com/alwayszihan', 'facebook'),
    _ContactItem('License', 'MIT License', 'license'),
  ];

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            icon: 'user-account',
            title: 'Developer Information',
            colorScheme: colorScheme,
          ),
          const SizedBox(height: LayoutConstants.spacingSm),
          ..._contacts.map((contact) {
            final isUrl = contact.value.startsWith('http');
            return Padding(
              padding: const EdgeInsets.symmetric(
                vertical: LayoutConstants.spacingXs - 2,
              ),
              child: InkWell(
                onTap: isUrl
                    ? () => launchUrl(
                          Uri.parse(contact.value),
                          mode: LaunchMode.externalApplication,
                        )
                    : null,
                borderRadius: BorderRadius.circular(LayoutConstants.radiusMd),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: LayoutConstants.spacingXs - 4,
                    horizontal: LayoutConstants.spacingXs - 4,
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(
                            LayoutConstants.radiusMd,
                          ),
                        ),
                        child: AppIcon(
                          contact.icon,
                          size: 16,
                          color: colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: LayoutConstants.spacingSm),
                      SizedBox(
                        width: 80,
                        child: Text(
                          contact.label,
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          contact.value,
                          style: textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                            color: isUrl ? colorScheme.primary : null,
                          ),
                        ),
                      ),
                      if (isUrl)
                        AppIcon(
                          'open-in-new-rounded',
                          size: 14,
                          color: colorScheme.primary,
                        ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _ContactItem {
  final String label;
  final String value;
  final String icon;
  const _ContactItem(this.label, this.value, this.icon);
}

class _ActionButtonsSection extends StatelessWidget {
  final ColorScheme colorScheme;

  const _ActionButtonsSection({required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: LayoutConstants.spacingMd),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(LayoutConstants.radiusMd),
                ),
                child: AppIcon('share', size: 20, color: colorScheme.primary),
              ),
              const SizedBox(width: LayoutConstants.spacingSm),
              Text(
                'Actions',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        _ActionButton(
          icon: 'github',
          label: 'GitHub',
          color: const Color(0xFF333333),
          onTap: () => launchUrl(
            Uri.parse('https://github.com/alwayszihanx'),
            mode: LaunchMode.externalApplication,
          ),
        ),
        const SizedBox(height: LayoutConstants.spacingSm),
        _ActionButton(
          icon: 'telegram',
          label: 'Telegram',
          color: const Color(0xFF0088CC),
          onTap: () => launchUrl(
            Uri.parse('https://t.me/alwayszihan'),
            mode: LaunchMode.externalApplication,
          ),
        ),
        const SizedBox(height: LayoutConstants.spacingSm),
        _ActionButton(
          icon: 'instagram',
          label: 'Instagram',
          color: const Color(0xFFE4405F),
          onTap: () => launchUrl(
            Uri.parse('https://instagram.com/alwayszihan'),
            mode: LaunchMode.externalApplication,
          ),
        ),
        const SizedBox(height: LayoutConstants.spacingSm),
        _ActionButton(
          icon: 'facebook',
          label: 'Facebook',
          color: const Color(0xFF1877F2),
          onTap: () => launchUrl(
            Uri.parse('https://facebook.com/alwayszihan'),
            mode: LaunchMode.externalApplication,
          ),
        ),
        const SizedBox(height: LayoutConstants.spacingSm),
        _ActionButton(
          icon: 'email',
          label: 'Email',
          color: const Color(0xFFEA4335),
          onTap: () => launchUrl(
            Uri.parse('mailto:alwayszihan@proton.me'),
            mode: LaunchMode.externalApplication,
          ),
        ),
        const SizedBox(height: LayoutConstants.spacingSm),
        _ActionButton(
          icon: 'share',
          label: 'Share App',
          color: colorScheme.primary,
          onTap: () => _shareApp(context),
        ),
        const SizedBox(height: LayoutConstants.spacingSm),
        _ActionButton(
          icon: 'refresh',
          label: 'Check Update',
          color: colorScheme.tertiary,
          onTap: () => launchUrl(
            Uri.parse('https://github.com/alwayszihanx/MixStream'),
            mode: LaunchMode.externalApplication,
          ),
        ),
        const SizedBox(height: LayoutConstants.spacingSm),
        _ActionButton(
          icon: 'copy',
          label: 'Copy Version',
          color: colorScheme.secondary,
          onTap: () => _copyVersion(context),
        ),
      ],
    );
  }

  void _shareApp(BuildContext context) {
    final text = 'Check out MixStream!\nhttps://github.com/alwayszihanx/MixStream';
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Link copied to clipboard')),
    );
  }

  Future<void> _copyVersion(BuildContext context) async {
    final info = await PackageInfo.fromPlatform();
    final version = '${info.version}+${info.buildNumber}';
    Clipboard.setData(ClipboardData(text: version));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Version $version copied to clipboard')),
      );
    }
  }
}

class _ActionButton extends StatelessWidget {
  final String icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: CustomButton(
        onPressed: onTap,
        padding: ButtonDesign.padding,
        child: Row(
          children: [
            AppIcon(icon, size: 20, color: color),
            const SizedBox(width: LayoutConstants.spacingSm),
            Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
