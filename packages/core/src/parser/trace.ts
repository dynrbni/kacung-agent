import type { CommandTrace } from '@kacung/types';

/**
 * Formats a structured internal command trace for logging and debugging.
 */
export function formatCommandTrace(trace: CommandTrace): string {
  const intentStr = Array.isArray(trace.parsedIntent)
    ? JSON.stringify(trace.parsedIntent, null, 2)
    : `intent = ${trace.parsedIntent.intent}\nrecipient = ${'recipient' in trace.parsedIntent ? trace.parsedIntent.recipient : 'N/A'}\nmessage = ${'message' in trace.parsedIntent ? trace.parsedIntent.message : 'N/A'}`;

  return [
    '=== INTERNAL COMMAND TRACE ===',
    'RAW TRANSCRIPT:',
    `"${trace.rawTranscript}"`,
    '',
    'PARSED INTENT:',
    intentStr,
    '',
    'VALIDATION:',
    `recipient = ${trace.validation.recipient}`,
    `message = ${trace.validation.message}${trace.validation.reason ? ` (${trace.validation.reason})` : ''}`,
    '',
    trace.contactResolution
      ? `CONTACT RESOLUTION:\n${trace.contactResolution.query} → ${trace.contactResolution.resolved ? 'resolved' : 'unresolved'}\n`
      : '',
    trace.execution
      ? `EXECUTION:\n${trace.execution.tool}(\n${Object.entries(trace.execution.parameters)
          .map(([k, v]) => `    ${k}="${v}"`)
          .join(',\n')}\n)\n`
      : '',
    trace.result
      ? `RESULT:\n${trace.result.success ? 'success' : 'failure'}${trace.result.details ? ` (${trace.result.details})` : ''}`
      : '',
    '==============================',
  ]
    .filter(Boolean)
    .join('\n');
}
