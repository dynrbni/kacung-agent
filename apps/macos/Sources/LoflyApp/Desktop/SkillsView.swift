import SwiftUI

/// Skills: what the agent can actually do on this Mac.
///
/// The list is the server's tool registry, so the screen can never advertise a
/// capability that is not wired up. Grouping is by permission level rather than
/// by invented categories, because the question a person actually has is "what
/// will this do without asking me first?".
struct SkillsView: View {
    @EnvironmentObject private var store: DesktopStore

    private var groups: [(SkillPermissionLevel, [SkillDescriptor])] {
        SkillPermissionLevel.allCases.compactMap { level in
            let items = store.skills.filter { $0.permissionLevel == level }
            return items.isEmpty ? nil : (level, items)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            screenHeader(
                title: "Skills",
                subtitle: "What Lofly can do on this Mac.",
                trailing: {
                    Button {
                        store.refreshSkills()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.borderless)
                    .help("Refresh skills")
                    .accessibilityLabel("Refresh skills")
                }
            )

            LoflySeparator()

            content
        }
        .onAppear { store.refreshSkills() }
    }

    @ViewBuilder
    private var content: some View {
        if store.skills.isEmpty && store.isLoadingSkills {
            loadingState("Loading skills from the agent server…")
        } else if store.skills.isEmpty {
            emptyState(
                "No skills reported",
                "The agent server lists its tools. Start it, then refresh.",
                actionTitle: "Refresh",
                action: { store.refreshSkills() }
            )
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: LoflyTheme.Space.l) {
                    if store.skills.contains(where: { $0.simulated }) {
                        HStack(alignment: .top, spacing: LoflyTheme.Space.s) {
                            Image(systemName: "shield.lefthalf.filled")
                                .font(.system(size: LoflyTheme.Size.caption))
                                .foregroundStyle(.orange)
                            Text("Safe mode: the agent is simulating actions, so nothing on your Mac changes. Activity marks each one as a dry run.")
                                .font(LoflyTheme.caption(LoflyTheme.Size.caption))
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    ForEach(groups, id: \.0) { level, skills in
                        VStack(alignment: .leading, spacing: LoflyTheme.Space.s) {
                            VStack(alignment: .leading, spacing: 2) {
                                LoflySectionHeader(level.title)
                                Text(level.detail)
                                    .font(LoflyTheme.caption(LoflyTheme.Size.caption))
                                    .foregroundStyle(.tertiary)
                            }
                            ForEach(skills) { skill in
                                SkillRow(skill: skill)
                            }
                        }
                    }
                }
                .padding(LoflyTheme.Space.l)
                .frame(maxWidth: 720, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }
}

/// One skill. Flat row, not a card: a registry of forty capabilities reads as a
/// list, and forty floating cards would say nothing about any of them.
///
/// The title is a capability phrase ("Open an app") and the line under it is a
/// complete sentence from the tool's own description, so the row states what
/// Lofly can do rather than what it once did.
private struct SkillRow: View {
    let skill: SkillDescriptor

    var body: some View {
        HStack(alignment: .top, spacing: LoflyTheme.Space.s) {
            Image(systemName: LoflyTheme.symbol(for: skill.permissionLevel))
                .font(.system(size: LoflyTheme.Size.callout))
                .foregroundStyle(LoflyTheme.color(for: skill.permissionLevel))
                .frame(width: 16)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: LoflyTheme.Space.s) {
                    Text(skill.name)
                        .font(.system(size: 13.5, weight: .medium))
                        .foregroundStyle(LoflyTheme.primaryText)
                    Text(skill.sideEffectTitle)
                        .font(LoflyTheme.caption(11))
                        .foregroundStyle(LoflyTheme.tertiaryText)
                }
                Text(skill.summary ?? skill.description)
                    .font(LoflyTheme.caption(11.5))
                    .foregroundStyle(LoflyTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: LoflyTheme.Space.s)
        }
        .padding(.vertical, LoflyTheme.Space.s)
        .overlay(alignment: .bottom) {
            LoflySeparator()
        }
        .help("\(skill.description)\n\n\(skill.id)")
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(skill.name). \(skill.permissionLevel.title). \(skill.summary ?? skill.description)")
    }
}
