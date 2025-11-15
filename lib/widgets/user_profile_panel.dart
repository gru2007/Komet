import 'package:flutter/material.dart';
import 'package:gwid/services/avatar_cache_service.dart';




class UserProfilePanel extends StatefulWidget {
  final int userId;
  final String? name;
  final String? firstName;
  final String? lastName;
  final String? avatarUrl;
  final String? description;
  final int myId;
  final int? currentChatId;
  final Map<String, dynamic>? contactData;
  final int? dialogChatId;

  const UserProfilePanel({
    super.key,
    required this.userId,
    this.name,
    this.firstName,
    this.lastName,
    this.avatarUrl,
    this.description,
    required this.myId,
    this.currentChatId,
    this.contactData,
    this.dialogChatId,
  });

  @override
  State<UserProfilePanel> createState() => _UserProfilePanelState();
}

class _UserProfilePanelState extends State<UserProfilePanel> {
  final ScrollController _nameScrollController = ScrollController();



  String get _displayName {
    if (widget.firstName != null || widget.lastName != null) {
      final firstName = widget.firstName ?? '';
      final lastName = widget.lastName ?? '';
      final fullName = '$firstName $lastName'.trim();
      return fullName.isNotEmpty ? fullName : (widget.name ?? 'Неизвестный');
    }
    return widget.name ?? 'Неизвестный';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkNameLength();
    });
  }

  void _checkNameLength() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_nameScrollController.hasClients) {
        final maxScroll = _nameScrollController.position.maxScrollExtent;
        if (maxScroll > 0) {
          _startNameScroll();
        }
      }
    });
  }

  void _startNameScroll() {
    if (!_nameScrollController.hasClients) return;

    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted || !_nameScrollController.hasClients) return;

      _nameScrollController
          .animateTo(
            _nameScrollController.position.maxScrollExtent,
            duration: const Duration(seconds: 3),
            curve: Curves.easeInOut,
          )
          .then((_) {
            if (!mounted) return;
            Future.delayed(const Duration(seconds: 1), () {
              if (!mounted || !_nameScrollController.hasClients) return;
              _nameScrollController
                  .animateTo(
                    0,
                    duration: const Duration(seconds: 3),
                    curve: Curves.easeInOut,
                  )
                  .then((_) {
                    if (mounted) {
                      Future.delayed(const Duration(seconds: 2), () {
                        if (mounted) _startNameScroll();
                      });
                    }
                  });
            });
          });
    });
  }

  @override
  void dispose() {
    _nameScrollController.dispose();
    super.dispose();
  }





















































































































  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: colors.onSurfaceVariant.withOpacity(0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                AvatarCacheService().getAvatarWidget(
                  widget.avatarUrl,
                  userId: widget.userId,
                  size: 80,
                  fallbackText: _displayName,
                  backgroundColor: colors.primaryContainer,
                  textColor: colors.onPrimaryContainer,
                ),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final textPainter = TextPainter(
                      text: TextSpan(
                        text: _displayName,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      maxLines: 1,
                      textDirection: TextDirection.ltr,
                    );
                    textPainter.layout();
                    final textWidth = textPainter.size.width;
                    final needsScroll = textWidth > constraints.maxWidth;

                    if (needsScroll) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _checkNameLength();
                      });
                      return SizedBox(
                        height: 28,
                        child: SingleChildScrollView(
                          controller: _nameScrollController,
                          scrollDirection: Axis.horizontal,
                          physics: const NeverScrollableScrollPhysics(),
                          child: Text(
                            _displayName,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    } else {
                      return Text(
                        _displayName,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                      );
                    }
                  },
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildActionButton(
                      icon: Icons.phone,
                      label: 'Позвонить',
                      onPressed: null,
                      colors: colors,
                    ),
                    _buildActionButton(
                      icon: Icons.person_add,
                      label: 'В контакты',
                      onPressed: null,
                      colors: colors,
                    ),
                    _buildActionButton(
                      icon: Icons.message,
                      label: 'Написать',
                      onPressed: null,
                      colors: colors,
                    ),
                  ],
                ),
                if (widget.description != null &&
                    widget.description!.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Text(
                    widget.description!,
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
                SizedBox(height: MediaQuery.of(context).padding.bottom),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    required ColorScheme colors,
    bool isLoading = false,
  }) {
    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: colors.primaryContainer,
            shape: BoxShape.circle,
          ),
          child: isLoading
              ? Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
                    ),
                  ),
                )
              : IconButton(
                  icon: Icon(icon, color: colors.primary),
                  onPressed: onPressed,
                ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
        ),
      ],
    );
  }
}
