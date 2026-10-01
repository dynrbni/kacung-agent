import { execFile } from 'child_process';
import { promisify } from 'util';
import type { ToolDefinition, ToolExecutionContext, ToolResult, UIElement } from '@lofly/types';
import { toolSafety } from '../safety/policy.js';

const execFileAsync = promisify(execFile);

export interface InspectUIParams {
  appName?: string;
  maxElements?: number;
}

export interface InspectUIResultData {
  application: string;
  windowTitle?: string;
  elements: UIElement[];
  totalFound: number;
}

export const inspectUITool: ToolDefinition<InspectUIParams, InspectUIResultData> = {
  name: 'inspect_ui',
  description: 'Inspects visible UI elements and accessibility hierarchy (buttons, inputs, menus, text) of the frontmost or specified application.',
  permissionLevel: 'SAFE',
  safety: toolSafety('none', { supportsSandbox: true }),
  parameters: {
    type: 'object',
    properties: {
      appName: {
        type: 'string',
        description: 'Optional name of the application to inspect. If omitted, inspects the current frontmost application.',
      },
      maxElements: {
        type: 'number',
        description: 'Maximum number of elements to return (default: 30).',
      },
    },
  },
  async execute(params: InspectUIParams, context: ToolExecutionContext): Promise<ToolResult<InspectUIResultData>> {
    const targetApp = params?.appName?.trim();
    const maxElements = params?.maxElements || 30;

    context.logger.info(`inspect_ui requested for ${targetApp || 'frontmost app'}`);

    // JavaScript for Automation (JXA) to query System Events Accessibility hierarchy
    const jxaScript = `
function run() {
    var se = Application("System Events");
    var targetProcess = null;

    var appArg = "${targetApp ? targetApp.replace(/"/g, '\\"') : ''}";
    if (appArg) {
        try {
            targetProcess = se.processes.byName(appArg);
        } catch(e) {}
    }

    if (!targetProcess) {
        var frontProcesses = se.processes.whose({ frontmost: true });
        if (frontProcesses.length > 0) {
            targetProcess = frontProcesses[0];
        }
    }

    if (!targetProcess) {
        return JSON.stringify({ application: "unknown", elements: [] });
    }

    var appName = targetProcess.name();
    var windowTitle = "";
    var uiElements = [];

    try {
        var windows = targetProcess.windows();
        if (windows.length > 0) {
            var frontWin = windows[0];
            try { windowTitle = frontWin.name() || frontWin.title() || ""; } catch(e) {}

            function extractElements(container, depth) {
                if (depth > 3 || uiElements.length >= ${maxElements}) return;
                var children = [];
                try { children = container.uiElements(); } catch(e) { return; }

                for (var i = 0; i < children.length; i++) {
                    if (uiElements.length >= ${maxElements}) break;
                    var el = children[i];
                    try {
                        var role = el.role();
                        var title = "";
                        var value = "";
                        var desc = "";
                        var pos = [0, 0];
                        var sz = [0, 0];

                        try { title = el.title(); } catch(e) {}
                        try { value = el.value(); } catch(e) {}
                        try { desc = el.description(); } catch(e) {}
                        try { pos = el.position(); } catch(e) {}
                        try { sz = el.size(); } catch(e) {}

                        // Only include meaningful interactive elements
                        if (title || value || desc || role === "AXButton" || role === "AXTextField" || role === "AXSearchField") {
                            uiElements.push({
                                role: role,
                                title: title || undefined,
                                value: value ? String(value) : undefined,
                                description: desc || undefined,
                                frame: { x: pos[0], y: pos[1], width: sz[0], height: sz[1] }
                            });
                        }
                        extractElements(el, depth + 1);
                    } catch(e) {}
                }
            }

            extractElements(frontWin, 1);
        }
    } catch(err) {
        // Accessibility permission not granted or app has no window
    }

    return JSON.stringify({
        application: appName,
        windowTitle: windowTitle,
        elements: uiElements
    });
}
`;

    try {
      const { stdout } = await execFileAsync('osascript', ['-l', 'JavaScript', '-e', jxaScript]);
      const parsed = JSON.parse(stdout.trim() || '{}');
      const elements: UIElement[] = parsed.elements || [];

      return {
        success: true,
        data: {
          application: parsed.application || targetApp || 'macOS',
          windowTitle: parsed.windowTitle || undefined,
          elements,
          totalFound: elements.length,
        },
      };
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : String(err);
      context.logger.warn(`inspect_ui failed: ${msg}`);

      // Graceful fallback with frontmost process name
      return {
        success: true,
        data: {
          application: targetApp || 'macOS',
          elements: [],
          totalFound: 0,
        },
      };
    }
  },
};
