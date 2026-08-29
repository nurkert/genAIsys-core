import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:genaisys/core/settings/project_registry.dart';
import 'package:genaisys/core/settings/project_registry_repository.dart';
import 'package:genaisys/core/settings/project_registry_service.dart';

void main() {
  String normalize(String path) => path.replaceAll('\\', '/');

  test('path resolver uses HOME on macOS/linux-style platforms', () {
    const ProjectRegistryPathResolver resolver = ProjectRegistryPathResolver(
      environment: <String, String>{'HOME': '/Users/tester'},
      platformOverride: ProjectRegistryPlatform.macOS,
    );

    final String path = resolver.resolveStoragePath();
    expect(path, '/Users/tester/.genaisys/project_registry.json');
  });

  test('path resolver uses APPDATA on Windows', () {
    const ProjectRegistryPathResolver resolver = ProjectRegistryPathResolver(
      environment: <String, String>{
        'APPDATA': r'C:\Users\tester\AppData\Roaming',
      },
      platformOverride: ProjectRegistryPlatform.windows,
    );

    final String path = resolver.resolveStoragePath();
    expect(
      normalize(path),
      'C:/Users/tester/AppData/Roaming/Genaisys/project_registry.json',
    );
  });

  test(
    'file repository returns empty registry when storage is missing',
    () async {
      final Directory temp = Directory.systemTemp.createTempSync(
        'genaisys_project_registry_missing_',
      );
      addTearDown(() {
        if (temp.existsSync()) {
          temp.deleteSync(recursive: true);
        }
      });

      final FileProjectRegistryRepository repository =
          FileProjectRegistryRepository(
            storagePath: '${temp.path}/project_registry.json',
          );
      final ProjectRegistry registry = await repository.read();

      expect(registry, ProjectRegistry.empty);
    },
  );

  test('file repository writes and reads registry', () async {
    final Directory temp = Directory.systemTemp.createTempSync(
      'genaisys_project_registry_roundtrip_',
    );
    addTearDown(() {
      if (temp.existsSync()) {
        temp.deleteSync(recursive: true);
      }
    });

    final FileProjectRegistryRepository repository =
        FileProjectRegistryRepository(
          storagePath: '${temp.path}/project_registry.json',
        );
    final ProjectRegistry expected = ProjectRegistry(
      lastOpenedProjectId: '/tmp/demo',
      projects: const <RegisteredProject>[
        RegisteredProject(
          id: '/tmp/demo',
          name: 'Demo',
          rootPath: '/tmp/demo',
          createdAtIso8601: '2026-02-12T00:00:00.000Z',
          lastOpenedAtIso8601: '2026-02-12T00:01:00.000Z',
        ),
      ],
    );

    await repository.write(expected);
    final ProjectRegistry actual = await repository.read();
    expect(actual, expected);
  });

  test(
    'service registers, opens and deletes projects deterministically',
    () async {
      final Directory temp = Directory.systemTemp.createTempSync(
        'genaisys_project_registry_service_',
      );
      addTearDown(() {
        if (temp.existsSync()) {
          temp.deleteSync(recursive: true);
        }
      });

      final Directory alpha = Directory('${temp.path}/alpha')..createSync();
      final Directory beta = Directory('${temp.path}/beta')..createSync();

      final FileProjectRegistryRepository repository =
          FileProjectRegistryRepository(
            storagePath: '${temp.path}/project_registry.json',
          );
      final ProjectRegistryService service = ProjectRegistryService(
        repository: repository,
      );

      await service.registerProject(name: 'Alpha', rootPath: alpha.path);
      await service.registerProject(name: 'Beta', rootPath: beta.path);

      ProjectRegistry registry = await service.load();
      expect(registry.projects.length, 2);
      expect(registry.lastOpenedProjectId, isNull);

      await service.markProjectOpened(beta.absolute.path);
      registry = await service.load();
      expect(registry.lastOpenedProjectId, beta.absolute.path);
      expect(registry.projects.first.id, beta.absolute.path);

      await service.deleteProject(beta.absolute.path);
      registry = await service.load();
      expect(registry.projects.length, 1);
      expect(registry.lastOpenedProjectId, isNull);
      expect(registry.projects.single.id, alpha.absolute.path);
    },
  );

  test('service resolves last opened only for existing directories', () async {
    final Directory temp = Directory.systemTemp.createTempSync(
      'genaisys_project_registry_last_opened_',
    );
    addTearDown(() {
      if (temp.existsSync()) {
        temp.deleteSync(recursive: true);
      }
    });

    final Directory existing = Directory('${temp.path}/existing')..createSync();
    final String missingPath = '${temp.path}/missing';
    final FileProjectRegistryRepository repository =
        FileProjectRegistryRepository(
          storagePath: '${temp.path}/project_registry.json',
        );
    final ProjectRegistryService service = ProjectRegistryService(
      repository: repository,
    );

    await service.registerProject(
      name: 'Missing',
      rootPath: missingPath,
      markAsLastOpened: true,
    );
    Directory(missingPath).deleteSync(recursive: true);
    expect(await service.resolveLastOpenedProject(), isNull);

    await service.registerProject(
      name: 'Existing',
      rootPath: existing.path,
      markAsLastOpened: true,
    );
    final RegisteredProject? resolved = await service
        .resolveLastOpenedProject();
    expect(resolved, isNotNull);
    expect(resolved!.rootPath, existing.absolute.path);
  });

  test(
    'service creates missing directory when registering a new project',
    () async {
      final Directory temp = Directory.systemTemp.createTempSync(
        'genaisys_project_registry_mkdir_',
      );
      addTearDown(() {
        if (temp.existsSync()) {
          temp.deleteSync(recursive: true);
        }
      });

      final String projectPath = '${temp.path}/new_project';
      final FileProjectRegistryRepository repository =
          FileProjectRegistryRepository(
            storagePath: '${temp.path}/project_registry.json',
          );
      final ProjectRegistryService service = ProjectRegistryService(
        repository: repository,
      );

      expect(Directory(projectPath).existsSync(), isFalse);
      await service.registerProject(name: 'New Project', rootPath: projectPath);
      expect(Directory(projectPath).existsSync(), isTrue);
    },
  );
}
