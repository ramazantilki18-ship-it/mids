import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

class MetroBrandHeader extends StatelessWidget {
  final double logoWidth;
  final double titleWidth;
  final double titleFontSize;
  final Color titleColor;
  final EdgeInsetsGeometry padding;
  final bool compact;
  final bool framed;
  final double? titleLetterSpacing;
  final double titleExtraWidth;

  const MetroBrandHeader({
    super.key,
    this.logoWidth = 156,
    double? titleWidth,
    this.titleFontSize = 12.5,
    this.titleColor = const Color(0xFF001E61),
    this.padding = EdgeInsets.zero,
    this.compact = false,
    this.framed = true,
    this.titleLetterSpacing,
    this.titleExtraWidth = 16,
  }) : titleWidth = titleWidth ?? logoWidth;

  @override
  Widget build(BuildContext context) {
    final title = Text(
      'DENET\u0130M S\u0130STEM\u0130',
      textAlign: TextAlign.center,
      maxLines: 1,
      overflow: TextOverflow.visible,
      style: TextStyle(
        color: titleColor,
        fontSize: titleFontSize,
        fontWeight: FontWeight.w700,
        letterSpacing: titleLetterSpacing ?? (compact ? 0.8 : 1.2),
        height: 1.05,
      ),
    );

    final content = Padding(
      padding: padding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!kIsWeb && Platform.isIOS)
            SizedBox(
              width: logoWidth * 0.45, // Kare formatındaki logo için dikeyde taşmaması adına ebat iyice küçültüldü
              child: Image.asset(
                'assets/brand/ios_m_logo.png',
                fit: BoxFit.contain,
              ),
            )
          else
            SizedBox(
              width: logoWidth,
              child: SvgPicture.asset(
                'assets/brand/metro_istanbul_logo_color.svg',
                fit: BoxFit.contain,
                colorMapper: const _MetroLogoColorMapper(),
              ),
            ),
          SizedBox(height: compact ? 8 : 12),
          SizedBox(
            width: titleWidth + titleExtraWidth,
            child: FittedBox(fit: BoxFit.scaleDown, child: title),
          ),
        ],
      ),
    );

    return content;
  }
}

class _MetroLogoColorMapper extends ColorMapper {
  const _MetroLogoColorMapper();

  static const _metroBlue = Color(0xFF003B8F);
  static const _metroDarkBlue = Color(0xFF001E61);
  static const _metroRed = Color(0xFFD7282F);
  static const _metroDarkRed = Color(0xFFB2292E);

  @override
  Color substitute(
    String? id,
    String elementName,
    String attributeName,
    Color color,
  ) {
    final value = color.value & 0x00FFFFFF;
    if (value == 0xD7282F) return _metroRed;
    if (value == 0xB2292E) return _metroDarkRed;
    if (value == 0x021D49) return _metroDarkBlue;
    if (value == 0x001E61 || value == 0x000000 || value == 0x111111) {
      return _metroBlue;
    }
    return color;
  }
}
