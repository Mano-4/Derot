import SwiftUI

struct SplashView: View {
    @State private var showTitle = false
    @State private var showCaption = false
    
    
    var body: some View {
        VStack(){
            Spacer()
            
            VStack(spacing:8){
                Text("Derot")  .font(Font.custom("ComingSoon-Regular", size:34, relativeTo: .title))
                    .opacity(showTitle ? 1 :0)
                    .onAppear(){
                        withAnimation(.easeOut(duration: 1.0)){ showTitle=true}
                    }
                
                Text("Less fog, more you.")
                    .font(.system(.callout, design: .rounded))
                    .foregroundStyle(.secondary)
                    .opacity(showCaption ? 1 : 0)
                    .onAppear(){
                        withAnimation(.easeOut(duration: 0.8).delay(0.4)){
                            showCaption = true
                        }
                    }
            }
                Spacer()
            
            
            
            Image("happybunny").resizable().scaledToFit().frame(width:140)
        }
        .ignoresSafeArea(edges:.bottom)
        
    }
    
}

#Preview {
    SplashView()
}
