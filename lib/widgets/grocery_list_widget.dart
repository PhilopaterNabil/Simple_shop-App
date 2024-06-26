import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shop/data/categories.dart';
import 'package:shop/models/category.dart';
import 'package:shop/models/grocery_item.dart';
import 'package:shop/widgets/new_item_widget.dart';

class GroceryListWidget extends StatefulWidget {
  const GroceryListWidget({super.key});

  @override
  State<GroceryListWidget> createState() => _GroceryListWidgetState();
}

class _GroceryListWidgetState extends State<GroceryListWidget> {
  List<GroceryItem> _groceryItems = [];
  bool _isLoading = true;
  String? _errorMessage;

  void _loadData() async {
    final Uri url = Uri.https(
        'simple-shop-ec2b4-default-rtdb.firebaseio.com', 'shopping-list.json');
    try {
      final http.Response response = await http.get(url);
      if (response.statusCode >= 400) {
        setState(() {
          _errorMessage = 'Failed to load data. Please try again later.';
        });
        return;
      }
      if (jsonDecode(response.body) == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }
      final Map<String, dynamic> loadedDate = jsonDecode(response.body);
      final List<GroceryItem> loadedItems = [];

      for (var item in loadedDate.entries) {
        final Category category = categories.entries
            .firstWhere(
              (element) => element.value.title == item.value['category'],
            )
            .value;
        loadedItems.add(
          GroceryItem(
            id: item.key,
            name: item.value['name'],
            quantity: item.value['quantity'],
            category: category,
          ),
        );
        setState(() {
          _groceryItems = loadedItems;
        });
      }
    } catch (error) {
      setState(() {
        _errorMessage = 'Something went wrong. Please try again later.';
      });
    }
  }

  @override
  void initState() {
    _loadData();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    Widget content = const Center(
      child: Text(
        'No items added yet.',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );

    if (_isLoading) {
      content = const Center(child: CircularProgressIndicator());
    }

    if (_groceryItems.isNotEmpty) {
      content = ListView.builder(
        itemCount: _groceryItems.length,
        itemBuilder: (context, index) => Dismissible(
          key: ValueKey(_groceryItems[index].id),
          onDismissed: (direction) {
            final String name = _groceryItems[index].name;
            _removeItem(_groceryItems[index], name, content);
          },
          child: ListTile(
            title: Text(_groceryItems[index].name),
            leading: Container(
              height: MediaQuery.of(context).size.height * 0.025,
              width: MediaQuery.of(context).size.height * 0.025,
              color: _groceryItems[index].category.color,
            ),
            trailing: Text(_groceryItems[index].quantity.toString()),
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      content = Center(
        child: Text(
          _errorMessage!,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Grocery List'),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: addItem,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: content,
    );
  }

  void _removeItem(GroceryItem item, String name, Widget content) async {
    final index = _groceryItems.indexOf(item);
    setState(() {
      _groceryItems.remove(item);
      if (_groceryItems.isEmpty) {
        setState(() {
          content;
          _isLoading = false;
        });
      }
    });
    final Uri url = Uri.https('simple-shop-ec2b4-default-rtdb.firebaseio.com',
        'shopping-list/${item.id}.json');
    final http.Response response = await http.delete(url);
    if (response.statusCode >= 400) {
      setState(() {
        _groceryItems.insert(index, item);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Failed to remove item. Please try again later.',
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$name was removed from the list.'),
          duration: const Duration(seconds: 2),
          action: SnackBarAction(
            textColor: Colors.brown,
            label: 'Undo',
            onPressed: () async {
              setState(() {
                _groceryItems.insert(index, item);
              });
              final Uri undoUrl = Uri.https(
                  'simple-shop-ec2b4-default-rtdb.firebaseio.com',
                  'shopping-list/${item.id}.json');
              final http.Response undoResponse = await http.put(
                undoUrl,
                body: jsonEncode({
                  'name': item.name,
                  'quantity': item.quantity,
                  'category': item.category.title,
                }),
              );
              if (undoResponse.statusCode >= 400) {
                setState(() {
                  _groceryItems.remove(item);
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Failed to undo removal. Please try again later.',
                    ),
                  ),
                );
              }
            },
          ),
        ),
      );
    }
  }

  void addItem() async {
    final newItem = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const NewItemWidget(),
      ),
    );

    if (newItem != null) {
      setState(() {
        _groceryItems.add(newItem);
        _isLoading = false;
      });
    }
  }
}
