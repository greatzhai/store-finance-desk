import 'package:flutter/material.dart';

class SearchableDropdown extends StatefulWidget {
  const SearchableDropdown({
    super.key,
    required this.initialValue,
    required this.items,
    required this.label,
    required this.onChanged,
  });

  final String initialValue;
  final List<String> items;
  final String label;
  final ValueChanged<String?> onChanged;

  @override
  State<SearchableDropdown> createState() => _SearchableDropdownState();
}

class _SearchableDropdownState extends State<SearchableDropdown> {
  late final TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();
  final MenuController _menuController = MenuController();
  String _filterQuery = '';

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void didUpdateWidget(covariant SearchableDropdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialValue != oldWidget.initialValue) {
      _controller.text = widget.initialValue;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredItems = widget.items
        .where((item) => item.toLowerCase().contains(_filterQuery.toLowerCase()))
        .toList();

    return MenuAnchor(
      controller: _menuController,
      style: MenuStyle(
        maximumSize: WidgetStateProperty.all(const Size(180, 320)),
      ),
      builder: (context, controller, child) {
        return SizedBox(
          width: 130,
          child: TextField(
            controller: _controller,
            focusNode: _focusNode,
            decoration: InputDecoration(
              labelText: widget.label,
              isDense: true,
              suffixIcon: IconButton(
                padding: EdgeInsets.zero,
                icon: Icon(
                  controller.isOpen ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                ),
                onPressed: () {
                  if (controller.isOpen) {
                    controller.close();
                  } else {
                    setState(() {
                      _filterQuery = '';
                    });
                    controller.open();
                  }
                },
              ),
            ),
            onChanged: (val) {
              setState(() {
                _filterQuery = val;
              });
              if (!controller.isOpen) {
                controller.open();
              }
            },
            onTap: () {
              // 点击输入框只聚焦打字，不弹起菜单
            },
          ),
        );
      },
      menuChildren: filteredItems.map((item) {
        return MenuItemButton(
          onPressed: () {
            _controller.text = item;
            widget.onChanged(item);
            _focusNode.unfocus();
          },
          child: SizedBox(
            width: 110,
            child: Text(
              item,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        );
      }).toList(),
    );
  }
}
