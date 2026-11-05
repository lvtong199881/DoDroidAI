import 'package:flutter/material.dart';

/// 仿系统 Toast：居中偏下的深色胶囊，2 秒后消失
void showToast(BuildContext context, String message) {
  final overlay = Overlay.of(context, rootOverlay: true);
  final entry = OverlayEntry(
    builder: (ctx) => Positioned(
      left: 0,
      right: 0,
      bottom: MediaQuery.of(ctx).size.height * 0.18,
      child: IgnorePointer(
        child: Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(ctx).size.width * 0.8,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xCC1F1F1F),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  overlay.insert(entry);
  Future.delayed(const Duration(seconds: 2), () {
    entry.remove();
  });
}
