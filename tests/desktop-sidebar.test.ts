import { describe, it, expect } from 'vitest';
import { readFileSync, existsSync, readdirSync } from 'fs';
import path from 'path';

const ROOT = process.cwd();
const SOURCES = path.join(ROOT, 'apps/macos/Sources/LoflyApp');

const SIDEBAR = readFileSync(path.join(SOURCES, 'Desktop/DesktopSidebar.swift'), 'utf8');
const ROOT_VIEW = readFileSync(path.join(SOURCES, 'Desktop/DesktopRootView.swift'), 'utf8');
const MODELS = readFileSync(path.join(SOURCES, 'Models/DesktopModels.swift'), 'utf8');

function swiftSources(dir: string, acc: string[] = []): string[] {
  for (const entry of readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) swiftSources(full, acc);
    else if (entry.name.endsWith('.swift')) acc.push(full);
  }
  return acc;
}

/** Source with comment lines removed, so an assertion is about code. */
function codeOnly(source: string): string {
  return source
    .split('\n')
    .filter((line) => !line.trim().startsWith('//'))
    .join('\n');
}

/**
 * The sidebar's shape is a product requirement — four destinations, then the
 * conversations, then who you are — and macOS views cannot be exercised from
 * the Node suite. These assertions guard the source that implements it, the
 * same way push-to-talk guards its own timing logic.
 */
describe('Desktop sidebar — four destinations, nothing more', () => {
  it('orders the destinations New chat, Activity, Integrations, Skills', () => {
    const navRows = [...SIDEBAR.matchAll(/LoflySidebarRow\(\s*"([^"]+)"/g)].map((match) => match[1]);
    expect(navRows).toEqual(['Activity', 'Integrations', 'Skills']);

    // New chat sits above the destinations, and the chat list below them.
    const body = SIDEBAR.slice(
      SIDEBAR.indexOf('var body: some View'),
      SIDEBAR.indexOf('MARK: - Wordmark')
    );
    const markers = ['wordmark', 'newChatButton', 'navigationRows', 'chatsSection', 'accountFooter'];
    const positions = markers.map((marker) => {
      const index = body.indexOf(marker);
      expect(index, `sidebar body is missing ${marker}`).toBeGreaterThan(-1);
      return index;
    });

    expect(positions).toEqual([...positions].sort((a, b) => a - b));
  });

  it('keeps Memory and Tasks out of the sidebar', () => {
    const rows = [...SIDEBAR.matchAll(/LoflySidebarRow\(\s*"([^"]+)"/g)].map((match) => match[1]);

    // The nav rows are exactly the navigation rows; history rows pass a title
    // expression, not a literal, so they never appear here.
    expect(rows).toEqual(['Activity', 'Integrations', 'Skills']);
    expect(rows).not.toContain('Memory');
    expect(rows).not.toContain('Tasks');
  });

  it('puts the account row and the settings button at the foot', () => {
    const footer = SIDEBAR.slice(SIDEBAR.indexOf('private var accountFooter'));

    expect(footer).toContain('store.activeSurface = .account');
    expect(footer).toContain('store.activeSurface = .settings');
  });

  it('routes every destination to a screen that exists', () => {
    const destinations = ['chat', 'activity', 'integrations', 'skills', 'account', 'settings'];

    for (const destination of destinations) {
      expect(MODELS).toContain(`case ${destination}`);
    }
    // Tasks is not a surface any more: it is the live block inside Activity.
    expect(MODELS).not.toMatch(/case tasks\b/);
    expect(ROOT_VIEW).not.toContain('case .tasks');

    expect(ROOT_VIEW).toContain('case .integrations: IntegrationsView()');
    expect(ROOT_VIEW).toContain('case .skills: SkillsView()');
    expect(ROOT_VIEW).toContain('case .activity: ActivityView()');
    expect(ROOT_VIEW).toContain('case .account: AccountView()');

    // A navigation item without a file behind it is a dead link.
    for (const file of ['Desktop/ActivityView.swift', 'Desktop/IntegrationsView.swift', 'Desktop/SkillsView.swift']) {
      expect(existsSync(path.join(SOURCES, file)), `${file} is missing`).toBe(true);
    }
    expect(existsSync(path.join(SOURCES, 'Desktop/TasksView.swift'))).toBe(false);
  });
});

describe('Desktop shell — one owner per concern', () => {
  it('keeps the sidebar and the banner out of the window controller file', () => {
    expect(ROOT_VIEW).not.toContain('struct DesktopSidebar');
    expect(ROOT_VIEW).not.toContain('struct LoflyBanner');

    // The root file still hosts both, and both still exist somewhere real.
    expect(ROOT_VIEW).toContain('DesktopSidebar()');
    expect(ROOT_VIEW).toContain('LoflyBanner(');
    expect(existsSync(path.join(SOURCES, 'Desktop/DesktopSidebar.swift'))).toBe(true);
    expect(existsSync(path.join(SOURCES, 'DesignSystem/LoflyBanner.swift'))).toBe(true);
  });

  it('formats every timestamp in exactly one place', () => {
    const owners = swiftSources(SOURCES)
      .filter((file) => /DateFormatter|RelativeDateTimeFormatter/.test(readFileSync(file, 'utf8')))
      .map((file) => path.relative(SOURCES, file).split(path.sep).join('/'));

    expect(owners).toEqual(['DesignSystem/LoflyDate.swift']);

    // Both former owners now defer to it, so the two cannot drift apart.
    expect(readFileSync(path.join(SOURCES, 'Desktop/TaskCard.swift'), 'utf8')).toContain(
      'LoflyDate.relative'
    );
    expect(SIDEBAR).toContain('LoflyDate.relative');
  });
});

describe('Desktop — the Memory screen stays locked', () => {
  /**
   * Memory is built but deliberately unreachable: it ships later, so the row
   * would be navigation to nothing (and the product rule is that it stays
   * unopenable until then). This test is that lock. When Memory does ship,
   * replace it with an assertion that the row leads to the screen.
   */
  it('exists, and is reachable from nowhere', () => {
    const memory = readFileSync(path.join(SOURCES, 'Desktop/MemoryView.swift'), 'utf8');
    expect(memory).toContain('struct MemoryView: View');
    expect(memory).toContain('Deliberately not reachable yet');

    expect(codeOnly(SIDEBAR)).not.toContain('Memory');
    expect(MODELS).not.toContain('case memory');
    expect(codeOnly(ROOT_VIEW)).not.toContain('MemoryView()');
  });
});
