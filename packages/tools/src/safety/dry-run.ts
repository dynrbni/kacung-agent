import type { ToolResult, ToolSafetyMetadata, ExecutionPolicy } from '@lofly/types';
import { getToolSafety, executionStatus } from './policy.js';

export interface DryRunOptions {
  toolName: string;
  parameters: Record<string, unknown>;
  safety?: ToolSafetyMetadata;
  policy: ExecutionPolicy;
}

/**
 * Builds the simulated result for a tool call that was blocked before it could
 * reach any external system.
 *
 * Arguments are echoed back verbatim so a test can assert on the exact
 * recipient and message that *would* have been used — the pipeline is fully
 * exercised, only the side effect is skipped.
 */
export function buildDryRunResult(options: DryRunOptions): ToolResult {
  const { toolName, parameters, policy } = options;
  const safety = getToolSafety(options.safety);
  const status = executionStatus('dry_run');

  return {
    success: true,
    data: simulateData(toolName, parameters),
    metadata: {
      ...status,
      tool: toolName,
      sideEffect: safety.sideEffect,
      suppressedSideEffect: safety.sideEffect,
      parameters,
      reason: `Blocked by execution policy (mode=${policy.mode}, sideEffect=${safety.sideEffect}). No external side effect was performed.`,
    },
  };
}

/**
 * Per-tool simulated payloads. The shape deliberately mirrors each tool's live
 * success payload so consumers and tests do not need a separate code path.
 */
function simulateData(toolName: string, params: Record<string, unknown>): Record<string, unknown> {
  const recipient = String(params.recipient ?? params.contact ?? params.name ?? '').trim();
  const message = String(params.message ?? params.text ?? '').trim();

  switch (toolName) {
    case 'send_whatsapp_message':
      return {
        recipient,
        text: message,
        sent: false,
        verified: false,
        details: `[DRY RUN] Pesan ke "${recipient}" TIDAK dikirim. Pesan: "${message}".`,
        mode: 'dry_run',
        dryRun: true,
        executed: false,
      };

    case 'open_whatsapp_chat':
      return {
        contact: String(params.contact ?? ''),
        message: `[DRY RUN] Tidak membuka chat WhatsApp dengan "${recipient}".`,
        mode: 'dry_run',
        dryRun: true,
        executed: false,
      };

    case 'search_whatsapp_contact':
      return {
        name: String(params.name ?? ''),
        message: `[DRY RUN] Tidak mencari kontak "${recipient}" di WhatsApp.`,
        mode: 'dry_run',
        dryRun: true,
        executed: false,
      };

    case 'open_whatsapp':
      return {
        target: 'app',
        message: '[DRY RUN] Tidak membuka WhatsApp.',
        mode: 'dry_run',
        dryRun: true,
        executed: false,
      };

    case 'open_app':
    case 'focus_app':
      return {
        appName: String(params.appName ?? ''),
        opened: false,
        message: `[DRY RUN] Tidak membuka aplikasi "${params.appName}".`,
        mode: 'dry_run',
        dryRun: true,
        executed: false,
      };

    case 'close_app':
      return {
        appName: String(params.appName ?? ''),
        closed: false,
        message: `[DRY RUN] Tidak menutup aplikasi "${params.appName}".`,
        mode: 'dry_run',
        dryRun: true,
        executed: false,
      };

    case 'delete_file':
      return {
        path: String(params.path ?? ''),
        deleted: false,
        message: `[DRY RUN] Tidak menghapus file "${params.path}".`,
        mode: 'dry_run',
        dryRun: true,
        executed: false,
      };

    case 'run_command':
      return {
        command: String(params.command ?? ''),
        stdout: '',
        stderr: '',
        exitCode: null,
        message: `[DRY RUN] Perintah tidak dijalankan: ${params.command}`,
        mode: 'dry_run',
        dryRun: true,
        executed: false,
      };

    case 'type_text':
      return {
        typed: false,
        message: '[DRY RUN] Tidak mengetik teks ke aplikasi aktif.',
        mode: 'dry_run',
        dryRun: true,
        executed: false,
      };

    default:
      return {
        parameters: params,
        message: `[DRY RUN] ${toolName} disimulasikan. Tidak ada side effect eksternal.`,
        mode: 'dry_run',
        dryRun: true,
        executed: false,
      };
  }
}

/**
 * Human-readable block for development logs and the macOS notch, so a
 * simulated action is never rendered as a completed one.
 */
export function formatDryRunSummary(toolName: string, parameters: Record<string, unknown>): string {
  const recipient = String(parameters.recipient ?? parameters.contact ?? parameters.name ?? '').trim();
  const message = String(parameters.message ?? parameters.text ?? '').trim();
  const lines = ['[DRY RUN]'];

  switch (toolName) {
    case 'send_whatsapp_message':
      lines.push('WhatsApp', `Recipient: ${recipient}`, `Message: ${message}`, 'Action: NOT SENT');
      break;
    case 'run_command':
      lines.push('Shell', `Command: ${parameters.command ?? ''}`, 'Action: NOT EXECUTED');
      break;
    case 'delete_file':
      lines.push('Filesystem', `Path: ${parameters.path ?? ''}`, 'Action: NOT DELETED');
      break;
    default:
      lines.push(toolName, `Parameters: ${JSON.stringify(parameters)}`, 'Action: NOT EXECUTED');
  }

  return lines.join('\n');
}
