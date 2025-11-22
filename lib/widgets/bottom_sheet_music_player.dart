import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/music_player_service.dart';

class BottomSheetMusicPlayer extends StatefulWidget {
  const BottomSheetMusicPlayer({super.key});

  static final ValueNotifier<bool> isExpandedNotifier = ValueNotifier<bool>(
    false,
  );

  @override
  State<BottomSheetMusicPlayer> createState() => _BottomSheetMusicPlayerState();
}

class _BottomSheetMusicPlayerState extends State<BottomSheetMusicPlayer>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    BottomSheetMusicPlayer.isExpandedNotifier.addListener(_onExpandedChanged);
  }

  void _onExpandedChanged() {
    final shouldBeExpanded = BottomSheetMusicPlayer.isExpandedNotifier.value;
    if (shouldBeExpanded != _isExpanded) {
      setState(() {
        _isExpanded = shouldBeExpanded;
        if (_isExpanded) {
          _animationController.forward();
        } else {
          _animationController.reverse();
        }
      });
    }
  }

  @override
  void dispose() {
    BottomSheetMusicPlayer.isExpandedNotifier.removeListener(
      _onExpandedChanged,
    );
    _animationController.dispose();
    super.dispose();
  }

  void _toggleExpand() {
    setState(() {
      _isExpanded = !_isExpanded;
      BottomSheetMusicPlayer.isExpandedNotifier.value = _isExpanded;
      if (_isExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${twoDigits(hours)}:${twoDigits(minutes)}:${twoDigits(seconds)}';
    }
    return '${twoDigits(minutes)}:${twoDigits(seconds)}';
  }

  @override
  Widget build(BuildContext context) {
    final musicPlayer = context.watch<MusicPlayerService>();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final track = musicPlayer.currentTrack;

    if (track == null) {
      return const SizedBox.shrink();
    }

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        final screenHeight = MediaQuery.of(context).size.height;
        final collapsedHeight = 100.0;
        final expandedHeight = screenHeight * 0.75;
        final animationValue = Curves.easeInOut.transform(
          _animationController.value,
        );
        final currentHeight =
            collapsedHeight +
            (expandedHeight - collapsedHeight) * animationValue;

        return Material(
          color: Colors.transparent,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            height: currentHeight,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(24),
                topRight: const Radius.circular(24),
                bottomLeft: Radius.circular(24 * (1 - animationValue)),
                bottomRight: Radius.circular(24 * (1 - animationValue)),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 12,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: _buildAnimatedContent(
              context,
              musicPlayer,
              track,
              colorScheme,
            ),
          ),
        );
      },
    );
  }

  Widget _buildAnimatedContent(
    BuildContext context,
    MusicPlayerService musicPlayer,
    MusicTrack track,
    ColorScheme colorScheme,
  ) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      switchInCurve: Curves.easeInOut,
      switchOutCurve: Curves.easeInOut,
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position:
                Tween<Offset>(
                  begin: const Offset(0.0, 0.1),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(parent: animation, curve: Curves.easeInOut),
                ),
            child: child,
          ),
        );
      },
      child: _isExpanded
          ? _buildExpandedView(context, musicPlayer, track, colorScheme)
          : _buildCollapsedView(context, musicPlayer, track, colorScheme),
    );
  }

  Widget _buildCollapsedView(
    BuildContext context,
    MusicPlayerService musicPlayer,
    MusicTrack track,
    ColorScheme colorScheme,
  ) {
    return SafeArea(
      key: const ValueKey('collapsed'),
      top: false,
      child: GestureDetector(
        onTap: _toggleExpand,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 48,
                  height: 48,
                  color: colorScheme.primaryContainer,
                  child: track.albumArtUrl != null
                      ? Image.network(
                          track.albumArtUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              _buildAlbumArtPlaceholder(colorScheme),
                        )
                      : _buildAlbumArtPlaceholder(colorScheme),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      track.title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      track.artist,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface.withOpacity(0.7),
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  if (musicPlayer.isPlaying) {
                    musicPlayer.pause();
                  } else {
                    musicPlayer.resume();
                  }
                },
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    musicPlayer.isPlaying ? Icons.pause : Icons.play_arrow,
                    size: 24,
                    color: colorScheme.onPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExpandedView(
    BuildContext context,
    MusicPlayerService musicPlayer,
    MusicTrack track,
    ColorScheme colorScheme,
  ) {
    return SafeArea(
      key: const ValueKey('expanded'),
      top: false,
      child: Column(
        children: [
          GestureDetector(
            onTap: _toggleExpand,
            onVerticalDragEnd: (details) {
              if (details.primaryVelocity != null &&
                  details.primaryVelocity! > 200) {
                _toggleExpand();
              }
            },
            child: Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.symmetric(vertical: 12),
              width: double.infinity,
              child: Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.onSurface.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final maxWidth = constraints.maxWidth;
                        final albumSize = maxWidth < 400 ? maxWidth : 400.0;
                        return Container(
                          width: albumSize,
                          height: albumSize,
                          margin: EdgeInsets.symmetric(
                            horizontal: (maxWidth - albumSize) / 2,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: track.albumArtUrl != null
                                ? Image.network(
                                    track.albumArtUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (context, error, stackTrace) =>
                                            _buildLargeAlbumArtPlaceholder(
                                              context,
                                              colorScheme,
                                            ),
                                  )
                                : _buildLargeAlbumArtPlaceholder(
                                    context,
                                    colorScheme,
                                  ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    Text(
                      track.title,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      track.artist,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: colorScheme.onSurface.withOpacity(0.7),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (track.album != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        track.album!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurface.withOpacity(0.6),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: 32),
                    Column(
                      children: [
                        Slider(
                          value: musicPlayer.duration.inMilliseconds > 0
                              ? musicPlayer.position.inMilliseconds /
                                    musicPlayer.duration.inMilliseconds
                              : 0.0,
                          onChanged: (value) {
                            final newPosition = Duration(
                              milliseconds:
                                  (value * musicPlayer.duration.inMilliseconds)
                                      .round(),
                            );
                            musicPlayer.seek(newPosition);
                          },
                          activeColor: colorScheme.primary,
                          inactiveColor: colorScheme.surfaceContainerHigh,
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _formatDuration(musicPlayer.position),
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: colorScheme.onSurface.withOpacity(
                                        0.7,
                                      ),
                                    ),
                              ),
                              Text(
                                _formatDuration(musicPlayer.duration),
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: colorScheme.onSurface.withOpacity(
                                        0.7,
                                      ),
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          onPressed: musicPlayer.previous,
                          icon: const Icon(Icons.skip_previous),
                          iconSize: 32,
                          style: IconButton.styleFrom(
                            backgroundColor: colorScheme.surfaceContainerHigh,
                            foregroundColor: colorScheme.onSurface,
                            padding: const EdgeInsets.all(16),
                          ),
                        ),
                        const SizedBox(width: 16),
                        FilledButton(
                          onPressed: () {
                            if (musicPlayer.isPlaying) {
                              musicPlayer.pause();
                            } else {
                              musicPlayer.resume();
                            }
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: colorScheme.primary,
                            foregroundColor: colorScheme.onPrimary,
                            padding: const EdgeInsets.all(20),
                            shape: const CircleBorder(),
                            minimumSize: const Size(72, 72),
                          ),
                          child: musicPlayer.isLoading
                              ? SizedBox(
                                  width: 32,
                                  height: 32,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 3,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      colorScheme.onPrimary,
                                    ),
                                  ),
                                )
                              : Icon(
                                  musicPlayer.isPlaying
                                      ? Icons.pause
                                      : Icons.play_arrow,
                                  size: 36,
                                ),
                        ),
                        const SizedBox(width: 16),
                        IconButton(
                          onPressed: musicPlayer.next,
                          icon: const Icon(Icons.skip_next),
                          iconSize: 32,
                          style: IconButton.styleFrom(
                            backgroundColor: colorScheme.surfaceContainerHigh,
                            foregroundColor: colorScheme.onSurface,
                            padding: const EdgeInsets.all(16),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlbumArtPlaceholder(ColorScheme colorScheme) {
    return Container(
      color: colorScheme.primaryContainer,
      child: Icon(
        Icons.music_note,
        color: colorScheme.onPrimaryContainer,
        size: 28,
      ),
    );
  }

  Widget _buildLargeAlbumArtPlaceholder(
    BuildContext context,
    ColorScheme colorScheme,
  ) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: colorScheme.primaryContainer,
      child: Icon(
        Icons.music_note,
        color: colorScheme.onPrimaryContainer,
        size: 80,
      ),
    );
  }
}
