import 'package:genaisys/core/settings/project_registry.dart';
import 'package:genaisys/core/settings/project_registry_repository.dart';

class FakeProjectRegistryRepository implements ProjectRegistryRepository {
  FakeProjectRegistryRepository({ProjectRegistry? initialRegistry})
    : _registry = initialRegistry ?? ProjectRegistry.empty;

  ProjectRegistry _registry;

  @override
  String get storagePath => '/tmp/fake_project_registry.json';

  @override
  Future<ProjectRegistry> read() async {
    return _registry;
  }

  @override
  Future<void> write(ProjectRegistry registry) async {
    _registry = registry;
  }

  @override
  Future<void> reset() async {
    _registry = ProjectRegistry.empty;
  }
}
