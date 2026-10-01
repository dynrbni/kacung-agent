/**
 * Wording for the Skills screen.
 *
 * The tool registry names tools for the executor, and `humanizeToolName` names
 * them for the activity log — a record of what already happened ("Opened
 * application", "Captured screen"). A capability list answers a different
 * question: what can Lofly do? Past tense is wrong there, and two tools that
 * read identically in a log ("Captured screen" for both `screenshot` and
 * `screenshot_app`) need to be told apart in a list.
 *
 * This table is the one place that wording lives. A tool missing from it still
 * renders as a readable phrase rather than a raw identifier, so adding a tool
 * to the registry can never produce a blank or snake-cased row.
 */
const CAPABILITY_LABELS: Record<string, string> = {
  // Applications
  open_app: 'Open an app',
  close_app: 'Quit an app',
  focus_app: 'Bring an app to the front',
  is_app_running: 'Check if an app is running',

  // Screen and UI
  screenshot: 'Take a screenshot of the screen',
  screenshot_app: "Capture one app's window",
  inspect_ui: "Inspect an app's buttons, fields and menus",
  locate_on_screen: 'Find text or buttons on the screen',
  click_element_by_text: 'Click a button or text on screen',

  // Mouse
  click: 'Click at a screen position',
  double_click: 'Double-click at a screen position',
  right_click: 'Right-click at a screen position',
  move_mouse: 'Move the mouse',
  drag: 'Drag from one point to another',
  scroll: 'Scroll',

  // Keyboard
  type_text: 'Type text into the active app',
  press_key: 'Press a key',
  hotkey: 'Press a keyboard shortcut',

  // Timing and verification
  wait: 'Pause for a moment',
  wait_for_app: 'Wait for an app to start',
  verify_state: 'Check that an action actually worked',

  // Files
  read_file: 'Read a file',
  write_file: 'Write or update a file',
  find_file: 'Find files by name',
  list_directory: "List a folder's contents",
  create_directory: 'Create a folder',
  copy_file: 'Copy a file',
  move_file: 'Move or rename a file',
  delete_file: 'Delete a file or folder',

  // Terminal and web
  run_command: 'Run a shell command',
  open_url: 'Open a link',
  web_search: 'Search the web',
  read_web_page: 'Read a web page',

  // Music
  play_music: 'Play music',
  search_music: 'Search music',

  // WhatsApp
  open_whatsapp: 'Open WhatsApp',
  search_whatsapp_contact: 'Find a WhatsApp contact',
  open_whatsapp_chat: 'Open a WhatsApp chat',
  send_whatsapp_message: 'Send a WhatsApp message',

  // System and documents
  set_volume: 'Change the system volume',
  write_word_document: 'Write a document in Word',
};

/** How a skill is named on the Skills screen. Never past tense, never raw. */
export function capabilityLabel(toolName: string): string {
  const label = CAPABILITY_LABELS[toolName];
  if (label) return label;

  const words = toolName.split('_').filter(Boolean).join(' ');
  return words ? `Use ${words}` : toolName;
}

/**
 * The first complete sentence of a description.
 *
 * Descriptions are written for the model and often run to several sentences,
 * with the first one carrying the meaning. Cutting one with a line limit ends
 * the row mid-sentence, so the screen shows the first sentence whole and keeps
 * the remainder for the tooltip.
 *
 * A period only ends a sentence when an uppercase word or the end of the text
 * follows it, so "e.g. "return"" and "(e.g. app is running)" are not mistaken
 * for sentence ends.
 */
export function firstSentence(text: string): string {
  const trimmed = text.trim();
  const match = trimmed.match(/^[\s\S]*?[.!?](?=\s+[A-Z]|$)/);
  return match ? match[0].trim() : trimmed;
}
