import path from 'path';
import os from 'os';
import type { ExecutionMode, ExecutionPolicy, SideEffectLevel, ToolSafetyMetadata } from '@kacung/types';

/**
 * Side-effect contract every tool must declare. A tool that omits `safety` is
 * treated as `external` so an undeclared tool can never inherit the permissive
 * default by accident.
 */
const UNDECLARED: ToolSafetyMetadata = {
  sideEffect: 'external',
  supportsDryRun: true,
  supportsSandbox: false,
};

export function toolSafety(
  sideEffect: SideEffectLevel,
  options: { supportsDryRun?: boolean; supportsSandbox?: boolean } = {}
): ToolSafetyMetadata {
  return {
    sideEffect,
    supportsDryRun: options.supportsDryRun ?? true,
    supportsSandbox: options.supportsSandbox ?? sideEffect !== 'destructive',
  };
}

export function getToolSafety(safety: ToolSafetyMetadata | undefined): ToolSafetyMetadata {
  return safety ?? UNDECLARED;
}

function envFlag(env: NodeJS.ProcessEnv, key: string): boolean | undefined {
  const raw = env[key];
  if (raw === undefined || raw === '') return undefined;
  const value = raw.trim().toLowerCase();
  if (value === 'true' || value === '1' || value === 'yes') return true;
  if (value === 'false' || value === '0' || value === 'no') return false;
  return undefined;
}

/**
 * Resolves the process-wide execution policy.
 *
 * The system is safe by default and fails closed: an unparseable value, a
 * missing value, or a contradictory pair of flags all resolve to the least
 * privileged mode. Reaching `live` requires an explicit
 * `SAFE_TEST_MODE=false` *and* `LIVE_SIDE_EFFECTS=true`.
 */
export function resolveExecutionPolicy(env: NodeJS.ProcessEnv = process.env): ExecutionPolicy {
  const sandboxRoot = env.LAFLY_SANDBOX_ROOT?.trim() || path.join(os.homedir(), 'LaflySandbox');

  const safeFlag = envFlag(env, 'SAFE_TEST_MODE');
  const liveFlag = envFlag(env, 'LIVE_SIDE_EFFECTS');

  // Contradictory configuration is a hard error, but we still resolve to the
  // safe mode so a bad config can never escalate into live execution.
  if (safeFlag === true && liveFlag === true) {
    return {
      mode: 'dry_run',
      safeTestMode: true,
      liveSideEffects: false,
      sandboxRoot,
      configError:
        'Configuration Error: SAFE_TEST_MODE and LIVE_SIDE_EFFECTS cannot both be enabled.',
    };
  }

  // CI is never allowed live side effects regardless of what the env claims.
  const isCi = Boolean(env.CI) && envFlag(env, 'CI') !== false;

  if (isCi && liveFlag === true) {
    return {
      mode: 'dry_run',
      safeTestMode: true,
      liveSideEffects: false,
      sandboxRoot,
      configError: 'Configuration Error: LIVE_SIDE_EFFECTS cannot be enabled in CI.',
    };
  }

  if (liveFlag === true && safeFlag === false) {
    return {
      mode: env.LAFLY_EXECUTION_MODE === 'sandbox' ? 'sandbox' : 'live',
      safeTestMode: false,
      liveSideEffects: true,
      sandboxRoot,
    };
  }

  if (env.LAFLY_EXECUTION_MODE === 'sandbox') {
    return { mode: 'sandbox', safeTestMode: true, liveSideEffects: false, sandboxRoot };
  }

  return { mode: 'dry_run', safeTestMode: true, liveSideEffects: false, sandboxRoot };
}

/**
 * The single chokepoint below the LLM. Tools whose side effect is anything but
 * `none` are simulated whenever the process is not in live mode, so no prompt,
 * developer instruction, or model output can talk its way past this.
 *
 * Sandbox mode is the exception: a tool that declared `supportsSandbox` does
 * execute there, because the resource it touches is already isolated. A tool
 * that did not opt in is still simulated.
 */
export function shouldSimulate(policy: ExecutionPolicy, safety: ToolSafetyMetadata | undefined): boolean {
  if (policy.mode === 'live') return false;

  const resolved = getToolSafety(safety);
  if (resolved.sideEffect === 'none') return false;
  if (policy.mode === 'sandbox' && resolved.supportsSandbox) return false;

  return true;
}

/** Sandbox mode only contains side effects when the tool opts in. */
export function isSandboxed(policy: ExecutionPolicy, safety: ToolSafetyMetadata | undefined): boolean {
  if (policy.mode !== 'sandbox') return false;
  return getToolSafety(safety).supportsSandbox;
}

export function executionStatus(mode: ExecutionMode): { mode: ExecutionMode; executed: boolean; dryRun: boolean } {
  return { mode, executed: mode === 'live', dryRun: mode === 'dry_run' };
}

let processPolicy: ExecutionPolicy | undefined;

/** Cached process-wide policy. Tests should use `resolveExecutionPolicy` directly. */
export function getExecutionPolicy(): ExecutionPolicy {
  if (!processPolicy) {
    processPolicy = resolveExecutionPolicy();
  }
  return processPolicy;
}

export function setExecutionPolicy(policy: ExecutionPolicy): void {
  processPolicy = policy;
}

export function resetExecutionPolicy(): void {
  processPolicy = undefined;
}

/**
 * Resolves a user-supplied path inside the sandbox root, rejecting any attempt
 * to escape it. Used by filesystem tools in sandbox mode.
 */
export function resolveSandboxPath(sandboxRoot: string, target: string): string {
  const root = path.resolve(sandboxRoot);
  const resolved = path.resolve(root, target.replace(/^~(?=\/|$)/, os.homedir()));
  if (resolved !== root && !resolved.startsWith(root + path.sep)) {
    throw new Error(`Path escapes the Lafly sandbox root: ${target}`);
  }
  return resolved;
}

export function describePolicy(policy: ExecutionPolicy): string {
  if (policy.mode === 'live') {
    return 'LIVE EXECUTION ENABLED — External side effects are allowed.';
  }
  if (policy.mode === 'sandbox') {
    return `SANDBOX MODE — Side effects are confined to ${policy.sandboxRoot}.`;
  }
  return 'DRY RUN — External side effects are blocked.';
}
