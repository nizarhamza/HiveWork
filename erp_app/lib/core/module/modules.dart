import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../modules/crm/crm_module.dart';
import '../../modules/inventory/inventory_module.dart';
import '../../modules/sales/sales_module.dart';
import '../../modules/stubs/stub_modules.dart';
import 'app_module.dart';

/// The enabled modules, in sidebar order.
///
/// To add a feature: create a `FooModule` implementing [AppModule] and append
/// it here. It appears in the sidebar with its pages nested beneath it,
/// fully themed — no other file changes.
const List<AppModule> kAppModules = [
  CrmModule(),
  SalesModule(),
  InventoryModule(),
  InvoicingModule(),
  ProjectsModule(),
];

final moduleRegistryProvider =
    Provider<ModuleRegistry>((ref) => const ModuleRegistry(kAppModules));
