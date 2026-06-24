import SwiftUI

struct StartPinMarkerView: View {
    var time: String
    
    var body: some View {
        VStack(spacing: 2) {
            ZStack {
                Circle()
                    .fill(Color(red: 0.18, green: 0.49, blue: 0.22))
                    .frame(width: 36, height: 36)
                VStack(spacing: 0) {
                    Text(time)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                    Text("min")
                        .font(.system(size: 10))
                        .foregroundColor(.white)
                }
            }
                // vertical line
            Rectangle()
                .fill(Color(red: 0.18, green: 0.49, blue: 0.22))
                .frame(width: 3, height: 30)
            
                // small white circle base
//            Circle()
//                .fill(Color.green300)
//                .frame(width: 8, height: 8)
        }
        .shadow(radius: 2)
    }
}
