insert into public.categorias (id, nombre, orden)
values
  ('00000000-0000-4000-8000-000000000101', 'Bebidas', 1),
  ('00000000-0000-4000-8000-000000000102', 'Abarrotes', 2),
  ('00000000-0000-4000-8000-000000000103', 'Varios', 3)
on conflict (id) do nothing;

insert into public.productos (id, codigo, nombre, descripcion, categoria_id, precio, costo, afectacion, aplica_icbper, controla_stock)
values
  ('00000000-0000-4000-8000-000000000201', 'P001', 'Agua mineral 625 ml', 'Producto de demostracion', '00000000-0000-4000-8000-000000000101', 2.500000, 1.200000, '10', false, false),
  ('00000000-0000-4000-8000-000000000202', 'P002', 'Gaseosa 500 ml', 'Producto de demostracion', '00000000-0000-4000-8000-000000000101', 3.500000, 2.000000, '10', false, false),
  ('00000000-0000-4000-8000-000000000203', 'P003', 'Arroz 1 kg', 'Producto de demostracion exonerado', '00000000-0000-4000-8000-000000000102', 4.800000, 3.500000, '20', false, false),
  ('00000000-0000-4000-8000-000000000204', 'P004', 'Bolsa plastica', 'Producto de demostracion con ICBPER', '00000000-0000-4000-8000-000000000103', 0.100000, 0.030000, '10', true, false)
on conflict (id) do nothing;
