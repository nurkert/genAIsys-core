import 'package:genaisys/app/app_services.dart';

import '../core/support/fake_genaisys_api.dart';

AppServices buildTestServices({FakeGenaisysApi? api}) {
  return AppServices(api: api ?? FakeGenaisysApi());
}
