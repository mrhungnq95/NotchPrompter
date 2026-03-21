import SwiftUI

struct PrompterView: View {
    @ObservedObject var viewModel: PrompterViewModel

    // Measure content height to loop or stop appropriately
    @State private var contentHeight: CGFloat = 0

    // Tracks whether we paused due to hover and what the previous play state was
    @State private var wasPlayingBeforeHover: Bool = false
    @State private var isHovering: Bool = false

    var body: some View {
        ScrollablePrompterView(
            viewModel: viewModel,
            contentHeight: $contentHeight,
            isHovering: $isHovering,
            wasPlayingBeforeHover: $wasPlayingBeforeHover
        )
    }
}

// MARK: - Scrollable Prompter View with NSView for scroll events
struct ScrollablePrompterView: NSViewRepresentable {
    @ObservedObject var viewModel: PrompterViewModel
    @Binding var contentHeight: CGFloat
    @Binding var isHovering: Bool
    @Binding var wasPlayingBeforeHover: Bool
    
    func makeNSView(context: Context) -> PrompterHostingView {
        let hostingView = PrompterHostingView(
            viewModel: viewModel,
            contentHeight: $contentHeight,
            isHovering: $isHovering,
            wasPlayingBeforeHover: $wasPlayingBeforeHover
        )
        return hostingView
    }
    
    func updateNSView(_ nsView: PrompterHostingView, context: Context) {
        nsView.updateContent()
    }
}

// MARK: - Custom NSView to handle scroll events
class PrompterHostingView: NSView {
    private let viewModel: PrompterViewModel
    private var hostingView: NSHostingView<PrompterContentView>!
    private var trackingArea: NSTrackingArea?
    @Binding var contentHeight: CGFloat
    @Binding var isHovering: Bool
    @Binding var wasPlayingBeforeHover: Bool
    
    init(viewModel: PrompterViewModel, 
         contentHeight: Binding<CGFloat>,
         isHovering: Binding<Bool>,
         wasPlayingBeforeHover: Binding<Bool>) {
        self.viewModel = viewModel
        self._contentHeight = contentHeight
        self._isHovering = isHovering
        self._wasPlayingBeforeHover = wasPlayingBeforeHover
        super.init(frame: .zero)
        
        let contentView = PrompterContentView(
            viewModel: viewModel,
            contentHeight: contentHeight
        )
        hostingView = NSHostingView(rootView: contentView)
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(hostingView)
        
        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(equalTo: leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: trailingAnchor),
            hostingView.topAnchor.constraint(equalTo: topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func updateContent() {
        let contentView = PrompterContentView(
            viewModel: viewModel,
            contentHeight: $contentHeight
        )
        hostingView.rootView = contentView
    }
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        
        if let trackingArea = trackingArea {
            removeTrackingArea(trackingArea)
        }
        
        let options: NSTrackingArea.Options = [
            .mouseEnteredAndExited,
            .activeAlways
        ]
        
        trackingArea = NSTrackingArea(
            rect: bounds,
            options: options,
            owner: self,
            userInfo: nil
        )
        
        if let trackingArea = trackingArea {
            addTrackingArea(trackingArea)
        }
    }
    
    override func mouseEntered(with event: NSEvent) {
        handleHoverChange(hovering: true)
    }
    
    override func mouseExited(with event: NSEvent) {
        handleHoverChange(hovering: false)
    }
    
    override func scrollWheel(with event: NSEvent) {
        // Only handle scroll when hovering
        guard isHovering else { return }
        
        // Handle vertical scroll
        let scrollAmount = event.scrollingDeltaY
        let sensitivity: CGFloat = 2.0 // Adjust scroll sensitivity
        
        viewModel.offset = max(0, viewModel.offset - scrollAmount * sensitivity)
    }
    
    private func handleHoverChange(hovering: Bool) {
        guard viewModel.pauseOnHover else {
            isHovering = false
            wasPlayingBeforeHover = false
            return
        }

        if hovering {
            isHovering = true
            wasPlayingBeforeHover = viewModel.isPlaying
            if viewModel.isPlaying {
                viewModel.pause()
            }
        } else {
            if isHovering, wasPlayingBeforeHover {
                viewModel.play()
            }
            isHovering = false
            wasPlayingBeforeHover = false
        }
    }
}

// MARK: - Content View (SwiftUI)
struct PrompterContentView: View {
    @ObservedObject var viewModel: PrompterViewModel
    @Binding var contentHeight: CGFloat

    var body: some View {
        ZStack {
            Color.black
            GeometryReader { geo in
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    movingText
                        .frame(width: geo.size.width, alignment: .center)
                        .offset(y: -viewModel.offset)
                        .background(HeightReader(height: $contentHeight))
                    Spacer(minLength: 0)
                }
                .clipped()
                .onChange(of: viewModel.offset) { _, newValue in
                    if contentHeight > 0, newValue > contentHeight {
                        //we've scrolled past the end
                        viewModel.offset = 0 // restarts
                    }
                }
                .onChange(of: viewModel.text) { _, _ in
                    // reset offset when text changes to avoid jump into middle
                    viewModel.offset = 0
                }
            }
            
            // Fade overlays
            VStack(spacing: 0) {
                if viewModel.enableTopFade {
                    LinearGradient(
                        gradient: Gradient(colors: [.black, .clear]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: viewModel.topFadeHeight)
                    .allowsHitTesting(false)
                }
                
                Spacer()
                
                if viewModel.enableBottomFade {
                    LinearGradient(
                        gradient: Gradient(colors: [.clear, .black]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: viewModel.bottomFadeHeight)
                    .allowsHitTesting(false)
                }
            }
        }
        .opacity(viewModel.opacity)
        .ignoresSafeArea()
    }
    
    private var movingText: some View {
        // Duplicate the text once to create a seamless loop
        let linesSpacing = 8.0 //add settings to configure this
        return VStack(spacing: linesSpacing) {
            textBlock
            textBlock
        }
        .padding(.vertical, 24)
        .padding(.horizontal, 24)
    }

    private var textBlock: some View {
        let base = viewModel.text.isEmpty ? "Put some text in Settings..." : viewModel.text
        let text = "\n" + base + "\n\n🏁\n\n" // add a new line to not hide the first line under the notch
        
        return Text(text)
            .font(.system(size: viewModel.fontSize, weight: .regular, design: viewModel.fontDesign))
            .foregroundColor(.white)
            .multilineTextAlignment(.center)
            .lineSpacing(8)
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .center)
    }
}

private struct HeightReader: View {
    @Binding var height: CGFloat
    var body: some View {
        GeometryReader { proxy in
            Color.clear
                .onAppear { height = proxy.size.height }
                .onChange(of: proxy.size) { _, newSize in
                    height = newSize.height
                }
        }
    }
}
