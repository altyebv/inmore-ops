/// Shared domain layer for the Inmore operations system.
///
/// Used by `ops_desktop` and `owner_mobile`. Nothing here draws or translates
/// anything — that is `inmore_ui`.
library inmore_core;

export 'src/data/back_office_repositories.dart';
export 'src/data/customer_repository.dart';
export 'src/data/errors.dart';
export 'src/data/misc_repositories.dart';
export 'src/data/quotation_repository.dart';
export 'src/data/request_repository.dart';
export 'src/data/session_repository.dart';
export 'src/data/task_repository.dart';
export 'src/enums/employee_role.dart';
export 'src/enums/enums.dart';
export 'src/export/excel_report.dart';
export 'src/export/report_table.dart';
export 'src/models/activity.dart';
export 'src/models/back_office.dart';
export 'src/models/catalog.dart';
export 'src/models/customer.dart';
export 'src/models/employee.dart';
export 'src/models/export_row.dart';
export 'src/models/payment.dart';
export 'src/models/quotation.dart';
export 'src/models/request.dart';
export 'src/models/task.dart';
export 'src/providers/auth_providers.dart';
export 'src/providers/back_office_providers.dart';
export 'src/providers/data_providers.dart';
export 'src/providers/owner_providers.dart';
export 'src/providers/realtime_sync.dart';
export 'src/providers/repository_providers.dart';
export 'src/util/formatting.dart';
