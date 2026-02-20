import SwiftUI
import PhotosUI

struct ImportView: View {
    @Binding var selectedItem: PhotosPickerItem?
    let isExtracting: Bool

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.42, green: 0.35, blue: 0.85),
                                    Color(red: 0.58, green: 0.42, blue: 0.92)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 100, height: 100)

                    Image(systemName: "dice.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(.white)
                }

                Text("Pips Solver")
                    .font(.system(.largeTitle, weight: .bold))

                Text("Upload a screenshot of a NYT Pips\npuzzle to extract and solve it")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 12) {
                PhotosPicker(selection: $selectedItem, matching: .screenshots) {
                    Label("Choose Screenshot", systemImage: "photo.on.rectangle.angled")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                }
                .buttonStyle(.borderedProminent)

                PhotosPicker(selection: $selectedItem, matching: .images) {
                    Label("Photo Library", systemImage: "photo.stack")
                        .font(.subheadline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal, 40)
            .disabled(isExtracting)

            if isExtracting {
                VStack(spacing: 12) {
                    ProgressView()
                        .controlSize(.large)
                    Text("Analyzing puzzle...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 8)
            }

            Spacer()
            Spacer()
        }
        .padding()
    }
}
