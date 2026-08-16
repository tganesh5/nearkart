import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/cart_item_model.dart';
import '../models/product_model.dart';

class CartState {
  final List<CartItemModel> items;
  final String? storeId;
  final String? storeName;

  CartState({
    this.items = const [],
    this.storeId,
    this.storeName,
  });

  double get subtotal => items.fold(0, (sum, item) => sum + item.totalPrice);
  int get totalItems => items.fold(0, (sum, item) => sum + item.quantity);
  bool get isEmpty => items.isEmpty;

  CartState copyWith({
    List<CartItemModel>? items,
    String? storeId,
    String? storeName,
  }) {
    return CartState(
      items: items ?? this.items,
      storeId: storeId ?? this.storeId,
      storeName: storeName ?? this.storeName,
    );
  }
}

class CartNotifier extends StateNotifier<CartState> {
  CartNotifier() : super(CartState());

  void addItem(ProductModel product, {String? storeName}) {
    if (state.storeId != null && state.storeId != product.storeId) {
      clearCart();
    }

    final existingIndex =
        state.items.indexWhere((item) => item.product.id == product.id);

    if (existingIndex >= 0) {
      final updatedItems = List<CartItemModel>.from(state.items);
      updatedItems[existingIndex] = updatedItems[existingIndex].copyWith(
        quantity: updatedItems[existingIndex].quantity + 1,
      );
      state = state.copyWith(items: updatedItems);
    } else {
      state = CartState(
        items: [...state.items, CartItemModel(product: product)],
        storeId: product.storeId,
        storeName: storeName ?? state.storeName,
      );
    }
  }

  void removeItem(String productId) {
    final updatedItems =
        state.items.where((item) => item.product.id != productId).toList();
    if (updatedItems.isEmpty) {
      clearCart();
    } else {
      state = state.copyWith(items: updatedItems);
    }
  }

  void updateQuantity(String productId, int quantity) {
    if (quantity <= 0) {
      removeItem(productId);
      return;
    }

    final updatedItems = state.items.map((item) {
      if (item.product.id == productId) {
        return item.copyWith(quantity: quantity);
      }
      return item;
    }).toList();

    state = state.copyWith(items: updatedItems);
  }

  void clearCart() {
    state = CartState();
  }

  int getItemQuantity(String productId) {
    final item = state.items.where((i) => i.product.id == productId);
    return item.isEmpty ? 0 : item.first.quantity;
  }
}

final cartProvider = StateNotifierProvider<CartNotifier, CartState>((ref) {
  return CartNotifier();
});
