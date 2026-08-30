import 'package:flutter/material.dart';

class SmoothPageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;

  SmoothPageRoute({required this.page})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionDuration: const Duration(milliseconds: 350),
          reverseTransitionDuration: const Duration(milliseconds: 300),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curvedAnim = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            );
            return FadeTransition(
              opacity: curvedAnim,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.05, 0),
                  end: Offset.zero,
                ).animate(curvedAnim),
                child: child,
              ),
            );
          },
        );
}

class SmoothFadeRoute<T> extends PageRouteBuilder<T> {
  final Widget page;

  SmoothFadeRoute({required this.page})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionDuration: const Duration(milliseconds: 300),
          reverseTransitionDuration: const Duration(milliseconds: 250),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: Curves.easeOut,
              ),
              child: child,
            );
          },
        );
}

class SmoothSlideUpRoute<T> extends PageRouteBuilder<T> {
  final Widget page;

  SmoothSlideUpRoute({required this.page})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionDuration: const Duration(milliseconds: 400),
          reverseTransitionDuration: const Duration(milliseconds: 300),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curvedAnim = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            );
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.15),
                end: Offset.zero,
              ).animate(curvedAnim),
              child: FadeTransition(
                opacity: CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOut,
                ),
                child: child,
              ),
            );
          },
        );
}

extension NavigatorExtension on BuildContext {
  Future<T?> pushSmooth<T>(Widget page) {
    return Navigator.push<T>(this, SmoothPageRoute(page: page));
  }

  Future<T?> pushFade<T>(Widget page) {
    return Navigator.push<T>(this, SmoothFadeRoute(page: page));
  }

  Future<T?> pushSlideUp<T>(Widget page) {
    return Navigator.push<T>(this, SmoothSlideUpRoute(page: page));
  }
}
