import SwiftUI

private struct StepIndicatorView: View
{
    let steps: [String]
    let currentStep: Int

    var body: some View
    {
        HStack(spacing: 0)
        {
            ForEach(0 ..< steps.count, id: \.self)
            { index in
                HStack(spacing: 8)
                {
                    ZStack
                    {
                        Circle()
                            .fill(circleColor(for: index))
                            .frame(width: 26, height: 26)

                        if index < currentStep
                        {
                            Image(systemName: "checkmark")
                                .font(.caption.bold())
                                .foregroundStyle(.white)
                        }
                        else
                        {
                            Text("\(index + 1)")
                                .font(.caption.bold())
                                .foregroundStyle(index == currentStep ? .white : .secondary)
                        }
                    }

                    Text(steps[index])
                        .font(.subheadline)
                        .fontWeight(index == currentStep ? .semibold : .regular)
                        .foregroundStyle(index <= currentStep ? .primary : .secondary)
                }

                if index < steps.count - 1
                {
                    Rectangle()
                        .fill(index < currentStep ? Color.accentColor : Color.secondary.opacity(0.25))
                        .frame(height: 1)
                        .padding(.horizontal, 10)
                }
            }
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 14)
    }

    private func circleColor(for index: Int) -> Color
    {
        if index < currentStep { return .accentColor }
        if index == currentStep { return .accentColor }
        return Color.secondary.opacity(0.2)
    }
}

struct ContentView: View
{
    @State private var appState = AppState()

    var body: some View
    {
        @Bindable var state = appState

        VStack(spacing: 0)
        {
            StepIndicatorView(steps: appState.stepTitles, currentStep: appState.currentStep)

            Divider()

            Group
            {
                switch appState.currentStep
                {
                case 0: FontPickerView()
                case 1: CharsetPickerView()
                case 2: ExportView()
                case 3: DemoView()
                default: EmptyView()
                }
            }
            .environment(appState)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            HStack
            {
                if appState.currentStep > 0
                {
                    Button("← Back")
                    {
                        state.goToPreviousStep()
                    }
                }

                Spacer()

                if appState.currentStep < appState.stepTitles.count - 1
                {
                    Button("Next →")
                    {
                        state.goToNextStep()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!appState.canAdvance)
                }
            }
            .padding()
        }
        .frame(minWidth: 720, minHeight: 520)
    }
}

#Preview
{
    ContentView()
}
