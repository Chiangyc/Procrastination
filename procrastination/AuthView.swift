import SwiftUI

struct AuthView: View {
    enum Mode { case login, register }

    // ✅ 使用共用的環境 ViewModel，不再用 @StateObject
    @EnvironmentObject var authVM: AuthViewModel
    @State private var mode: Mode = .login

    var body: some View {
        VStack(spacing: 20) {
            Text(mode == .login ? "登入" : "註冊")
                .font(.largeTitle)
                .bold()

            // Email 欄位
            TextField("Email", text: $authVM.email)
                .textInputAutocapitalization(.never)
                .keyboardType(.emailAddress)
                .textFieldStyle(.roundedBorder)

            // 註冊時才輸入用戶名稱
            if mode == .register {
                TextField("用戶名稱", text: $authVM.displayName)
                    .textFieldStyle(.roundedBorder)
            }

            // 密碼欄位
            SecureField("密碼", text: $authVM.password)
                .textFieldStyle(.roundedBorder)

            // 登入或註冊按鈕
            Button(mode == .login ? "登入" : "註冊") {
                Task {
                    if mode == .login {
                        await authVM.login()
                    } else {
                        await authVM.register()
                    }
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(authVM.isLoading)

            // 錯誤訊息
            if let msg = authVM.errorMessage {
                Text(msg)
                    .foregroundColor(.red)
                    .font(.footnote)
            }

            // 切換登入／註冊
            Button(mode == .login ? "沒有帳號？註冊" : "已有帳號？登入") {
                mode = (mode == .login) ? .register : .login
            }
            .font(.footnote)

            // 成功登入後顯示暫時提示
            if let user = authVM.currentUser {
                Text("Hi, \(user.displayName)")
                    .font(.title3)
                    .padding(.top)
            }
        }
        .padding()
    }
}
