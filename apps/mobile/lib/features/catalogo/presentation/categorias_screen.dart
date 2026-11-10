import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/formatos/validadores.dart';
import '../../../core/widgets/widgets.dart';
import '../data/catalogo_repository.dart';
import '../domain/catalogo_models.dart';

class CategoriasLista extends ConsumerWidget {
  const CategoriasLista({required this.editable, super.key});

  final bool editable;

  static Future<void> editar(BuildContext context, {Categoria? categoria}) =>
      showDialog<void>(
        context: context,
        builder: (_) => _DialogoCategoria(categoria: categoria),
      );

  Future<void> _cambiarActiva(
    BuildContext context,
    WidgetRef ref,
    Categoria categoria,
    bool activa,
  ) async {
    try {
      await ref
          .read(catalogoRepositoryProvider)
          .cambiarCategoriaActiva(categoria.id, activa);
      ref.invalidate(categoriasProvider);
    } catch (error) {
      if (context.mounted) {
        mostrarMensaje(context, mensajeDeEscritura(error), error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ContenidoAsync<List<Categoria>>(
        valor: ref.watch(categoriasProvider),
        onReintentar: () => ref.invalidate(categoriasProvider),
        builder: (categorias) {
          if (categorias.isEmpty) {
            return const EstadoVacio(titulo: 'Sin categorías');
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.x4,
              AppSpace.x4,
              AppSpace.x4,
              AppSpace.x6,
            ),
            itemCount: categorias.length,
            itemBuilder: (_, indice) {
              final categoria = categorias[indice];
              return ListCard(
                margin: const EdgeInsets.only(bottom: AppSpace.x2 + 2),
                dimmed: !categoria.activa,
                leading: IconChip(
                  LucideIcons.tag,
                  color: CategoryColors.of(categoria.nombre),
                ),
                title: categoria.nombre,
                subtitle: 'Orden ${categoria.orden}',
                onTap: editable
                    ? () => editar(context, categoria: categoria)
                    : null,
                trailing: Switch(
                  value: categoria.activa,
                  onChanged: editable
                      ? (activa) =>
                            _cambiarActiva(context, ref, categoria, activa)
                      : null,
                ),
              );
            },
          );
        },
      );
}

class _DialogoCategoria extends ConsumerStatefulWidget {
  const _DialogoCategoria({this.categoria});

  final Categoria? categoria;

  @override
  ConsumerState<_DialogoCategoria> createState() => _DialogoCategoriaState();
}

class _DialogoCategoriaState extends ConsumerState<_DialogoCategoria> {
  final _formulario = GlobalKey<FormState>();
  late final _nombre = TextEditingController(text: widget.categoria?.nombre);
  late final _orden = TextEditingController(
    text: (widget.categoria?.orden ?? 0).toString(),
  );
  bool _guardando = false;

  @override
  void dispose() {
    _nombre.dispose();
    _orden.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formulario.currentState!.validate()) return;
    setState(() => _guardando = true);
    try {
      await ref
          .read(catalogoRepositoryProvider)
          .guardarCategoria(
            widget.categoria?.id,
            nombre: _nombre.text.trim(),
            orden: int.tryParse(_orden.text) ?? 0,
          );
      ref.invalidate(categoriasProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        mostrarMensaje(context, mensajeDeEscritura(error), error: true);
        setState(() => _guardando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => AppDialog(
    title: Text(
      widget.categoria == null ? 'Nueva categoría' : 'Editar categoría',
    ),
    content: Form(
      key: _formulario,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CampoTexto(
            etiqueta: 'Nombre',
            controller: _nombre,
            validator: validarRequerido,
          ),
          const SizedBox(height: AppSpace.x3),
          CampoTexto(
            etiqueta: 'Orden',
            controller: _orden,
            teclado: TextInputType.number,
            formateadores: [FilteringTextInputFormatter.digitsOnly],
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: _guardando ? null : () => Navigator.of(context).pop(),
        child: const Text('Cancelar'),
      ),
      TextButton(
        onPressed: _guardando ? null : _guardar,
        child: const Text('Guardar'),
      ),
    ],
  );
}
