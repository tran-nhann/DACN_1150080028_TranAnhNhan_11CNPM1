import 'package:flutter/material.dart';

import 'theme.dart';

/// Scroll the fields while keeping the primary action inside the visible area.
class PinnedFormLayout extends StatelessWidget {
  const PinnedFormLayout({
    super.key,
    this.header,
    required this.body,
    required this.footer,
  });
  final Widget? header;
  final Widget body, footer;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact =
          constraints.maxHeight < 300 ||
          constraints.maxHeight <
              400 * MediaQuery.textScalerOf(context).scale(1);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!compact && header != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: header!,
            ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [if (compact && header != null) header!, body],
              ),
            ),
          ),
          Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: AsterColors.border)),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
                child: footer,
              ),
            ),
          ),
        ],
      );
    },
  );
}
