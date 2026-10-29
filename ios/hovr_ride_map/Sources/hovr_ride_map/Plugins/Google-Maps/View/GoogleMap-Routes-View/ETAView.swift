import SwiftUI

struct StartPinMarkerView: View {
    var time: String
    private let colors = MapThemeColors.current
    
    var body: some View {
        VStack(spacing: 2) {
            ZStack {
                Circle()
                    .fill(colors.accentStrong.argbColor)
                    .frame(width: 36, height: 36)
                VStack(spacing: 0) {
                    Text(time)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(colors.onAccent.argbColor)
                    Text("min")
                        .font(.system(size: 10))
                        .foregroundColor(colors.onAccent.argbColor)
                }
            }
                // vertical line
            Rectangle()
                .fill(colors.accentStrong.argbColor)
                .frame(width: 3, height: 30)
            
                // small white circle base
//            Circle()
//                .fill(Color.green300)
//                .frame(width: 8, height: 8)
        }
        .shadow(radius: 2)
    }
}
