import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme.dart';

/// Professional ko'rinishdagi 6-katakli SMS-kod kiritish maydoni. Haqiqiy
/// kiritish yagona (ko'rinmas) `TextField` orqali amalga oshadi — bu
/// klaviatura/fokus muammolarisiz eng ishonchli yondashuv (6 ta alohida
/// `TextField` orasida fokus almashtirishga qaraganda barqarorroq).
class OtpBoxInput extends StatelessWidget {
  final TextEditingController controller;
  final int length;
  final ValueChanged<String>? onCompleted;
  const OtpBoxInput({
    super.key,
    required this.controller,
    this.length = 6,
    this.onCompleted,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(length, (i) => _box(i)),
          ),
          Opacity(
            opacity: 0,
            child: TextField(
              controller: controller,
              autofocus: true,
              showCursor: false,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(length),
              ],
              onChanged: (v) {
                if (v.length == length) onCompleted?.call(v);
              },
              decoration: const InputDecoration(
                border: InputBorder.none,
                counterText: '',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _box(int index) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final text = controller.text;
        final char = index < text.length ? text[index] : '';
        final isActive = index == text.length;
        return Container(
          width: 44,
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isActive ? AppColors.deep : AppColors.cardBorder,
              width: isActive ? 2 : 1,
            ),
          ),
          child: Text(
            char,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.deep,
            ),
          ),
        );
      },
    );
  }
}
