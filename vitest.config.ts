import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    // Runs before any test module is imported, pinning the process into
    // dry-run mode so no tool can reach a real side effect.
    setupFiles: ['./tests/setup.ts'],
    include: ['**/*.{test,spec}.ts'],
    exclude: [
      '**/node_modules/**',
      '**/dist/**',
      '**/.build/**',
      '**/*.app/**',
      '**/*.d.ts',
    ],
    env: {
      SAFE_TEST_MODE: 'true',
      LIVE_SIDE_EFFECTS: 'false',
      LOFLY_ENV: 'test',
    },
  },
});
