// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

class RedactionPolicy {
  const RedactionPolicy({
    this.environmentKeys = _defaultEnvironmentKeys,
    this.minimumSecretLength = 8,
  });

  final List<String> environmentKeys;
  final int minimumSecretLength;

  static const List<String> _defaultEnvironmentKeys = <String>[
    'OPENAI_API_KEY',
    'GEMINI_API_KEY',
    'ANTHROPIC_API_KEY',
    'AZURE_OPENAI_API_KEY',
    'COHERE_API_KEY',
    'MISTRAL_API_KEY',
    'GROQ_API_KEY',
    'HF_TOKEN',
    'HUGGINGFACEHUB_API_TOKEN',
    'GITHUB_TOKEN',
    'GITLAB_TOKEN',
    'BITBUCKET_TOKEN',
    'AWS_ACCESS_KEY_ID',
    'AWS_SECRET_ACCESS_KEY',
    'AWS_SESSION_TOKEN',
  ];
}
