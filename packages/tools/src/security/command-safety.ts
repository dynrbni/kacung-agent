import type { PermissionLevel } from '@kacung/types';

export interface CommandSafetyEvaluation {
  level: PermissionLevel;
  isBlocked: boolean;
  blockReason?: string;
  warning?: string;
  isSafeToExecuteDirectly: boolean;
}

const BLOCKED_PATTERNS: Array<{ pattern: RegExp; reason: string }> = [
  {
    pattern: /\brm\s+-[a-zA-Z]*[rf][a-zA-Z]*\s+(\/|\/\*|~\/|~|\$HOME)(\s|$|;)/i,
    reason: 'Destructive deletion of root, home, or system directory is blocked.',
  },
  {
    pattern: /\brm\s+-[a-zA-Z]*\s+-[a-zA-Z]*\s+(\/|\/\*|~\/|~|\$HOME)(\s|$|;)/i,
    reason: 'Destructive deletion of root, home, or system directory is blocked.',
  },
  {
    pattern: /:\(\)\s*\{\s*:\s*\|\s*:\s*&\s*\}\s*;\s*:/,
    reason: 'Fork bombs are strictly blocked.',
  },
  {
    pattern: /\bdd\s+if=.*of=\/dev\/(r?disk|sd)/i,
    reason: 'Direct disk write / block-level overwrite is blocked.',
  },
  {
    pattern: /\bmkfs(\.[a-z0-9]+)?\b/i,
    reason: 'Filesystem formatting is blocked.',
  },
  {
    pattern: />\s*\/dev\/(sda|sdb|nvme|disk)/i,
    reason: 'Redirecting raw data to disk block devices is blocked.',
  },
];

const DANGEROUS_PATTERNS: Array<{ pattern: RegExp; warning: string }> = [
  { pattern: /\bsudo\b/i, warning: 'Requires superuser privileges (sudo)' },
  { pattern: /\brm\s+-[a-zA-Z]*r/i, warning: 'Recursive file deletion' },
  { pattern: /\brm\s+-[a-zA-Z]*f/i, warning: 'Forceful file deletion' },
  { pattern: /\bkill\s+-9\b/i, warning: 'Forceful process termination' },
  { pattern: /\bpkill\s+-9\b/i, warning: 'Forceful process kill' },
  { pattern: /\bgit\s+reset\s+--hard\b/i, warning: 'Destructive Git reset' },
  { pattern: /\bgit\s+clean\s+-[a-zA-Z]*f/i, warning: 'Destructive Git clean' },
  { pattern: /\bchmod\s+(-R\s+)?777\b/i, warning: 'Insecure full permission granting' },
  { pattern: /\bshutdown\b|\breboot\b|\bhalt\b/i, warning: 'System restart/shutdown command' },
];

const SENSITIVE_PATTERNS: Array<{ pattern: RegExp; warning: string }> = [
  { pattern: /\b(npm|pnpm|yarn|bun)\s+(install|add|remove|uninstall)\b/i, warning: 'Package dependency modification' },
  { pattern: /\bgit\s+(commit|push|rebase|merge)\b/i, warning: 'Git repository state mutation' },
  { pattern: /\bcurl\b.*\s+\|\s*(ba)?sh\b/i, warning: 'Piping remote script directly to shell execution' },
  { pattern: /\b(mkdir|mv|cp|touch|sed|awk\s+-i)\b/i, warning: 'Filesystem mutation command' },
  { pattern: />>|>/i, warning: 'Output redirection to file' },
];

const SAFE_COMMANDS = new Set([
  'pwd',
  'ls',
  'dir',
  'whoami',
  'date',
  'cal',
  'echo',
  'printf',
  'which',
  'where',
  'uname',
  'hostname',
  'sw_vers',
  'uptime',
  'id',
  'cat',
  'head',
  'tail',
  'wc',
  'git status',
  'git log',
  'git branch',
  'git diff',
  'sw_vers',
]);

export function evaluateCommandSafety(command: string): CommandSafetyEvaluation {
  const trimmed = command.trim();

  // 1. Check blocked patterns
  for (const { pattern, reason } of BLOCKED_PATTERNS) {
    if (pattern.test(trimmed)) {
      return {
        level: 'DANGEROUS',
        isBlocked: true,
        blockReason: reason,
        isSafeToExecuteDirectly: false,
      };
    }
  }

  // 2. Check dangerous patterns
  for (const { pattern, warning } of DANGEROUS_PATTERNS) {
    if (pattern.test(trimmed)) {
      return {
        level: 'DANGEROUS',
        isBlocked: false,
        warning,
        isSafeToExecuteDirectly: false,
      };
    }
  }

  // 3. Check sensitive patterns
  for (const { pattern, warning } of SENSITIVE_PATTERNS) {
    if (pattern.test(trimmed)) {
      return {
        level: 'SENSITIVE',
        isBlocked: false,
        warning,
        isSafeToExecuteDirectly: false,
      };
    }
  }

  // 4. Check if single safe command
  const baseCommand = trimmed.split(/\s+/)[0]?.toLowerCase() || '';
  if (SAFE_COMMANDS.has(trimmed) || SAFE_COMMANDS.has(baseCommand)) {
    // Avoid piped or chained commands being treated as unconditionally safe
    if (!trimmed.includes('|') && !trimmed.includes('&') && !trimmed.includes(';')) {
      return {
        level: 'SAFE',
        isBlocked: false,
        isSafeToExecuteDirectly: true,
      };
    }
  }

  // Default for unspecified commands is SENSITIVE (requires confirmation)
  return {
    level: 'SENSITIVE',
    isBlocked: false,
    warning: 'General shell command requires confirmation',
    isSafeToExecuteDirectly: false,
  };
}
