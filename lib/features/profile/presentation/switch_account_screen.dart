import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/widgets/app_icon.dart';
import '../../../../shared/widgets/loading_indicator.dart';
import 'profile_provider.dart';

class SwitchAccountScreen extends ConsumerStatefulWidget {
  const SwitchAccountScreen({super.key});

  static Future<void> show(BuildContext context) async {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const SwitchAccountScreen(),
    );
  }

  @override
  ConsumerState<SwitchAccountScreen> createState() => _SwitchAccountScreenState();
}

class _SwitchAccountScreenState extends ConsumerState<SwitchAccountScreen> {
  List<Map<String, dynamic>> _profiles = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfiles();
  }

  Future<void> _loadProfiles() async {
    final profiles = await ref.read(userProfileProvider.notifier).getAllProfiles();
    if (mounted) {
      setState(() {
        _profiles = profiles;
        _isLoading = false;
      });
    }
  }

  void _showCreateProfileDialog() {
    final controller = TextEditingController();
    int selectedColor = 0;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('New Profile'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Profile name',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),
              Text(
                'Choose color',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: List.generate(
                  UserProfileData.avatarColors.length,
                  (index) {
                    final color = UserProfileData.avatarColors[index];
                    final isSelected = selectedColor == index;
                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        setDialogState(() => selectedColor = index);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: isSelected
                              ? Border.all(color: Colors.white, width: 3)
                              : null,
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: color.withValues(alpha: 0.5),
                                    blurRadius: 12,
                                    spreadRadius: 2,
                                  ),
                                ]
                              : null,
                        ),
                        child: isSelected
                            ? const Icon(Icons.check, color: Colors.white, size: 18)
                            : null,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (controller.text.trim().isNotEmpty) {
                  ref.read(userProfileProvider.notifier).createProfile(
                        controller.text.trim(),
                        selectedColor,
                      );
                  Navigator.pop(ctx);
                  _loadProfiles();
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentProfile = ref.watch(userProfileProvider);
    final cs = Theme.of(context).colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.85,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(24),
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: cs.onSurface.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Center(
                child: Text(
                  'Switch Profile',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 24),
              if (_isLoading)
                const Center(child: AppLoadingIndicator())
              else ...[
                ..._profiles.map((profile) {
                  final isCurrent = (profile['name'] as String?) == currentProfile.name;
                  final colorIndex = (profile['colorIndex'] as int?) ?? 0;
                  final color = UserProfileData.avatarColors[colorIndex % UserProfileData.avatarColors.length];
                  final avatarIndex = (profile['avatarIndex'] as int?) ?? 0;
                  final avatarIcon = UserProfileData.avatarIcons[avatarIndex % UserProfileData.avatarIcons.length];
                  final imagePath = profile['imagePath'] as String?;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        radius: 24,
                        backgroundColor: color,
                        backgroundImage: imagePath != null && imagePath.isNotEmpty
                            ? NetworkImage(imagePath)
                            : null,
                        child: imagePath == null || imagePath.isEmpty
                            ? AppIcon(avatarIcon, size: 22, color: Colors.white)
                            : null,
                      ),
                      title: Row(
                        children: [
                          Text(
                            (profile['name'] as String?) ?? 'User',
                            style: TextStyle(
                              fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          if (isCurrent) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: cs.primary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Current',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: cs.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      trailing: _profiles.length > 1
                          ? IconButton(
                              icon: const AppIcon('delete_outline_rounded', size: 20),
                              color: cs.error.withValues(alpha: 0.7),
                              onPressed: () async {
                                await ref.read(userProfileProvider.notifier).deleteProfile(profile['id'] as String);
                                _loadProfiles();
                              },
                            )
                          : null,
                      onTap: isCurrent
                          ? null
                          : () async {
                              await ref.read(userProfileProvider.notifier).switchToProfile(profile['id'] as String);
                              _loadProfiles();
                            },
                    ),
                  );
                }),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _showCreateProfileDialog,
                  icon: const AppIcon('add_rounded', size: 18),
                  label: const Text('Add Profile'),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
