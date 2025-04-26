import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'responsive_scaffold.dart';
import 'app_sidebar.dart';
import '../config/theme.dart';

/// A shared layout component that includes the responsive scaffold with sidebar
/// Use this widget to maintain a consistent layout across all app screens
class AppLayout extends ConsumerWidget {
  final String title;
  final Widget body;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;
  final bool showNavigation;
  final List<Widget>? actions;
  final Widget? drawer;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final bool centerTitle;
  final Widget? leading;
  final PreferredSizeWidget? appBar;
  final bool useDarkBackground;
  final bool showHeaderDecoration;

  const AppLayout({
    super.key,
    required this.title,
    required this.body,
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.showNavigation = true,
    this.actions,
    this.drawer,
    this.floatingActionButtonLocation,
    this.centerTitle = false,
    this.leading,
    this.appBar,
    this.useDarkBackground = false,
    this.showHeaderDecoration = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customAppBar = appBar ??
        AppBar(
          title: Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          centerTitle: centerTitle,
          actions: actions,
          leading: leading,
          elevation: 0,
          backgroundColor: useDarkBackground
              ? AppTheme.primaryDarkColor
              : AppTheme.primaryColor,
          shape: showHeaderDecoration
              ? const RoundedRectangleBorder(
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                )
              : null,
        );

    final isSidebarCollapsed = ref.watch(sidebarCollapsedProvider);
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth <= 800;

    final wrappedBody = _buildStyledBody(context, body);

    if (!showNavigation) {
      // If navigation is disabled, use a simple Scaffold instead
      return Scaffold(
        appBar: customAppBar,
        body: wrappedBody,
        floatingActionButton: floatingActionButton,
        floatingActionButtonLocation: floatingActionButtonLocation,
        bottomNavigationBar: bottomNavigationBar,
        drawer: drawer,
        backgroundColor: useDarkBackground
            ? const Color(0xFF1E272E)
            : const Color(0xFFF5F7F9),
      );
    }

    return ResponsiveScaffold(
      title: title,
      body: wrappedBody,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
      sidebar: const AppSidebar(),
      appBar: customAppBar,
      backgroundColor:
          useDarkBackground ? const Color(0xFF1E272E) : const Color(0xFFF5F7F9),
    );
  }

  Widget _buildStyledBody(BuildContext context, Widget content) {
    return Stack(
      children: [
        // Background pattern
        if (!useDarkBackground)
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.05),
                borderRadius: BorderRadius.circular(150),
              ),
            ),
          ),
        if (!useDarkBackground)
          Positioned(
            bottom: -80,
            left: -80,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                color: AppTheme.accentColor.withOpacity(0.05),
                borderRadius: BorderRadius.circular(100),
              ),
            ),
          ),

        // Main content with some padding and margins
        SafeArea(
          child: content,
        ),
      ],
    );
  }
}
