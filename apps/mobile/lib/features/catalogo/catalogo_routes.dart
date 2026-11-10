import 'package:go_router/go_router.dart';

import '../../core/router/rutas.dart';
import 'presentation/clientes_screen.dart';
import 'presentation/producto_form_screen.dart';
import 'presentation/productos_screen.dart';

final List<RouteBase> catalogoRoutes = [
  GoRoute(path: Rutas.productos, builder: (_, _) => const ProductosScreen()),
  GoRoute(
    path: Rutas.productoDetalle,
    builder: (_, estado) {
      final id = estado.pathParameters['id']!;
      return ProductoFormScreen(productoId: id == idProductoNuevo ? null : id);
    },
  ),
  GoRoute(path: Rutas.clientes, builder: (_, _) => const ClientesScreen()),
];
