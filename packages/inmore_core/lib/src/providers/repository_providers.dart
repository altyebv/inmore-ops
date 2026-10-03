import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/back_office_repositories.dart';
import '../data/customer_repository.dart';
import '../data/misc_repositories.dart';
import '../data/quotation_repository.dart';
import '../data/request_repository.dart';
import '../data/task_repository.dart';
import 'auth_providers.dart';

final customerRepositoryProvider = Provider<CustomerRepository>(
  (ref) => CustomerRepository(ref.watch(supabaseClientProvider)),
);

final requestRepositoryProvider = Provider<RequestRepository>(
  (ref) => RequestRepository(ref.watch(supabaseClientProvider)),
);

final taskRepositoryProvider = Provider<TaskRepository>(
  (ref) => TaskRepository(ref.watch(supabaseClientProvider)),
);

final quotationRepositoryProvider = Provider<QuotationRepository>(
  (ref) => QuotationRepository(ref.watch(supabaseClientProvider)),
);

final paymentRepositoryProvider = Provider<PaymentRepository>(
  (ref) => PaymentRepository(ref.watch(supabaseClientProvider)),
);

final catalogRepositoryProvider = Provider<CatalogRepository>(
  (ref) => CatalogRepository(ref.watch(supabaseClientProvider)),
);

final employeeRepositoryProvider = Provider<EmployeeRepository>(
  (ref) => EmployeeRepository(ref.watch(supabaseClientProvider)),
);

final activityRepositoryProvider = Provider<ActivityRepository>(
  (ref) => ActivityRepository(ref.watch(supabaseClientProvider)),
);

final exportRepositoryProvider = Provider<ExportRepository>(
  (ref) => ExportRepository(ref.watch(supabaseClientProvider)),
);

final inventoryRepositoryProvider = Provider<InventoryRepository>(
  (ref) => InventoryRepository(ref.watch(supabaseClientProvider)),
);

final expenseRepositoryProvider = Provider<ExpenseRepository>(
  (ref) => ExpenseRepository(ref.watch(supabaseClientProvider)),
);

final staffRepositoryProvider = Provider<StaffRepository>(
  (ref) => StaffRepository(ref.watch(supabaseClientProvider)),
);

final businessProfileRepositoryProvider = Provider<BusinessProfileRepository>(
  (ref) => BusinessProfileRepository(ref.watch(supabaseClientProvider)),
);
