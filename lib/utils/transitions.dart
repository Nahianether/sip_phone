import 'package:flutter/material.dart';

class AppTransitions {
  // Slide transition from right
  static Route<T> slideFromRight<T>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: const Duration(milliseconds: 300),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(1.0, 0.0);
        const end = Offset.zero;
        const curve = Curves.easeInOutCubic;

        var tween = Tween(begin: begin, end: end).chain(
          CurveTween(curve: curve),
        );

        var offsetAnimation = animation.drive(tween);

        return SlideTransition(
          position: offsetAnimation,
          child: child,
        );
      },
    );
  }

  // Slide transition from bottom
  static Route<T> slideFromBottom<T>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: const Duration(milliseconds: 400),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(0.0, 1.0);
        const end = Offset.zero;
        const curve = Curves.easeOutCubic;

        var tween = Tween(begin: begin, end: end).chain(
          CurveTween(curve: curve),
        );

        var offsetAnimation = animation.drive(tween);

        return SlideTransition(
          position: offsetAnimation,
          child: child,
        );
      },
    );
  }

  // Fade transition
  static Route<T> fadeTransition<T>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: const Duration(milliseconds: 250),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: child,
        );
      },
    );
  }

  // Scale transition
  static Route<T> scaleTransition<T>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: const Duration(milliseconds: 300),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const curve = Curves.easeInOutBack;
        var scaleAnimation = Tween<double>(
          begin: 0.0,
          end: 1.0,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: curve,
        ));

        return ScaleTransition(
          scale: scaleAnimation,
          child: child,
        );
      },
    );
  }

  // Combined slide and fade transition
  static Route<T> slideAndFade<T>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: const Duration(milliseconds: 350),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(0.3, 0.0);
        const end = Offset.zero;
        const curve = Curves.easeOutCubic;

        var slideAnimation = Tween(begin: begin, end: end).animate(
          CurvedAnimation(parent: animation, curve: curve),
        );

        var fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(parent: animation, curve: curve),
        );

        return SlideTransition(
          position: slideAnimation,
          child: FadeTransition(
            opacity: fadeAnimation,
            child: child,
          ),
        );
      },
    );
  }

  // Hero-style transition for dialogs
  static Route<T> heroDialog<T>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: const Duration(milliseconds: 300),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        var scaleAnimation = Tween<double>(
          begin: 0.7,
          end: 1.0,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
        ));

        var fadeAnimation = Tween<double>(
          begin: 0.0,
          end: 1.0,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: Curves.easeOut,
        ));

        return Transform.scale(
          scale: scaleAnimation.value,
          child: FadeTransition(
            opacity: fadeAnimation,
            child: child,
          ),
        );
      },
      opaque: false,
      barrierColor: Colors.black54,
      barrierDismissible: true,
    );
  }

  // Custom navigation with different transitions
  static Future<T?> navigateWithTransition<T>(
    BuildContext context,
    Widget page, {
    TransitionType type = TransitionType.slideFromRight,
  }) {
    Route<T> route;
    
    switch (type) {
      case TransitionType.slideFromRight:
        route = slideFromRight<T>(page);
        break;
      case TransitionType.slideFromBottom:
        route = slideFromBottom<T>(page);
        break;
      case TransitionType.fade:
        route = fadeTransition<T>(page);
        break;
      case TransitionType.scale:
        route = scaleTransition<T>(page);
        break;
      case TransitionType.slideAndFade:
        route = slideAndFade<T>(page);
        break;
      case TransitionType.heroDialog:
        route = heroDialog<T>(page);
        break;
    }
    
    return Navigator.of(context).push<T>(route);
  }

  // Replace current page with transition
  static Future<T?> replaceWithTransition<T>(
    BuildContext context,
    Widget page, {
    TransitionType type = TransitionType.slideFromRight,
  }) {
    Route<T> route;
    
    switch (type) {
      case TransitionType.slideFromRight:
        route = slideFromRight<T>(page);
        break;
      case TransitionType.slideFromBottom:
        route = slideFromBottom<T>(page);
        break;
      case TransitionType.fade:
        route = fadeTransition<T>(page);
        break;
      case TransitionType.scale:
        route = scaleTransition<T>(page);
        break;
      case TransitionType.slideAndFade:
        route = slideAndFade<T>(page);
        break;
      case TransitionType.heroDialog:
        route = heroDialog<T>(page);
        break;
    }
    
    return Navigator.of(context).pushReplacement<T, void>(route);
  }
}

enum TransitionType {
  slideFromRight,
  slideFromBottom,
  fade,
  scale,
  slideAndFade,
  heroDialog,
}