import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';
import 'news_screen.dart';
import 'profile_screen.dart';
import 'studio_screen.dart';
import 'trend_screen.dart';
import 'upload_screen.dart';

/// 앱 셸 — 5탭 구조 + 글래스 하단 내비게이션
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  static const _items = [
    _NavItem('뉴스', Icons.newspaper_outlined, Icons.newspaper_rounded,
        AppColors.neonCyan),
    _NavItem('트렌드', Icons.local_fire_department_outlined,
        Icons.local_fire_department_rounded, AppColors.neonAmber),
    _NavItem('스튜디오', Icons.movie_creation_outlined,
        Icons.movie_creation_rounded, AppColors.neonMagenta),
    _NavItem('업로드', Icons.cloud_upload_outlined, Icons.cloud_upload_rounded,
        AppColors.neonPurple),
    _NavItem('내정보', Icons.person_outline_rounded, Icons.person_rounded,
        AppColors.neonLime),
  ];

  void goTo(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      extendBody: true,
      body: Stack(
        children: [
          // 배경 네온 블룸
          const _AmbientGlow(),
          SafeArea(
            bottom: false,
            child: IndexedStack(
              index: _index,
              children: [
                NewsScreen(onNavigate: goTo),
                TrendScreen(onNavigate: goTo),
                StudioScreen(onNavigate: goTo),
                UploadScreen(onNavigate: goTo),
                ProfileScreen(onNavigate: goTo),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _GlassNavBar(
        items: _items,
        index: _index,
        onTap: goTo,
      ),
    );
  }
}

class _NavItem {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final Color color;
  const _NavItem(this.label, this.icon, this.activeIcon, this.color);
}

/// 배경 앰비언트 글로우 — 심야의 방 조명
class _AmbientGlow extends StatelessWidget {
  const _AmbientGlow();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          children: [
            Positioned(
              top: -110,
              left: -80,
              child: _blob(AppColors.neonMagenta, 300, 0.16),
            ),
            Positioned(
              top: 140,
              right: -110,
              child: _blob(AppColors.neonCyan, 280, 0.13),
            ),
            Positioned(
              bottom: -60,
              left: 30,
              child: _blob(AppColors.neonPurple, 260, 0.10),
            ),
          ],
        ),
      ),
    );
  }

  Widget _blob(Color c, double size, double opacity) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [c.withValues(alpha: opacity), c.withValues(alpha: 0)],
        ),
      ),
    );
  }
}

/// 글래스 하단 내비게이션 바
class _GlassNavBar extends StatelessWidget {
  final List<_NavItem> items;
  final int index;
  final ValueChanged<int> onTap;

  const _GlassNavBar({
    required this.items,
    required this.index,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final pendingCount = context.select<AppState, int>(
      (s) => s.pendingUploadCount,
    );

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.bgElevated.withValues(alpha: 0.86),
            border: const Border(
              top: BorderSide(color: AppColors.border),
            ),
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 62,
              child: Row(
                children: List.generate(items.length, (i) {
                  final it = items[i];
                  final active = i == index;
                  final badge = i == 3 && pendingCount > 0 ? pendingCount : 0;
                  return Expanded(
                    child: InkWell(
                      onTap: () => onTap(i),
                      splashColor: it.color.withValues(alpha: 0.1),
                      highlightColor: Colors.transparent,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 220),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 5),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(999),
                                  color: active
                                      ? it.color.withValues(alpha: 0.16)
                                      : Colors.transparent,
                                  boxShadow: active
                                      ? AppShadows.glow(it.color,
                                          blur: 14, opacity: 0.30)
                                      : null,
                                ),
                                child: Icon(
                                  active ? it.activeIcon : it.icon,
                                  size: 21,
                                  color:
                                      active ? it.color : AppColors.textLow,
                                ),
                              ),
                              if (badge > 0)
                                Positioned(
                                  right: 6,
                                  top: -2,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 5, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: AppColors.neonRed,
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(
                                          color: AppColors.bgElevated,
                                          width: 1.5),
                                    ),
                                    child: Text(
                                      '$badge',
                                      style: const TextStyle(
                                        fontSize: 8.5,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                        height: 1.2,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            it.label,
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight:
                                  active ? FontWeight.w800 : FontWeight.w600,
                              color: active ? it.color : AppColors.textLow,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
