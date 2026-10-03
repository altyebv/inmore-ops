import 'package:flutter/material.dart';
import 'package:inmore_ui/inmore_ui.dart';

/// A text field that suggests what's been used before, without restricting
/// the answer to that list — a category, a unit.
class SuggestField extends StatefulWidget {
  const SuggestField({
    required this.controller,
    required this.label,
    required this.options,
    this.validator,
    super.key,
  });

  final TextEditingController controller;
  final String label;
  final List<String> options;
  final FormFieldValidator<String>? validator;

  @override
  State<SuggestField> createState() => _SuggestFieldState();
}

class _SuggestFieldState extends State<SuggestField> {
  final _focus = FocusNode();

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RawAutocomplete<String>(
        textEditingController: widget.controller,
        focusNode: _focus,
        optionsBuilder: (v) {
          final q = v.text.trim().toLowerCase();
          return widget.options
              .where((o) => o.toLowerCase().contains(q) && o != v.text.trim());
        },
        fieldViewBuilder: (context, c, focus, onSubmit) => TextFormField(
          controller: c,
          focusNode: focus,
          validator: widget.validator,
          decoration: InputDecoration(labelText: widget.label),
        ),
        optionsViewBuilder: (context, onSelected, opts) => Align(
          alignment: AlignmentDirectional.topStart,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(Radii.md),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240, maxWidth: 260),
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 4),
                shrinkWrap: true,
                children: [
                  for (final o in opts)
                    ListTile(
                      dense: true,
                      title: UserText(o),
                      onTap: () => onSelected(o),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
}
