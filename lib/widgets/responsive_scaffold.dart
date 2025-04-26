import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_sidebar.dart';

class ResponsiveScaffold extends ConsumerWidget {
  final String title;
  final Widget body;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;
  final Widget? sidebar;
  final Widget? appBar;
  final bool resizeToAvoidBottomInset;
  final Color backgroundColor;

  const ResponsiveScaffold({
    Key? key,
    required this.title,
    required this.body,
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.sidebar,
    this.appBar,
    this.resizeToAvoidBottomInset = true,
    this.backgroundColor = Colors.white,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSidebarCollapsed = ref.watch(sidebarCollapsedProvider);

    // Determine screen size
    final isLargeScreen = screenWidth > 1200;
    final isMediumScreen = screenWidth > 800 && screenWidth <= 1200;
    final isSmallScreen = screenWidth <= 800;

    // Default appbar if none provided
    final appBarWidget = appBar ??
        AppBar(
          title: Text(title),
          elevation: 0,
          // Only show menu button on small screens
          leading: isSmallScreen
              ? IconButton(
                  icon: const Icon(Icons.menu),
                  onPressed: () {
                    Scaffold.of(context).openDrawer();
                  },
                )
              : null,
        );

    // Use the sidebar if provided, otherwise use the default one
    final sidebarWidget = sidebar ?? const AppSidebar();

    if (isLargeScreen || isMediumScreen) {
      // For large and medium screens, show side-by-side layout
      return Scaffold(
        appBar: appBarWidget as PreferredSizeWidget,
        body: Row(
          children: [
            // Sidebar (fixed width)
            sidebarWidget,
            // Main content (expands to fill space)
            Expanded(child: body),
          ],
        ),
        floatingActionButton: floatingActionButton,
        bottomNavigationBar: bottomNavigationBar,
        resizeToAvoidBottomInset: resizeToAvoidBottomInset,
        backgroundColor: backgroundColor,
      );
    } else {
      // For small screens, use drawer layout
      return Scaffold(
        appBar: appBarWidget as PreferredSizeWidget,
        drawer: Drawer(
          elevation: 0,
          child: sidebarWidget,
        ),
        body: body,
        floatingActionButton: floatingActionButton,
        bottomNavigationBar: bottomNavigationBar,
        resizeToAvoidBottomInset: resizeToAvoidBottomInset,
        backgroundColor: backgroundColor,
      );
    }
  }
}
